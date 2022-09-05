// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { BaseTest, console, stdError, PoolConfig, PoolMath, PoolOracle, Pool, PoolRouter } from "../../base/BaseTest.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MockWNative } from "src/tests/mocks/MockWNative.sol";

abstract contract Pool_BaseTest is BaseTest {
  PoolConfig internal poolConfig;
  PoolMath internal poolMath;
  PoolOracle internal poolOracle;
  Pool internal pool;
  PoolRouter internal poolRouter;

  function setUp() public virtual {
    BaseTest.PoolConfigConstructorParams memory poolConfigParams = BaseTest
      .PoolConfigConstructorParams({
        treasury: TREASURY,
        fundingInterval: 8 hours,
        mintBurnFeeBps: 30,
        taxBps: 50,
        stableFundingRateFactor: 600,
        fundingRateFactor: 600,
        liquidityCoolDownPeriod: 1 days,
        liquidationFeeUsd: 5 * 10**30
      });

    (poolOracle, poolConfig, poolMath, pool) = deployFullPool(poolConfigParams);

    (
      address[] memory tokens,
      PoolOracle.PriceFeedInfo[] memory priceFeedInfo
    ) = buildDefaultSetPriceFeedInput();
    poolOracle.setPriceFeed(tokens, priceFeedInfo);

    poolRouter = deployPoolRouter(address(matic));
    poolConfig.setRouter(address(poolRouter));
  }

  function checkPoolBalanceWithState(address token, uint256 offset) internal {
    uint256 balance = IERC20(token).balanceOf(address(pool));
    assertEq(
      balance,
      pool.liquidityOf(token) + pool.feeReserveOf(token) + offset
    );
  }
}
