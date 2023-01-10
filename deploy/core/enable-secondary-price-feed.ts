import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { MEVAegis__factory, PoolOracle__factory } from "../../typechain";
import { getConfig } from "../utils/config";
import { eip1559rapidGas } from "../utils/gas";

const config = getConfig();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const poolOracle = PoolOracle__factory.connect(
    config.Pools.PLP.oracle,
    deployer
  );

  console.log("> Enable Secondary Price Feed for PoolOracle");
  const tx = await poolOracle.setIsSecondaryPriceEnabled(true, {
    ...(await eip1559rapidGas()),
  });
  console.log(`> ⛓ Tx submitted: ${tx.hash}`);
  console.log(`> Waiting for tx to be mined...`);
  await tx.wait(3);
  console.log(`> ✅ Done`);
};

export default func;
func.tags = ["EnableSecondaryPriceFeed"];
