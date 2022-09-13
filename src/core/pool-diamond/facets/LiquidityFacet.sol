// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { LibReentrancyGuard } from "../libraries/LibReentrancyGuard.sol";
import { LibPoolV1 } from "../libraries/LibPoolV1.sol";
import { LibPoolConfigV1 } from "../libraries/LibPoolConfigV1.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { FarmFacetInterface } from "../interfaces/FarmFacetInterface.sol";
import { GetterFacetInterface } from "../interfaces/GetterFacetInterface.sol";
import { FundingRateFacetInterface } from "../interfaces/FundingRateFacetInterface.sol";
import { LiquidityFacetInterface } from "../interfaces/LiquidityFacetInterface.sol";
import { FlashLoanBorrowerInterface } from "../../../interfaces/FlashLoanBorrowerInterface.sol";
import { StrategyInterface } from "../../../interfaces/StrategyInterface.sol";

import { console } from "../../../tests/utils/console.sol";

contract LiquidityFacet is LiquidityFacetInterface {
  using SafeERC20 for IERC20;
  using SafeCast for uint256;

  error LiquidityFacet_BadAmount();
  error LiquidityFacet_BadAmountOut();
  error LiquidityFacet_BadFlashLoan();
  error LiquidityFacet_BadLength();
  error LiquidityFacet_BadToken();
  error LiquidityFacet_BadTokenIn();
  error LiquidityFacet_BadTokenOut();
  error LiquidityFacet_CoolDown();
  error LiquidityFacet_InsufficientLiquidityMint();
  error LiquidityFacet_LiquidityBuffer();
  error LiquidityFacet_SameTokenInTokenOut();
  error LiquidityFacet_Slippage();
  error LiquidityFacet_SwapDisabled();

  uint256 internal constant PRICE_PRECISION = 10**30;
  uint256 internal constant BPS = 10000;
  uint256 internal constant USD_DECIMALS = 18;

  event AddLiquidity(
    address account,
    address token,
    uint256 amount,
    uint256 aum,
    uint256 supply,
    uint256 usdDebt,
    uint256 mintAmount
  );
  event CollectSwapFee(address token, uint256 feeUsd, uint256 fee);
  event ExitPool(
    address account,
    address token,
    uint256 usdAmount,
    uint256 amountOut,
    uint256 burnFeeBps
  );
  event FlashLoan(
    address borrower,
    address token,
    uint256 amount,
    uint256 fee,
    address receiver
  );
  event JoinPool(
    address account,
    address token,
    uint256 amount,
    uint256 usdDebt,
    uint256 mintFeeBps
  );
  event RemoveLiquidity(
    address account,
    address tokenOut,
    uint256 liquidity,
    uint256 aum,
    uint256 supply,
    uint256 usdDebt,
    uint256 amountOut
  );
  event StrategyDivest(address token, uint256 amount);
  event Swap(
    address account,
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 amountOut,
    uint256 amountOutAfterFee,
    uint256 swapFeeBps
  );

  function _collectSwapFee(
    address token,
    uint256 tokenPriceUsd,
    uint256 amount,
    uint256 feeBps
  ) internal returns (uint256) {
    // Load diamond storage
    LibPoolV1.PoolV1DiamondStorage storage poolV1ds = LibPoolV1
      .poolV1DiamondStorage();

    uint256 amountAfterFee = (amount * (BPS - feeBps)) / BPS;
    uint256 fee = amount - amountAfterFee;

    poolV1ds.feeReserveOf[token] += fee;

    emit CollectSwapFee(token, fee * tokenPriceUsd, fee);

    return amountAfterFee;
  }

  modifier allowed(address account) {
    LibPoolV1.allowed(account);
    _;
  }

  modifier nonReentrant() {
    LibReentrancyGuard.lock();
    _;
    LibReentrancyGuard.unlock();
  }

  function _realizedFarmPnL(address token) internal {
    // Load PoolConfigV1 diamond storage
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigV1ds = LibPoolConfigV1.poolConfigV1DiamondStorage();

    StrategyInterface strategy = poolConfigV1ds.strategyOf[token];

    if (address(strategy) != address(0))
      FarmFacetInterface(address(this)).farm(token, false);
  }

  function addLiquidity(
    address account,
    address token,
    address receiver
  ) external nonReentrant allowed(account) returns (uint256) {
    // LOAD poolV1 diamond storage
    LibPoolV1.PoolV1DiamondStorage storage poolV1ds = LibPoolV1
      .poolV1DiamondStorage();

    // Pull tokens
    uint256 amount = LibPoolV1.pullTokens(token);

    // Check
    if (!LibPoolConfigV1.isAcceptToken(token)) revert LiquidityFacet_BadToken();
    if (amount == 0) revert LiquidityFacet_BadAmount();

    _realizedFarmPnL(token);

    uint256 aum = GetterFacetInterface(address(this)).getAumE18(true);
    uint256 lpSupply = poolV1ds.plp.totalSupply();

    uint256 usdDebt = _join(token, amount, receiver);
    uint256 mintAmount = aum == 0 ? usdDebt : (usdDebt * lpSupply) / aum;

    poolV1ds.plp.mint(receiver, mintAmount);

    poolV1ds.lastAddLiquidityAtOf[account] = block.timestamp;

    emit AddLiquidity(
      account,
      token,
      amount,
      aum,
      lpSupply,
      usdDebt,
      mintAmount
    );

    return mintAmount;
  }

  function _join(
    address token,
    uint256 amount,
    address receiver
  ) internal returns (uint256) {
    // LOAD diamond storage
    LibPoolV1.PoolV1DiamondStorage storage poolV1ds = LibPoolV1
      .poolV1DiamondStorage();

    FundingRateFacetInterface(address(this)).updateFundingRate(token, token);

    uint256 price = poolV1ds.oracle.getMinPrice(token);

    uint256 tokenValueUsd = (amount * price) / PRICE_PRECISION;
    uint8 tokenDecimals = LibPoolConfigV1.getTokenDecimalsOf(token);
    tokenValueUsd = LibPoolV1.convertTokenDecimals(
      tokenDecimals,
      USD_DECIMALS,
      tokenValueUsd
    );
    if (tokenValueUsd == 0) revert LiquidityFacet_InsufficientLiquidityMint();

    uint256 feeBps = GetterFacetInterface(address(this)).getAddLiquidityFeeBps(
      token,
      tokenValueUsd
    );
    uint256 amountAfterDepositFee = _collectSwapFee(
      token,
      price,
      amount,
      feeBps
    );
    uint256 usdDebt = LibPoolV1.convertTokenDecimals(
      tokenDecimals,
      USD_DECIMALS,
      (amountAfterDepositFee * price) / PRICE_PRECISION
    );

    LibPoolV1.increaseUsdDebt(token, usdDebt);
    LibPoolV1.increasePoolLiquidity(token, amountAfterDepositFee);

    poolV1ds.totalUsdDebt += usdDebt;

    emit JoinPool(receiver, token, amount, usdDebt, feeBps);

    return usdDebt;
  }

  function _tokenOut(
    address token,
    address to,
    uint256 amountOut
  ) internal {
    // Load PoolV1 diamond storage
    LibPoolV1.PoolV1DiamondStorage storage poolV1ds = LibPoolV1
      .poolV1DiamondStorage();

    // Load PoolConfigV1 diamond storage
    LibPoolConfigV1.PoolConfigV1DiamondStorage
      storage poolConfigV1ds = LibPoolConfigV1.poolConfigV1DiamondStorage();

    StrategyInterface strategy = poolConfigV1ds.strategyOf[token];
    uint256 poolBalance = IERC20(token).balanceOf(address(this)) -
      poolV1ds.feeReserveOf[token];
    if (address(strategy) != address(0) && poolBalance < amountOut) {
      // Handle when physical tokens in Pool < amountOut, then we need to withdraw from strategy.
      LibPoolConfigV1.StrategyData storage strategyData = poolConfigV1ds
        .strategyDataOf[token];

      console.log("here");
      uint256 amountIn = amountOut - poolBalance;

      // Witthdraw funds from strategy
      uint256 actualAmountIn = strategy.withdraw(amountIn);
      // Update totalOf[token] to sync physical balance with pool state
      LibPoolV1.updateTotalOf(token);

      // Update how much pool put in the strategy
      strategyData.principle -= actualAmountIn.toUint128();

      emit StrategyDivest(token, actualAmountIn);
    }
    LibPoolV1.pushTokens(token, to, amountOut);
  }

  function removeLiquidity(
    address account,
    address tokenOut,
    address receiver
  ) external nonReentrant allowed(account) returns (uint256) {
    // LOAD diamond storage
    LibPoolV1.PoolV1DiamondStorage storage poolV1ds = LibPoolV1
      .poolV1DiamondStorage();

    uint256 liquidity = poolV1ds.plp.balanceOf(address(this));

    if (!LibPoolConfigV1.isAcceptToken(tokenOut))
      revert LiquidityFacet_BadToken();
    if (liquidity == 0) revert LiquidityFacet_BadAmount();
    if (
      poolV1ds.lastAddLiquidityAtOf[account] +
        LibPoolConfigV1.liquidityCoolDownDuration() >
      block.timestamp
    ) {
      revert LiquidityFacet_CoolDown();
    }

    _realizedFarmPnL(tokenOut);

    uint256 aum = GetterFacetInterface(address(this)).getAumE18(false);
    uint256 lpSupply = poolV1ds.plp.totalSupply();

    uint256 lpUsdValue = (liquidity * aum) / lpSupply;
    // Adjust totalUsdDebt if lpUsdValue > totalUsdDebt.
    if (poolV1ds.totalUsdDebt < lpUsdValue)
      poolV1ds.totalUsdDebt += lpUsdValue - poolV1ds.totalUsdDebt;
    uint256 amountOut = _exit(tokenOut, lpUsdValue, receiver);

    poolV1ds.plp.burn(address(this), liquidity);
    _tokenOut(tokenOut, receiver, amountOut);

    emit RemoveLiquidity(
      account,
      tokenOut,
      liquidity,
      aum,
      lpSupply,
      lpUsdValue,
      amountOut
    );

    return amountOut;
  }

  function _exit(
    address token,
    uint256 usdValue,
    address receiver
  ) internal returns (uint256) {
    // LOAD diamond storage
    LibPoolV1.PoolV1DiamondStorage storage poolV1ds = LibPoolV1
      .poolV1DiamondStorage();

    FundingRateFacetInterface(address(this)).updateFundingRate(token, token);

    uint256 tokenPrice = poolV1ds.oracle.getMaxPrice(token);
    uint256 amountOut = LibPoolV1.convertTokenDecimals(
      18,
      LibPoolConfigV1.getTokenDecimalsOf(token),
      (usdValue * PRICE_PRECISION) / tokenPrice
    );
    if (amountOut == 0) revert LiquidityFacet_BadAmountOut();

    LibPoolV1.decreaseUsdDebt(token, usdValue);
    LibPoolV1.decreasePoolLiquidity(token, amountOut);

    poolV1ds.totalUsdDebt -= usdValue;

    uint256 burnFeeBps = GetterFacetInterface(address(this))
      .getRemoveLiquidityFeeBps(token, usdValue);
    amountOut = _collectSwapFee(
      token,
      poolV1ds.oracle.getMinPrice(token),
      amountOut,
      burnFeeBps
    );
    if (amountOut == 0) revert LiquidityFacet_BadAmountOut();

    emit ExitPool(receiver, token, usdValue, amountOut, burnFeeBps);

    return amountOut;
  }

  function swap(
    address tokenIn,
    address tokenOut,
    uint256 minAmountOut,
    address receiver
  ) external nonReentrant returns (uint256) {
    // LOAD diamond storage
    LibPoolV1.PoolV1DiamondStorage storage poolV1ds = LibPoolV1
      .poolV1DiamondStorage();

    // Pull Tokens
    uint256 amountIn = LibPoolV1.pullTokens(tokenIn);

    if (!LibPoolConfigV1.isSwapEnable()) revert LiquidityFacet_SwapDisabled();
    if (!LibPoolConfigV1.isAcceptToken(tokenIn))
      revert LiquidityFacet_BadTokenIn();
    if (!LibPoolConfigV1.isAcceptToken(tokenOut))
      revert LiquidityFacet_BadTokenOut();
    if (tokenIn == tokenOut) revert LiquidityFacet_SameTokenInTokenOut();
    if (amountIn == 0) revert LiquidityFacet_BadAmount();

    FundingRateFacetInterface(address(this)).updateFundingRate(
      tokenIn,
      tokenIn
    );
    FundingRateFacetInterface(address(this)).updateFundingRate(
      tokenOut,
      tokenOut
    );

    uint256 priceIn = poolV1ds.oracle.getMinPrice(tokenIn);
    uint256 priceOut = poolV1ds.oracle.getMaxPrice(tokenOut);

    uint256 amountOut = (amountIn * priceIn) / priceOut;
    amountOut = LibPoolV1.convertTokenDecimals(
      LibPoolConfigV1.getTokenDecimalsOf(tokenIn),
      LibPoolConfigV1.getTokenDecimalsOf(tokenOut),
      amountOut
    );

    // Adjust USD debt as swap shifted the debt between two assets
    uint256 usdDebt = (amountIn * priceIn) / PRICE_PRECISION;
    usdDebt = LibPoolV1.convertTokenDecimals(
      LibPoolConfigV1.getTokenDecimalsOf(tokenIn),
      USD_DECIMALS,
      usdDebt
    );

    uint256 swapFeeBps = GetterFacetInterface(address(this)).getSwapFeeBps(
      tokenIn,
      tokenOut,
      usdDebt
    );
    uint256 amountOutAfterFee = _collectSwapFee(
      tokenOut,
      poolV1ds.oracle.getMinPrice(tokenOut),
      amountOut,
      swapFeeBps
    );

    LibPoolV1.increasePoolLiquidity(tokenIn, amountIn);
    LibPoolV1.increaseUsdDebt(tokenIn, usdDebt);

    LibPoolV1.decreasePoolLiquidity(tokenOut, amountOut);
    LibPoolV1.decreaseUsdDebt(tokenOut, usdDebt);

    // Buffer check
    if (
      poolV1ds.liquidityOf[tokenOut] <
      LibPoolConfigV1.getTokenBufferLiquidityOf(tokenOut)
    ) revert LiquidityFacet_LiquidityBuffer();

    // Slippage check
    if (amountOutAfterFee < minAmountOut) revert LiquidityFacet_Slippage();

    // Transfer amount out.
    LibPoolV1.pushTokens(tokenOut, receiver, amountOutAfterFee);

    emit Swap(
      receiver,
      tokenIn,
      tokenOut,
      amountIn,
      amountOut,
      amountOutAfterFee,
      swapFeeBps
    );

    return amountOutAfterFee;
  }

  function flashLoan(
    FlashLoanBorrowerInterface borrower,
    address[] calldata receivers,
    address[] calldata tokens,
    uint256[] calldata amounts,
    bytes calldata data
  ) external nonReentrant {
    if (receivers.length != tokens.length || receivers.length != amounts.length)
      revert LiquidityFacet_BadLength();

    LibPoolV1.PoolV1DiamondStorage storage poolV1ds = LibPoolV1
      .poolV1DiamondStorage();

    uint256[] memory fees = new uint256[](tokens.length);
    for (uint256 i = 0; i < tokens.length; ) {
      fees[i] = (amounts[i] * LibPoolConfigV1.flashLoanFeeBps()) / BPS;

      IERC20(tokens[i]).safeTransfer(receivers[i], amounts[i]);

      unchecked {
        ++i;
      }
    }

    borrower.onFlashLoan(msg.sender, tokens, amounts, fees, data);

    for (uint256 i = 0; i < tokens.length; ) {
      if (
        IERC20(tokens[i]).balanceOf(address(this)) <
        poolV1ds.totalOf[tokens[i]] + fees[i]
      ) revert LiquidityFacet_BadFlashLoan();

      // Collect fee
      poolV1ds.feeReserveOf[tokens[i]] += fees[i];

      emit FlashLoan(
        address(borrower),
        tokens[i],
        amounts[i],
        fees[i],
        receivers[i]
      );

      unchecked {
        ++i;
      }
    }
  }
}
