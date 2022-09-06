// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import { MintableTokenInterface } from "../../../interfaces/MintableTokenInterface.sol";

interface GetterFacetInterface {
  function feeReserveOf(address token) external view returns (uint256);

  function guaranteedUsdOf(address token) external view returns (uint256);

  function plp() external view returns (MintableTokenInterface);

  function lastAddLiquidityAtOf(address user) external view returns (uint256);

  function liquidityOf(address token) external view returns (uint256);

  function reservedOf(address token) external view returns (uint256);

  function totalUsdDebt() external view returns (uint256);

  function usdDebtOf(address token) external view returns (uint256);

  function getDelta(
    address indexToken,
    uint256 size,
    uint256 averagePrice,
    bool isLong,
    uint256 lastIncreasedTime
  ) external view returns (bool, uint256);

  function getEntryFundingRate(
    address collateralToken,
    address indexToken,
    bool isLong
  ) external view returns (uint256);

  function getFundingFee(
    address account,
    address collateralToken,
    address indexToken,
    bool isLong,
    uint256 size,
    uint256 entryFundingRate
  ) external view returns (uint256);

  function getNextShortAveragePrice(
    address indexToken,
    uint256 nextPrice,
    uint256 sizeDelta
  ) external view returns (uint256);

  struct GetPositionReturnVars {
    address primaryAccount;
    uint256 size;
    uint256 collateral;
    uint256 averagePrice;
    uint256 entryFundingRate;
    uint256 reserveAmount;
    uint256 realizedPnl;
    bool hasProfit;
    uint256 lastIncreasedTime;
  }

  function getPosition(
    address account,
    address collateralToken,
    address indexToken,
    bool isLong
  ) external view returns (GetPositionReturnVars memory);

  function getPositionWithSubAccountId(
    address primaryAccount,
    uint256 subAccountId,
    address collateralToken,
    address indexToken,
    bool isLong
  ) external view returns (GetPositionReturnVars memory);

  function getPositionDelta(
    address primaryAccount,
    uint256 subAccountId,
    address collateralToken,
    address indexToken,
    bool isLong
  ) external view returns (bool, uint256);

  function getPositionFee(
    address account,
    address collateralToken,
    address indexToken,
    bool isLong,
    uint256 sizeDelta
  ) external view returns (uint256);

  function getPositionLeverage(
    address primaryAccount,
    uint256 subAccountId,
    address collateralToken,
    address indexToken,
    bool isLong
  ) external view returns (uint256);

  function getPositionNextAveragePrice(
    address indexToken,
    uint256 size,
    uint256 averagePrice,
    bool isLong,
    uint256 nextPrice,
    uint256 sizeDelta,
    uint256 lastIncreasedTime
  ) external view returns (uint256);

  function getRedemptionCollateral(address token)
    external
    view
    returns (uint256);

  function getRedemptionCollateralUsd(address token)
    external
    view
    returns (uint256);

  function getSubAccount(address primaryAccount, uint256 subAccountId)
    external
    pure
    returns (address);

  function getTargetValue(address token) external view returns (uint256);

  function getAddLiquidityFeeBps(address token, uint256 value)
    external
    view
    returns (uint256);

  function getAum(bool isUseMaxPrice) external view returns (uint256);

  function getAumE18(bool isUseMaxPrice) external view returns (uint256);

  function getRemoveLiquidityFeeBps(address token, uint256 value)
    external
    view
    returns (uint256);

  function getSwapFeeBps(
    address tokenIn,
    address tokenOut,
    uint256 usdDebt
  ) external view returns (uint256);

  function getNextFundingRate(address token) external view returns (uint256);
}
