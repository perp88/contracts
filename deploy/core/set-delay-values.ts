import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import {
  AdminFacetInterface__factory,
  MarketOrderbook__factory,
} from "../../typechain";
import { getConfig } from "../utils/config";
import { eip1559rapidGas } from "../utils/gas";

const config = getConfig();

const minBlockDelayKeeper = 0;
const minTimeDelayPublic = 180;
const maxTimeDelay = 1800;

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const orderbook = MarketOrderbook__factory.connect(
    config.Pools.PLP.marketOrderbook,
    deployer
  );

  console.log(`> Set Delay Values...`);
  const tx = await orderbook.setDelayValues(
    minBlockDelayKeeper, // _minBlockDelayKeeper
    minTimeDelayPublic, // _minTimeDelayPublic
    maxTimeDelay, // _maxTimeDelay
    await eip1559rapidGas()
  );
  console.log(`> ⛓ Tx submitted: ${tx.hash}`);
  console.log(`> Waiting for tx to be mined...`);
  await tx.wait(3);
  console.log(`> ✅ Tx mined!`);
};

export default func;
func.tags = ["SetDelayValues"];
