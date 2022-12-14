import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, upgrades, tenderly, network } from "hardhat";
import { getConfig, writeConfigFile } from "../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const config = getConfig();
const LIQUIDITY_COOLDOWN = 60 * 15; // 15 minutes

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const PLP = await ethers.getContractFactory("PLP", deployer);

  console.log(`Deploying PLP Token Contract`);
  const plp = await upgrades.deployProxy(PLP, [LIQUIDITY_COOLDOWN]);
  await plp.deployTransaction.wait(3);
  console.log(`Deployed at: ${plp.address}`);

  config.Tokens.PLP = plp.address;
  writeConfigFile(config);

  const implAddress = await getImplementationAddress(
    network.provider,
    plp.address
  );

  await tenderly.verify({
    address: implAddress,
    name: "PLP",
  });
};

export default func;
func.tags = ["PLPToken"];
