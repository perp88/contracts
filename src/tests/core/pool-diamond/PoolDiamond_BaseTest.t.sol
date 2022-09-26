// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { BaseTest, console, stdError, MockStrategy, MockDonateVault, PLP, MockFlashLoanBorrower, PoolConfig, LibPoolConfigV1, PoolOracle, Pool, PoolRouter, OwnershipFacetInterface, GetterFacetInterface, LiquidityFacetInterface, PerpTradeFacetInterface, AdminFacetInterface, FarmFacetInterface, AccessControlFacetInterface, LibAccessControl } from "../../base/BaseTest.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract PoolDiamond_BaseTest is BaseTest {
  PoolOracle internal poolOracle;
  address internal poolDiamond;
  PoolRouter internal poolRouter;
  PLP internal plp;

  AdminFacetInterface internal poolAdminFacet;
  GetterFacetInterface internal poolGetterFacet;
  LiquidityFacetInterface internal poolLiquidityFacet;
  PerpTradeFacetInterface internal poolPerpTradeFacet;
  FarmFacetInterface internal poolFarmFacet;
  AccessControlFacetInterface internal poolAccessControlFacet;

  function setUp() public virtual {
    BaseTest.PoolConfigConstructorParams memory poolConfigParams = BaseTest
      .PoolConfigConstructorParams({
        treasury: TREASURY,
        fundingInterval: 1 hours,
        mintBurnFeeBps: 30,
        taxBps: 50,
        stableBorrowingRateFactor: 100,
        borrowingRateFactor: 100,
        fundingRateFactor: 25,
        liquidationFeeUsd: 5 * 10**30
      });

    (poolOracle, poolDiamond) = deployPoolDiamond(poolConfigParams);

    (
      address[] memory tokens,
      PoolOracle.PriceFeedInfo[] memory priceFeedInfo
    ) = buildDefaultSetPriceFeedInput();
    poolOracle.setPriceFeed(tokens, priceFeedInfo);

    poolAdminFacet = AdminFacetInterface(poolDiamond);
    poolGetterFacet = GetterFacetInterface(poolDiamond);
    poolLiquidityFacet = LiquidityFacetInterface(poolDiamond);
    poolPerpTradeFacet = PerpTradeFacetInterface(poolDiamond);
    poolFarmFacet = FarmFacetInterface(poolDiamond);
    poolAccessControlFacet = AccessControlFacetInterface(poolDiamond);

    plp = poolGetterFacet.plp();

    poolRouter = deployPoolRouter(address(matic));
    poolAdminFacet.setRouter(address(poolRouter));

    // Grant Farm Keeper Role For This testing contract
    poolAccessControlFacet.grantRole(
      LibAccessControl.FARM_KEEPER,
      address(this)
    );
  }

  function checkPoolBalanceWithState(address token, int256 offset) internal {
    uint256 balance = IERC20(token).balanceOf(address(poolDiamond));
    assertEq(
      balance,
      uint256(
        int256(poolGetterFacet.liquidityOf(token)) +
          int256(poolGetterFacet.feeReserveOf(token)) +
          offset
      )
    );
  }
}
