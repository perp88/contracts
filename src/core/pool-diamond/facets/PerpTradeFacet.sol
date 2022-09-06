// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import { LibReentrancyGuard } from "../libraries/LibReentrancyGuard.sol";
import { LibPoolV1 } from "../libraries/LibPoolV1.sol";

import { PerpTradeFacetInterface } from "../interfaces/PerpTradeFacetInterface.sol";
import { GetterFacetInterface } from "../interfaces/GetterFacetInterface.sol";
import { FundingRateFacetInterface } from "../interfaces/FundingRateFacetInterface.sol";

contract PerpTradeFacet is PerpTradeFacetInterface {
  error PerpTradeFacet_BadCollateralDelta();
  error PerpTradeFacet_BadLiquidator();
  error PerpTradeFacet_BadToken();
  error PerpTradeFacet_BadPositionSize();
  error PerpTradeFacet_BadSizeDelta();
  error PerpTradeFacet_CollateralNotCoverFee();
  error PerpTradeFacet_CollateralTokenIsStable();
  error PerpTradeFacet_CollateralTokenNotStable();
  error PerpTradeFacet_FeeExceedCollateral();
  error PerpTradeFacet_IndexTokenIsStable();
  error PerpTradeFacet_IndexTokenNotShortable();
  error PerpTradeFacet_LeverageDisabled();
  error PerpTradeFacet_LiquidationFeeExceedCollateral();
  error PerpTradeFacet_LossesExceedCollateral();
  error PerpTradeFacet_MaxLeverageExceed();
  error PerpTradeFacet_SizeSmallerThanCollateral();
  error PerpTradeFacet_TokenMisMatch();

  uint256 internal constant BPS = 10000;

  event ClosePosition(
    bytes32 posId,
    uint256 size,
    uint256 collateral,
    uint256 averagePrice,
    uint256 entryFundingRate,
    uint256 reserveAmount,
    int256 realisedPnL
  );
  event CollectMarginFee(address token, uint256 feeUsd, uint256 feeTokens);
  event DecreasePosition(
    bytes32 posId,
    address primaryAccount,
    uint256 subAccountId,
    address collateralToken,
    address indexToken,
    uint256 collateralDelta,
    uint256 sizeDelta,
    bool isLong,
    uint256 price,
    uint256 feeUsd
  );
  event IncreasePosition(
    bytes32 posId,
    address primaryAccount,
    uint256 subAccountId,
    address collateralToken,
    address indexToken,
    uint256 collateralDeltaUsd,
    uint256 sizeDelta,
    bool isLong,
    uint256 price,
    uint256 feeUsd
  );
  event LiquidatePosition(
    bytes32 posId,
    address primaryAccount,
    uint256 subAccountId,
    address collateralToken,
    address indexToken,
    bool isLong,
    uint256 size,
    uint256 collateral,
    uint256 reserveAmount,
    int256 realisedPnl,
    uint256 markPrice
  );
  event UpdatePnL(bytes32 positionId, bool isProfit, uint256 delta);
  event UpdatePosition(
    bytes32 positionId,
    uint256 size,
    uint256 collateral,
    uint256 averagePrice,
    uint256 entryFundingRate,
    uint256 reserveAmount,
    int256 realizedPnl,
    uint256 price
  );

  function checkLiquidation(
    address account,
    address collateralToken,
    address indexToken,
    bool isLong,
    bool isRevertOnError
  ) public view returns (LiquidationState, uint256) {
    // Load diamond storage
    LibPoolV1.PoolV1DiamondStorage storage ds = LibPoolV1
      .poolV1DiamondStorage();

    LibPoolV1.Position memory position = ds.positions[
      LibPoolV1.getPositionId(account, collateralToken, indexToken, isLong)
    ];

    (bool isProfit, uint256 delta) = GetterFacetInterface(address(this))
      .getDelta(
        indexToken,
        position.size,
        position.averagePrice,
        isLong,
        position.lastIncreasedTime
      );
    uint256 marginFee = GetterFacetInterface(address(this)).getFundingFee(
      account,
      collateralToken,
      indexToken,
      isLong,
      position.size,
      position.entryFundingRate
    );
    marginFee += GetterFacetInterface(address(this)).getPositionFee(
      account,
      collateralToken,
      indexToken,
      isLong,
      position.size
    );

    if (!isProfit && position.collateral < delta) {
      if (isRevertOnError) revert PerpTradeFacet_LossesExceedCollateral();
      return (LiquidationState.LIQUIDATE, marginFee);
    }

    uint256 remainingCollateral = position.collateral;
    if (!isProfit) {
      remainingCollateral -= delta;
    }

    if (remainingCollateral < marginFee) {
      if (isRevertOnError) revert PerpTradeFacet_FeeExceedCollateral();
      // Cap the fee to the remainingCollateral.
      return (LiquidationState.LIQUIDATE, remainingCollateral);
    }

    if (remainingCollateral < marginFee + ds.config.liquidationFeeUsd()) {
      if (isRevertOnError)
        revert PerpTradeFacet_LiquidationFeeExceedCollateral();
      // Cap the fee to the margin fee
      return (LiquidationState.LIQUIDATE, marginFee);
    }

    if (remainingCollateral * ds.config.maxLeverage() < position.size * BPS) {
      if (isRevertOnError) revert PerpTradeFacet_MaxLeverageExceed();
      return (LiquidationState.SOFT_LIQUIDATE, marginFee);
    }

    return (LiquidationState.HEALTHY, marginFee);
  }

  function _checkPosition(uint256 size, uint256 collateral) internal pure {
    if (size == 0) {
      if (collateral != 0) revert PerpTradeFacet_SizeSmallerThanCollateral();
      return;
    }
    if (size < collateral) revert PerpTradeFacet_SizeSmallerThanCollateral();
  }

  function _checkTokenInputs(
    address collateralToken,
    address indexToken,
    bool isLong
  ) internal view {
    // Load diamond storage
    LibPoolV1.PoolV1DiamondStorage storage ds = LibPoolV1
      .poolV1DiamondStorage();

    if (isLong) {
      if (collateralToken != indexToken) revert PerpTradeFacet_TokenMisMatch();
      if (!ds.config.isAcceptToken(collateralToken))
        revert PerpTradeFacet_BadToken();
      if (ds.config.isStableToken(collateralToken))
        revert PerpTradeFacet_CollateralTokenIsStable();
      return;
    }

    if (!ds.config.isAcceptToken(collateralToken))
      revert PerpTradeFacet_BadToken();
    if (!ds.config.isStableToken(collateralToken))
      revert PerpTradeFacet_CollateralTokenNotStable();
    if (ds.config.isStableToken(indexToken))
      revert PerpTradeFacet_IndexTokenIsStable();
    if (!ds.config.isShortableToken(indexToken))
      revert PerpTradeFacet_IndexTokenNotShortable();
  }

  function _collectMarginFee(
    address account,
    address collateralToken,
    address indexToken,
    bool isLong,
    uint256 sizeDelta,
    uint256 size,
    uint256 entryFundingRate
  ) internal returns (uint256) {
    // Load diamond storage
    LibPoolV1.PoolV1DiamondStorage storage ds = LibPoolV1
      .poolV1DiamondStorage();

    uint256 feeUsd = GetterFacetInterface(address(this)).getPositionFee(
      account,
      collateralToken,
      indexToken,
      isLong,
      sizeDelta
    );

    uint256 fundingFeeUsd = GetterFacetInterface(address(this)).getFundingFee(
      account,
      collateralToken,
      indexToken,
      isLong,
      size,
      entryFundingRate
    );

    feeUsd += fundingFeeUsd;

    uint256 feeTokens = LibPoolV1.convertUsde30ToTokens(
      collateralToken,
      feeUsd,
      true
    );
    ds.feeReserveOf[collateralToken] += feeTokens;

    emit CollectMarginFee(collateralToken, feeUsd, feeTokens);

    return feeUsd;
  }

  struct IncreasePositionLocalVars {
    address subAccount;
    bytes32 posId;
    uint256 price;
    uint256 feeUsd;
    uint256 collateralDelta;
    uint256 collateralDeltaUsd;
    uint256 reserveDelta;
  }

  /// @notice Increase leverage position size.
  /// @param primaryAccount The account that owns the position.
  /// @param subAccountId The sub account ID of the given account.
  /// @param collateralToken The collateral token.
  /// @param indexToken The index token.
  /// @param sizeDelta The size delta in USD units with 1e30 precision.
  /// @param isLong The exposure that the position is in. Either Long or Short.
  function increasePosition(
    address primaryAccount,
    uint256 subAccountId,
    address collateralToken,
    address indexToken,
    uint256 sizeDelta,
    bool isLong
  ) external {
    LibReentrancyGuard.lock();
    LibPoolV1.allowed(primaryAccount);

    // Load diamond storage
    LibPoolV1.PoolV1DiamondStorage storage ds = LibPoolV1
      .poolV1DiamondStorage();

    if (!ds.config.isLeverageEnable()) revert PerpTradeFacet_LeverageDisabled();
    _checkTokenInputs(collateralToken, indexToken, isLong);
    // TODO: Add validate increase position

    FundingRateFacetInterface(address(this)).updateFundingRate(
      collateralToken,
      indexToken
    );

    IncreasePositionLocalVars memory vars;

    vars.subAccount = LibPoolV1.getSubAccount(primaryAccount, subAccountId);

    vars.posId = LibPoolV1.getPositionId(
      vars.subAccount,
      collateralToken,
      indexToken,
      isLong
    );
    LibPoolV1.Position storage position = ds.positions[vars.posId];

    vars.price = isLong
      ? ds.oracle.getMaxPrice(indexToken)
      : ds.oracle.getMinPrice(indexToken);

    if (position.size == 0) {
      // If position size = 0, then it is a new position.
      // So make average price to equal to price.
      // And assign the primary account
      position.averagePrice = vars.price;
      position.primaryAccount = primaryAccount;
    }

    if (position.size > 0 && sizeDelta > 0) {
      // If position size > 0, then position is existed.
      // Need to calculate the next average price.
      position.averagePrice = GetterFacetInterface(address(this))
        .getPositionNextAveragePrice(
          indexToken,
          position.size,
          position.averagePrice,
          isLong,
          vars.price,
          sizeDelta,
          position.lastIncreasedTime
        );
    }

    vars.feeUsd = _collectMarginFee(
      vars.subAccount,
      collateralToken,
      indexToken,
      isLong,
      sizeDelta,
      position.size,
      position.entryFundingRate
    );
    vars.collateralDelta = LibPoolV1.pullTokens(collateralToken);
    vars.collateralDeltaUsd = LibPoolV1.convertTokensToUsde30(
      collateralToken,
      vars.collateralDelta,
      false
    );

    position.collateral += vars.collateralDeltaUsd;
    if (position.collateral < vars.feeUsd)
      revert PerpTradeFacet_CollateralNotCoverFee();

    position.collateral -= vars.feeUsd;
    position.entryFundingRate = GetterFacetInterface(address(this))
      .getEntryFundingRate(collateralToken, indexToken, isLong);
    position.size += sizeDelta;
    position.lastIncreasedTime = block.timestamp;

    if (position.size == 0) revert PerpTradeFacet_BadPositionSize();
    _checkPosition(position.size, position.collateral);
    checkLiquidation(
      vars.subAccount,
      collateralToken,
      indexToken,
      isLong,
      true
    );

    // Lock tokens in reserved to pay for profits on this position.
    uint256 reserveDelta = LibPoolV1.convertUsde30ToTokens(
      collateralToken,
      sizeDelta,
      false
    );
    position.reserveAmount += reserveDelta;
    LibPoolV1.increaseReserved(collateralToken, reserveDelta);

    if (isLong) {
      // guaranteedUsd stores the sum of (position.size - position.collateral) for all positions
      // if a fee is charged on the collateral then guaranteedUsd should be increased by that fee amount
      // since (position.size - position.collateral) would have increased by `fee`
      LibPoolV1.increaseGuaranteedUsd(collateralToken, sizeDelta + vars.feeUsd);
      LibPoolV1.decreaseGuaranteedUsd(collateralToken, vars.collateralDeltaUsd);

      // treat the deposited collateral as part of the pool
      LibPoolV1.increasePoolLiquidity(collateralToken, vars.collateralDelta);

      // fees need to be deducted from the pool since fees are deducted from position.collateral
      // and collateral is treated as part of the pool
      LibPoolV1.decreasePoolLiquidity(
        collateralToken,
        LibPoolV1.convertUsde30ToTokens(collateralToken, vars.feeUsd, true)
      );
    } else {
      if (ds.shortSizeOf[indexToken] == 0)
        ds.shortAveragePriceOf[indexToken] = vars.price;
      else
        ds.shortAveragePriceOf[indexToken] = GetterFacetInterface(address(this))
          .getNextShortAveragePrice(indexToken, vars.price, sizeDelta);

      LibPoolV1.increaseShortSize(indexToken, sizeDelta);
    }

    emit IncreasePosition(
      vars.posId,
      primaryAccount,
      subAccountId,
      collateralToken,
      indexToken,
      vars.collateralDeltaUsd,
      sizeDelta,
      isLong,
      vars.price,
      vars.feeUsd
    );
    emit UpdatePosition(
      vars.posId,
      position.size,
      position.collateral,
      position.averagePrice,
      position.entryFundingRate,
      position.reserveAmount,
      position.realizedPnl,
      vars.price
    );

    LibReentrancyGuard.unlock();
  }

  struct DecreasePositionLocalVars {
    address subAccount;
    bytes32 posId;
    uint256 collateral;
    uint256 reserveDelta;
    uint256 usdOut;
    uint256 usdOutAfterFee;
    uint256 price;
  }

  function decreasePosition(
    address primaryAccount,
    uint256 subAccountId,
    address collateralToken,
    address indexToken,
    uint256 collateralDelta,
    uint256 sizeDelta,
    bool isLong,
    address receiver
  ) external returns (uint256) {
    LibReentrancyGuard.lock();
    LibPoolV1.allowed(primaryAccount);

    uint256 amountOut = _decreasePosition(
      primaryAccount,
      subAccountId,
      collateralToken,
      indexToken,
      collateralDelta,
      sizeDelta,
      isLong,
      receiver
    );

    LibReentrancyGuard.unlock();

    return amountOut;
  }

  /// @notice Decrease leverage position size.
  function _decreasePosition(
    address primaryAccount,
    uint256 subAccountId,
    address collateralToken,
    address indexToken,
    uint256 collateralDelta,
    uint256 sizeDelta,
    bool isLong,
    address receiver
  ) internal returns (uint256) {
    // Load diamond storage
    LibPoolV1.PoolV1DiamondStorage storage ds = LibPoolV1
      .poolV1DiamondStorage();

    FundingRateFacetInterface(address(this)).updateFundingRate(
      collateralToken,
      indexToken
    );

    DecreasePositionLocalVars memory vars;

    vars.subAccount = GetterFacetInterface(address(this)).getSubAccount(
      primaryAccount,
      subAccountId
    );

    vars.posId = LibPoolV1.getPositionId(
      vars.subAccount,
      collateralToken,
      indexToken,
      isLong
    );
    LibPoolV1.Position storage position = ds.positions[vars.posId];
    if (position.size == 0) revert PerpTradeFacet_BadPositionSize();
    if (sizeDelta > position.size) revert PerpTradeFacet_BadSizeDelta();
    if (collateralDelta > position.collateral)
      revert PerpTradeFacet_BadCollateralDelta();

    // Reduce position's reserveAmount proportionally to sizeDelta and positionSize.
    // Then decrease reserved token in the pool as well.
    vars.reserveDelta = (position.reserveAmount * sizeDelta) / position.size;
    position.reserveAmount -= vars.reserveDelta;
    LibPoolV1.decreaseReserved(collateralToken, vars.reserveDelta);

    // Preload position's collateral here as _reduceCollateral will alter it
    vars.collateral = position.collateral;

    // Perform the actual reduce collateral
    (vars.usdOut, vars.usdOutAfterFee) = _reduceCollateral(
      vars.subAccount,
      collateralToken,
      indexToken,
      collateralDelta,
      sizeDelta,
      isLong
    );

    if (position.size != sizeDelta) {
      // Partially close the position
      position.entryFundingRate = GetterFacetInterface(address(this))
        .getEntryFundingRate(collateralToken, indexToken, isLong);
      position.size -= sizeDelta;

      _checkPosition(position.size, position.collateral);
      checkLiquidation(
        vars.subAccount,
        collateralToken,
        indexToken,
        isLong,
        true
      );

      if (isLong) {
        // Update guaranteedUsd by increase by delta of collateralBeforeReduce and collateralAfterReduce
        // Then decrease by sizeDelta
        LibPoolV1.increaseGuaranteedUsd(
          collateralToken,
          vars.collateral - position.collateral
        );
        LibPoolV1.decreaseGuaranteedUsd(collateralToken, sizeDelta);
      }

      vars.price = isLong
        ? ds.oracle.getMinPrice(indexToken)
        : ds.oracle.getMaxPrice(indexToken);

      emit DecreasePosition(
        vars.posId,
        primaryAccount,
        subAccountId,
        collateralToken,
        indexToken,
        collateralDelta,
        sizeDelta,
        isLong,
        vars.price,
        vars.usdOut - vars.usdOutAfterFee
      );
      emit UpdatePosition(
        vars.posId,
        position.size,
        position.collateral,
        position.averagePrice,
        position.entryFundingRate,
        position.reserveAmount,
        position.realizedPnl,
        vars.price
      );
    } else {
      // Close position
      if (isLong) {
        LibPoolV1.increaseGuaranteedUsd(collateralToken, vars.collateral);
        LibPoolV1.decreaseGuaranteedUsd(collateralToken, sizeDelta);
      }

      vars.price = isLong
        ? ds.oracle.getMinPrice(indexToken)
        : ds.oracle.getMaxPrice(indexToken);

      delete ds.positions[vars.posId];

      emit DecreasePosition(
        vars.posId,
        primaryAccount,
        subAccountId,
        collateralToken,
        indexToken,
        collateralDelta,
        sizeDelta,
        isLong,
        vars.price,
        vars.usdOut - vars.usdOutAfterFee
      );
      emit ClosePosition(
        vars.posId,
        position.size,
        position.collateral,
        position.averagePrice,
        position.entryFundingRate,
        position.reserveAmount,
        position.realizedPnl
      );
    }

    if (!isLong) LibPoolV1.decreaseShortSize(indexToken, sizeDelta);

    if (vars.usdOut > 0) {
      if (isLong)
        LibPoolV1.decreasePoolLiquidity(
          collateralToken,
          LibPoolV1.convertUsde30ToTokens(collateralToken, vars.usdOut, true)
        );
      uint256 amountOutAfterFee = LibPoolV1.convertUsde30ToTokens(
        collateralToken,
        vars.usdOutAfterFee,
        true
      );
      LibPoolV1.pushTokens(collateralToken, receiver, amountOutAfterFee);

      return amountOutAfterFee;
    }

    return 0;
  }

  function liquidate(
    address primaryAccount,
    uint256 subAccountId,
    address collateralToken,
    address indexToken,
    bool isLong,
    address to
  ) external {
    LibReentrancyGuard.lock();

    // Load diamond storage
    LibPoolV1.PoolV1DiamondStorage storage ds = LibPoolV1
      .poolV1DiamondStorage();

    if (!ds.config.isAllowedLiquidators(msg.sender))
      revert PerpTradeFacet_BadLiquidator();

    FundingRateFacetInterface(address(this)).updateFundingRate(
      collateralToken,
      indexToken
    );

    address subAccount = GetterFacetInterface(address(this)).getSubAccount(
      primaryAccount,
      subAccountId
    );

    bytes32 posId = LibPoolV1.getPositionId(
      subAccount,
      collateralToken,
      indexToken,
      isLong
    );
    LibPoolV1.Position memory position = ds.positions[posId];

    if (position.size == 0) revert PerpTradeFacet_BadPositionSize();

    (LiquidationState liquidationState, uint256 marginFee) = checkLiquidation(
      subAccount,
      collateralToken,
      indexToken,
      isLong,
      false
    );
    if (liquidationState == LiquidationState.SOFT_LIQUIDATE) {
      // Position's leverage is exceeded, but there is enough collateral to soft-liquidate.
      _decreasePosition(
        primaryAccount,
        subAccountId,
        collateralToken,
        indexToken,
        0,
        position.size,
        isLong,
        position.primaryAccount
      );

      LibReentrancyGuard.unlock();
      return;
    }

    uint256 feeTokens = LibPoolV1.convertUsde30ToTokens(
      collateralToken,
      marginFee,
      true
    );
    ds.feeReserveOf[collateralToken] += feeTokens;
    emit CollectMarginFee(collateralToken, marginFee, feeTokens);

    // Decreases reserve amount of a collateral token.
    LibPoolV1.decreaseReserved(collateralToken, position.reserveAmount);

    if (isLong) {
      // If it is long, then decrease guaranteed usd and pool's liquidity
      LibPoolV1.decreaseGuaranteedUsd(
        collateralToken,
        position.size - position.collateral
      );
      LibPoolV1.decreasePoolLiquidity(
        collateralToken,
        LibPoolV1.convertUsde30ToTokens(collateralToken, marginFee, true)
      );
    }

    uint256 markPrice = isLong
      ? ds.oracle.getMinPrice(indexToken)
      : ds.oracle.getMaxPrice(indexToken);

    emit LiquidatePosition(
      posId,
      primaryAccount,
      subAccountId,
      collateralToken,
      indexToken,
      isLong,
      position.size,
      position.collateral,
      position.reserveAmount,
      position.realizedPnl,
      markPrice
    );

    if (!isLong && marginFee < position.collateral) {
      uint256 remainingCollateral = position.collateral - marginFee;
      LibPoolV1.increasePoolLiquidity(
        collateralToken,
        LibPoolV1.convertUsde30ToTokens(
          collateralToken,
          remainingCollateral,
          true
        )
      );
    }

    if (!isLong) LibPoolV1.decreaseShortSize(indexToken, position.size);

    delete ds.positions[posId];

    // Pay liquidation bounty with the pool's liquidity
    LibPoolV1.decreasePoolLiquidity(
      collateralToken,
      LibPoolV1.convertUsde30ToTokens(
        collateralToken,
        ds.config.liquidationFeeUsd(),
        true
      )
    );
    LibPoolV1.pushTokens(
      collateralToken,
      to,
      LibPoolV1.convertUsde30ToTokens(
        collateralToken,
        ds.config.liquidationFeeUsd(),
        true
      )
    );

    LibReentrancyGuard.unlock();
  }

  struct ReduceCollateralLocalVars {
    uint256 feeUsd;
    uint256 delta;
    uint256 usdOut;
    uint256 usdOutAfterFee;
    bool isProfit;
  }

  function _reduceCollateral(
    address account,
    address collateralToken,
    address indexToken,
    uint256 collateralDelta,
    uint256 sizeDelta,
    bool isLong
  ) internal returns (uint256, uint256) {
    // Load diamond storage
    LibPoolV1.PoolV1DiamondStorage storage ds = LibPoolV1
      .poolV1DiamondStorage();

    bytes32 posId = LibPoolV1.getPositionId(
      account,
      collateralToken,
      indexToken,
      isLong
    );
    LibPoolV1.Position storage position = ds.positions[posId];

    ReduceCollateralLocalVars memory vars;

    // Collect margin fee
    vars.feeUsd = _collectMarginFee(
      account,
      collateralToken,
      indexToken,
      isLong,
      sizeDelta,
      position.size,
      position.entryFundingRate
    );

    // Calculate position's delta.
    (vars.isProfit, vars.delta) = GetterFacetInterface(address(this)).getDelta(
      indexToken,
      position.size,
      position.averagePrice,
      isLong,
      position.lastIncreasedTime
    );
    // Adjusting delta to be proportionally to size delta and position size
    vars.delta = (vars.delta * sizeDelta) / position.size;

    if (vars.isProfit && vars.delta > 0) {
      // Position is profitable. Handle profits here.
      vars.usdOut = vars.delta;

      // realized PnL
      position.realizedPnl += int256(vars.delta);

      if (!isLong)
        // If it is a short position, payout profits from the liquidity.
        LibPoolV1.decreasePoolLiquidity(
          collateralToken,
          LibPoolV1.convertUsde30ToTokens(collateralToken, vars.delta, true)
        );
    }

    if (!vars.isProfit && vars.delta > 0) {
      // Position is not profitable. Handle losses here.

      // Take out collateral
      position.collateral -= vars.delta;

      if (!isLong)
        // If it is a short position, add short losses to pool liquidity.
        LibPoolV1.increasePoolLiquidity(
          collateralToken,
          LibPoolV1.convertUsde30ToTokens(collateralToken, vars.delta, true)
        );

      // realized PnL
      position.realizedPnl -= int256(vars.delta);
    }

    // Reduce position's collateral by collateralDelta
    if (collateralDelta > 0) {
      vars.usdOut += collateralDelta;
      position.collateral -= collateralDelta;
    }

    // If position to be closed, then remove all collateral from it.
    if (position.size == sizeDelta) {
      vars.usdOut += position.collateral;
      position.collateral = 0;
    }

    vars.usdOutAfterFee = vars.usdOut;
    if (vars.usdOut > vars.feeUsd)
      // if usdOut is enough to cover fee, then take it out from usdOut
      vars.usdOutAfterFee -= vars.feeUsd;
    else {
      // take fee from the collateral
      position.collateral -= vars.feeUsd;
      if (isLong) {
        LibPoolV1.decreasePoolLiquidity(
          collateralToken,
          LibPoolV1.convertUsde30ToTokens(collateralToken, vars.feeUsd, true)
        );
      }
    }

    emit UpdatePnL(posId, vars.isProfit, vars.delta);

    return (vars.usdOut, vars.usdOutAfterFee);
  }
}