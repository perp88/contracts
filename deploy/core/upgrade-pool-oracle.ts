import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, upgrades, tenderly } from "hardhat";
import { getConfig } from "../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const config = getConfig();

const TARGET_ADDRESS = config.Pools.PLP.oracle;

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const PoolOracle = await ethers.getContractFactory("PoolOracle", deployer);

  console.log(`> Preparing to upgrade PoolOracle`);
  const newPoolOracle = await upgrades.prepareUpgrade(
    TARGET_ADDRESS,
    PoolOracle
  );
  console.log(`> Done`);

  console.log(`> New PoolOracle Implementation address: ${newPoolOracle}`);
  const upgradeTx = await upgrades.upgradeProxy(TARGET_ADDRESS, PoolOracle);
  console.log(`> ⛓ Tx is submitted: ${upgradeTx.deployTransaction.hash}`);
  console.log(`> Waiting for tx to be mined...`);
  await upgradeTx.deployTransaction.wait(3);
  console.log(`> Tx is mined!`);

  console.log(`> Verify contract on Tenderly`);
  await tenderly.verify({
    address: newPoolOracle.toString(),
    name: "PoolOracle",
  });
  console.log(`> ✅ Done`);
};

export default func;
func.tags = ["UpgradePoolOracle"];
