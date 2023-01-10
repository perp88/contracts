import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, upgrades, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const config = getConfig();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const Orderbook = await ethers.getContractFactory(
    "MarketOrderbook",
    deployer
  );
  const newOrderbookImp = await upgrades.prepareUpgrade(
    config.Pools.PLP.marketOrderbook,
    Orderbook
  );
  console.log(
    `> New MarketOrderbook Implementation address: ${newOrderbookImp}`
  );
  const tx = await upgrades.upgradeProxy(
    config.Pools.PLP.marketOrderbook,
    Orderbook
  );
  await tx.deployed();

  await tenderly.verify({
    address: newOrderbookImp.toString(),
    name: "MarketOrderbook",
  });
};

export default func;
func.tags = ["UpgradeMarketOrderbook"];
