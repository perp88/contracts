import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { getConfig } from "../utils/config";

const config = getConfig();

const WNATIVE = config.Tokens.WMATIC;

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const PoolRouter = await ethers.getContractFactory("PoolRouter", deployer);
  const poolRouter = await PoolRouter.deploy(WNATIVE);
  await poolRouter.deployed();
  console.log(`Deploying PoolRouter Contract`);
  console.log(`Deployed at: ${poolRouter.address}`);
};

export default func;
func.tags = ["PoolRouter"];