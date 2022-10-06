import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../utils/config";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const config = getConfig();
  const deployer = (await ethers.getSigners())[0];
  const MerkleAirdropFactory = await ethers.getContractFactory(
    "MerkleAirdropFactory",
    deployer
  );
  const merkleAirdropFactory = await MerkleAirdropFactory.deploy();
  await merkleAirdropFactory.deployed();
  console.log(`Deploying MerkleAirdropFactory Contract`);
  console.log(`Deployed at: ${merkleAirdropFactory.address}`);

  await tenderly.verify({
    address: merkleAirdropFactory.address,
    name: "MerkleAirdropFactory",
  });

  config.ReferralDistribution.MerkleAirdropFactory =
    merkleAirdropFactory.address;
  writeConfigFile(config);
};

export default func;
func.tags = ["MerkleAirdropFactory"];
