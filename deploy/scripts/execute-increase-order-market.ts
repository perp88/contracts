import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import {
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
  const orderbook = MarketOrderbook__factory.connect(ORDERBOOK, deployer);
  const collateralToken = ERC20__factory.connect(COLLATERAL_TOKEN, deployer);
  const decimals = await collateralToken.decimals();

  await (
    await orderbook.executeIncreasePositions(
      ethers.constants.MaxUint256,
      deployer.address,
      { gasLimit: 10000000 }
    )
  ).wait();
  console.log(`Execute executeIncreaseOrder`);
};

export default func;
func.tags = ["ExecuteIncreaseOrderMarket"];
