import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import {
  AccessControlFacetInterface__factory,
  ERC20__factory,
  MarketOrderbook__factory,
  MintableTokenInterface__factory,
  Orderbook__factory,
} from "../../typechain";
import { getConfig } from "../utils/config";

const config = getConfig();

const ORDERBOOK = config.Pools.PLP.marketOrderbook;
const COLLATERAL_TOKEN = config.Tokens.WBTC;
const INDEX_TOKEN = config.Tokens.WBTC;
const isLong = true;

enum Exposure {
  LONG,
  SHORT,
}

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const pool = AccessControlFacetInterface__factory.connect(
    config.Pools.PLP.poolDiamond,
    deployer
  );
  const orderbook = MarketOrderbook__factory.connect(ORDERBOOK, deployer);
  const collateralToken = ERC20__factory.connect(COLLATERAL_TOKEN, deployer);
  const decimals = await collateralToken.decimals();

  // await (await pool.allowPlugin(ORDERBOOK)).wait();
  // await (
  //   await collateralToken.approve(
  //     orderbook.address,
  //     ethers.constants.MaxUint256
  //   )
  // ).wait();
  const minExecutionFee = await orderbook.minExecutionFee();
  await (
    await orderbook.createIncreasePosition(
      0, // _subAccountId
      [COLLATERAL_TOKEN], // _path
      INDEX_TOKEN, // _indexToken
      ethers.utils.parseUnits("0.1", decimals), // _amountIn
      0, // _minOut
      ethers.utils.parseUnits("40000", 30), // _sizeDelta
      isLong, // _isLong
      ethers.constants.MaxUint256, // _acceptablePrice
      minExecutionFee, // _executionFee
      { value: minExecutionFee, gasLimit: 10000000 }
    )
  ).wait();
  console.log(`Create Market Increase Order`);
};

export default func;
func.tags = ["CreateIncreaseOrderMarket"];
