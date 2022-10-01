// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { PoolDiamond_BaseTest, console, Pool, LibPoolConfigV1, LiquidityFacetInterface, GetterFacetInterface, PerpTradeFacetInterface } from "./PoolDiamond_BaseTest.t.sol";

contract PoolDiamond_Orderbook is PoolDiamond_BaseTest {
  function setUp() public override {
    super.setUp();

    (
      address[] memory tokens2,
      LibPoolConfigV1.TokenConfig[] memory tokenConfigs2
    ) = buildDefaultSetTokenConfigInput2();

    poolAdminFacet.setTokenConfigs(tokens2, tokenConfigs2);
  }

  function testCorrectness_WhenLong() external {
    maticPriceFeed.setLatestAnswer(400 * 10**8);
    daiPriceFeed.setLatestAnswer(1 * 10**8);

    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    wbtc.mint(ALICE, 1 * 10**8);

    // ----- Start Alice session -----
    vm.deal(ALICE, 100 ether);
    vm.startPrank(ALICE);

    // Alice add liquidity with 117499 satoshi
    wbtc.approve(address(poolRouter), 117499);
    poolRouter.addLiquidity(
      address(poolDiamond),
      address(wbtc),
      117499,
      ALICE,
      0
    );

    // After Alice added 117499 satoshi as a liquidity,
    // the following conditions should be met:
    // 1. Alice should get 46.8584 PLP
    // 2. Pool should make 353 sathoshi
    // 3. Pool's AUM by min price should be:
    // 0.00117499 * (1-0.003) * 40000 = 46.8584 USD
    // 4. Pool's AUM by max price should be:
    // 0.00117499 * (1-0.003) * 41000 = 48.02986 USD
    // 5. WBTC's USD debt should be 48.8584 USD
    // 6. WBTC's liquidity should be 117499 - 353 = 117146 satoshi
    // 7. Redeemable WBTC in USD should be 48.8584 USD
    assertEq(poolGetterFacet.plp().balanceOf(ALICE), 46.8584 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 353);
    assertEq(poolGetterFacet.getAumE18(false), 46.8584 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 48.02986 * 10**18);
    assertEq(poolGetterFacet.usdDebtOf(address(wbtc)), 46.8584 * 10**18);
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 117146);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(wbtc)),
      46.8584 * 10**30
    );

    // Alice add liquidity again with 117499 satoshi
    wbtc.approve(address(poolRouter), 117499);
    poolRouter.addLiquidity(
      address(poolDiamond),
      address(wbtc),
      117499,
      ALICE,
      0
    );

    // After Alice added 117499 satoshi as a liquidity,
    // the following conditions should be met:
    // 1. Alice should get 46.8584 + (46.8584 * 46.8584 / 48.02986) = 92573912195121951219 PLP
    // 2. Pool should make 706 sathoshi
    // 3. Pool's AUM by min price should be:
    // 46.8584 + (0.00117499 * (1-0.003) * 40000) = 93.7168 USD
    // 4. Pool's AUM by max price should be:
    // 48.02986 + (0.00117499 * (1-0.003) * 41000) = 96.05972 USD
    // 5. WBTC's USD debt should be 93.7168 USD
    // 6. WBTC's liquidity should be 117146 + 117499 - 353 = 234292 satoshi
    // 7. Redeemable WBTC in USD should be 93.7168 USD
    assertEq(poolGetterFacet.plp().balanceOf(ALICE), 92573912195121951219);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 706);
    assertEq(poolGetterFacet.getAumE18(false), 93.7168 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 96.05972 * 10**18);
    assertEq(poolGetterFacet.usdDebtOf(address(wbtc)), 93.7168 * 10**18);
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 234292);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(wbtc)),
      93.7168 * 10**30
    );

    vm.stopPrank();

    wbtcPriceFeed.setLatestAnswer(45_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(45_000 * 10**8);

    // Alice increase long position with sub account id = 0
    vm.startPrank(ALICE);
    wbtc.approve(address(orderbook), 22500);
    poolAccessControlFacet.allowPlugin(address(orderbook));
    address[] memory path = new address[](1);
    path[0] = address(wbtc);
    orderbook.createIncreaseOrder{ value: 0.01 ether }({
      _subAccountId: 0,
      _path: path,
      _amountIn: 22500,
      _indexToken: address(wbtc),
      _minOut: 0,
      _sizeDelta: 47 * 10**30,
      _collateralToken: address(wbtc),
      _isLong: true,
      _triggerPrice: 41_001 * 10**30,
      _triggerAboveThreshold: false,
      _executionFee: 0.01 ether,
      _shouldWrap: false
    });

    // Cancel the submitted order and create the same one again
    orderbook.cancelIncreaseOrder(0, 0);
    assertEq(ALICE.balance, 100 ether);

    wbtc.approve(address(orderbook), 22500);
    orderbook.createIncreaseOrder{ value: 0.01 ether }({
      _subAccountId: 0,
      _path: path,
      _amountIn: 22500,
      _indexToken: address(wbtc),
      _minOut: 0,
      _sizeDelta: 47 * 10**30,
      _collateralToken: address(wbtc),
      _isLong: true,
      _triggerPrice: 41_001 * 10**30,
      _triggerAboveThreshold: false,
      _executionFee: 0.01 ether,
      _shouldWrap: false
    });

    (
      address purchaseToken,
      uint256 purchaseTokenAmount,
      address collateralToken,
      address indexToken,
      uint256 sizeDelta,
      bool isLong,
      uint256 triggerPrice,
      bool triggerAboveThreshold
    ) = orderbook.getIncreaseOrder(ALICE, 1);
    assertEq(purchaseToken, address(wbtc));
    assertEq(purchaseTokenAmount, 22500);
    assertEq(collateralToken, address(wbtc));
    assertEq(indexToken, address(wbtc));
    assertEq(sizeDelta, 47 * 10**30);
    assertTrue(isLong);
    assertEq(triggerPrice, 41_001 * 10**30);
    assertFalse(triggerAboveThreshold);
    vm.stopPrank();

    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Execute Alice's order
    orderbook.executeIncreaseOrder(ALICE, 1, payable(BOB));
    // Bob should receive 0.01 ether as execution fee
    assertEq(BOB.balance, 0.01 ether);

    // The following condition expected to be happened:
    // 1. Pool's WBTC liquidity should be:
    // = 234292 + 22500 - (((47 * 0.001) + (47 * 0)) / 41000)
    // = 234292 + 22500 - 114 = 256678 sathoshi
    // 2. Pool's WBTC reserved should be:
    // = 47 / 40000 = 117500 sathoshi
    // 3. Pool's WBTC guarantee USD should be:
    // = 47 + 0.0047 - ((22500 / 1e8) * 40000) = 38.047 USD
    // 4. Redeemable WBTC in USD should be:
    // = ((256678 + 92797 - 117500) / 1e8) * 40000 = 92.79 USD
    // 5. Pool's AUM by min price should be:
    // 38.047 + ((256678 - 117500) / 1e8) * 40000 = 93.7182 USD
    // 6. Pool's AUM by max price should be:
    // 38.047 + ((256678 - 117500) / 1e8) * 41000 = 95.10998 USD
    // 7. Pool should makes 706 + 114 = 820 sathoshi
    // 8. Pool's WBTC USD debt should still the same as before
    // 9. Pool's WBTC balance should be:
    // = 256678 + 820 = 257498 sathoshi
    assertEq(poolGetterFacet.liquidityOf(address(wbtc)), 256678);
    assertEq(poolGetterFacet.reservedOf(address(wbtc)), 117500);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(wbtc)), 38.047 * 10**30);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(wbtc)),
      92.79 * 10**30
    );
    assertEq(poolGetterFacet.getAumE18(false), 93.7182 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 95.10998 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(wbtc)), 820);
    assertEq(poolGetterFacet.usdDebtOf(address(wbtc)), 93.7168 * 10**18);
    assertEq(wbtc.balanceOf(address(poolDiamond)), 257498);

    // Assert a postion
    // 1. Position's size should be 47 USD
    // 2. Position's collateral should be:
    // = ((22500 / 1e8) * 40000) - 0.047 = 8.953 USD
    // 3. Position's average price should be 41000 USD
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        ALICE,
        0,
        address(wbtc),
        address(wbtc),
        true
      );
    assertEq(position.size, 47 * 10**30);
    assertEq(position.collateral, 8.953 * 10**30);
    assertEq(position.averagePrice, 41000 * 10**30);
    assertEq(position.entryFundingRate, 0);
    assertEq(position.reserveAmount, 117500);
    assertEq(position.realizedPnl, 0);
    assertTrue(position.hasProfit == true);
    assertEq(position.lastIncreasedTime, block.timestamp);

    vm.startPrank(ALICE);
    orderbook.createDecreaseOrder{ value: 0.01 ether }({
      _subAccountId: 0,
      _indexToken: address(wbtc),
      _sizeDelta: 47 * 10**30,
      _collateralToken: address(wbtc),
      _collateralDelta: position.collateral,
      _isLong: true,
      _triggerPrice: 44_000 * 10**30,
      _triggerAboveThreshold: true
    });
    vm.stopPrank();
    // ----- Stop Alice session ------

    wbtcPriceFeed.setLatestAnswer(45_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(46_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(45_000 * 10**8);

    uint256 aliceWBTCBalanceBefore = wbtc.balanceOf(ALICE);

    orderbook.executeDecreaseOrder(ALICE, 0, payable(BOB));
    // Bob should receive another 0.01 ether as execution fee
    assertEq(BOB.balance, 0.02 ether);

    position = poolGetterFacet.getPositionWithSubAccountId(
      ALICE,
      0,
      address(wbtc),
      address(wbtc),
      true
    );
    // Position should be closed
    assertEq(position.collateral, 0, "Alice position should be closed");
    assertGt(
      wbtc.balanceOf(ALICE) - aliceWBTCBalanceBefore,
      22500,
      "Alice should receive collateral and profit."
    );
  }

  function testCorrectness_WhenShort() external {
    // Initialized price feeds
    daiPriceFeed.setLatestAnswer(1 * 10**8);
    wbtcPriceFeed.setLatestAnswer(60_000 * 10**8);
    maticPriceFeed.setLatestAnswer(1000 * 10**8);

    // Set mintBurnFeeBps to 4 BPS
    poolAdminFacet.setMintBurnFeeBps(4);

    // Feed WBTC price to be 40,000 USD
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    // Mint 1,000 DAI to Alice
    dai.mint(ALICE, 1000 * 10**18);

    // --- Start Alice session --- //
    vm.deal(ALICE, 100 ether);
    vm.startPrank(ALICE);

    // Alice performs add liquidity by a 500 DAI
    dai.approve(address(poolRouter), 500 * 10**18);
    poolRouter.addLiquidity(
      address(poolDiamond),
      address(dai),
      500 * 10**18,
      ALICE,
      0
    );

    // The following conditions need to be met:
    // 1. Pool's DAI liquidity should be 500 * (1-0.0004) = 499.8 DAI
    // 2. Pool should make 0.2 DAI in fee
    // 3. Pool's DAI usd debt should be 499.8 USD
    // 4. Redemptable DAI collateral should be 499.8 USD
    // 5. Pool's AUM by min price should be 499.8 USD
    // 6. Pool's AUM by max price should be 499.8 USD
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 499.8 * 10**18);
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.2 * 10**18);
    assertEq(poolGetterFacet.usdDebtOf(address(dai)), 499.8 * 10**18);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(dai)),
      499.8 * 10**30
    );
    assertEq(poolGetterFacet.getAumE18(false), 499.8 * 10**18);
    assertEq(poolGetterFacet.getAumE18(true), 499.8 * 10**18);

    vm.stopPrank();
    // ---- Stop Alice session ---- //

    wbtcPriceFeed.setLatestAnswer(39_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(39_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(39_000 * 10**8);

    // ---- Start Alice session ---- //
    vm.startPrank(ALICE);

    // Alice opens a 90 USD WBTC short position with 20 DAI as a collateral
    dai.approve(address(orderbook), 20 * 10**18);
    poolAccessControlFacet.allowPlugin(address(orderbook));
    address[] memory path = new address[](1);
    path[0] = address(dai);
    orderbook.createIncreaseOrder{ value: 0.01 ether }({
      _subAccountId: 1,
      _path: path,
      _amountIn: 20 * 10**18,
      _indexToken: address(wbtc),
      _minOut: 0,
      _sizeDelta: 90 * 10**30,
      _collateralToken: address(dai),
      _isLong: false,
      _triggerPrice: 49_999 * 10**30,
      _triggerAboveThreshold: true,
      _executionFee: 0.01 ether,
      _shouldWrap: false
    });

    // Edit the trigger price of the submitted order
    orderbook.updateIncreaseOrder({
      _subAccountId: 1,
      _orderIndex: 0,
      _sizeDelta: 90 * 10**30,
      _triggerPrice: 39_999 * 10**30,
      _triggerAboveThreshold: true
    });

    address subAccount = poolGetterFacet.getSubAccount(ALICE, 1);

    (
      address purchaseToken,
      uint256 purchaseTokenAmount,
      address collateralToken,
      address indexToken,
      uint256 sizeDelta,
      bool isLong,
      uint256 triggerPrice,
      bool triggerAboveThreshold
    ) = orderbook.getIncreaseOrder(subAccount, 0);
    assertEq(purchaseToken, address(dai));
    assertEq(purchaseTokenAmount, 20 * 10**18);
    assertEq(collateralToken, address(dai));
    assertEq(indexToken, address(wbtc));
    assertEq(sizeDelta, 90 * 10**30);
    assertFalse(isLong);
    assertEq(triggerPrice, 39_999 * 10**30);
    assertTrue(triggerAboveThreshold);
    vm.stopPrank();

    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(41_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(40_000 * 10**8);

    orderbook.executeIncreaseOrder(subAccount, 0, payable(BOB));
    // Bob should receive 0.01 ether as execution fee
    assertEq(BOB.balance, 0.01 ether);

    // The following conditions need to be met:
    // 1. Pool's DAI liquidity should be the same.
    // 2. Pool's DAI USD debt should be the same.
    // 2. Pool's DAI reserved should be 90 DAI
    // 3. Pool's guaranteed USD should be 0
    // 4. Redemptable DAI collateral should be 499.8 USD (same as liquidity)
    // 5. Pool should makes 0.2 + ((90 * 0.001)) = 0.29 DAI
    assertEq(poolGetterFacet.liquidityOf(address(dai)), 499.8 * 10**18);
    assertEq(poolGetterFacet.usdDebtOf(address(dai)), 499.8 * 10**18);
    assertEq(poolGetterFacet.reservedOf(address(dai)), 90 * 10**18);
    assertEq(poolGetterFacet.guaranteedUsdOf(address(dai)), 0 * 10**18);
    assertEq(
      poolGetterFacet.getRedemptionCollateralUsd(address(dai)),
      499.8 * 10**30
    );
    assertEq(poolGetterFacet.feeReserveOf(address(dai)), 0.29 * 10**18);
    assertEq(poolGetterFacet.shortSizeOf(address(wbtc)), 90 * 10**30);
    assertEq(
      poolGetterFacet.shortAveragePriceOf(address(wbtc)),
      40_000 * 10**30
    );

    // Assert a position:
    // 1. Position's size should be 90
    // 2. Position's collateral should be 20 - (90 * 0.001) = 19.91 DAI
    // 3. Position's averagePrice should be 40,000 USD
    // 4. Position's entry funding rate should be 0
    // 5. Position's reserve amount should be 90 DAI
    // 6. Position should be in profit
    // 7. Position's lastIncreasedTime should be block.timestamp
    GetterFacetInterface.GetPositionReturnVars memory position = poolGetterFacet
      .getPositionWithSubAccountId(
        ALICE,
        1,
        address(dai),
        address(wbtc),
        false
      );
    assertEq(position.size, 90 * 10**30);
    assertEq(position.collateral, 19.91 * 10**30);
    assertEq(position.averagePrice, 40_000 * 10**30);
    assertEq(position.entryFundingRate, 0);
    assertEq(position.reserveAmount, 90 * 10**18);
    assertTrue(position.hasProfit);
    assertEq(position.lastIncreasedTime, block.timestamp);

    // Assert pool's short delta
    // 1. Pool's delta should be (90 * (40000 - 41000)) / 40000 = -2.25 USD
    // 2. Pool's short should be not profitable
    (bool isProfit, uint256 delta) = poolGetterFacet.getPoolShortDelta(
      address(wbtc)
    );
    assertFalse(isProfit);
    assertEq(delta, 2.25 * 10**30);

    // Assert position's delta
    // 1. Position's delta should be (90 * (40000 - 41000)) / 40000 = -2.25 USD
    // 2. Position's short should be not profitable
    (isProfit, delta) = poolGetterFacet.getPositionDelta(
      ALICE,
      1,
      address(dai),
      address(wbtc),
      false
    );
    assertFalse(isProfit);
    assertEq(delta, 2.25 * 10**30);

    vm.stopPrank();

    // Make WBTC price pump to 42,000 USD
    wbtcPriceFeed.setLatestAnswer(42_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(42_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(42_000 * 10**8);

    vm.startPrank(ALICE);

    // Assert pool's short delta
    // 1. Pool's delta should be (90 * (40000 - 42000)) / 40000 = -4.5 USD
    // 2. Pool's short should be not profitable
    (isProfit, delta) = poolGetterFacet.getPoolShortDelta(address(wbtc));
    assertFalse(isProfit);
    assertEq(delta, 4.5 * 10**30);

    // Assert position's delta
    // 1. Position's delta should be (90 * (40000 - 42000)) / 40000 = -4.5 USD
    // 2. Position's short should be not profitable
    (isProfit, delta) = poolGetterFacet.getPositionDelta(
      ALICE,
      1,
      address(dai),
      address(wbtc),
      false
    );
    assertFalse(isProfit);
    assertEq(delta, 4.5 * 10**30);

    orderbook.createDecreaseOrder{ value: 0.01 ether }({
      _subAccountId: 1,
      _indexToken: address(wbtc),
      _sizeDelta: 90 * 10**30,
      _collateralToken: address(dai),
      _collateralDelta: position.collateral,
      _isLong: false,
      _triggerPrice: 40_000 * 10**30,
      _triggerAboveThreshold: false
    });
    vm.stopPrank();

    wbtcPriceFeed.setLatestAnswer(39_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(39_000 * 10**8);
    wbtcPriceFeed.setLatestAnswer(38_000 * 10**8);

    uint256 aliceDAIBalanceBefore = dai.balanceOf(ALICE);

    orderbook.executeDecreaseOrder(subAccount, 0, payable(BOB));
    // Bob should receive another 0.01 ether as execution fee
    assertEq(BOB.balance, 0.02 ether);

    position = poolGetterFacet.getPositionWithSubAccountId(
      ALICE,
      1,
      address(wbtc),
      address(wbtc),
      true
    );
    // Position should be closed
    assertEq(position.collateral, 0, "Alice position should be closed");
    assertGt(
      dai.balanceOf(ALICE) - aliceDAIBalanceBefore,
      20 * 10**18,
      "Alice should receive collateral and profit."
    );
  }
}
