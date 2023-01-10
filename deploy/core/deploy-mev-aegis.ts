import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, tenderly, upgrades } from "hardhat";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";
import { getConfig, writeConfigFile } from "../utils/config";
import { eip1559rapidGas } from "../utils/gas";

const config = getConfig();

const priceDuration = 300;
const maxPriceUpdateDelay = 3600;
const minBlockInterval = 1;
const maxDeviationBasisPoints = 500;
const tokenManager = "0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a";
const positionRouter = config.Pools.PLP.marketOrderbook;
const orderbook = config.Pools.PLP.orderbook;

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];

  console.log(`> Deploying MEVAegis Contract`);
  const MEVAegis = await ethers.getContractFactory("MEVAegis", deployer);
  const mevAegis = await upgrades.deployProxy(MEVAegis, [
    priceDuration,
    maxPriceUpdateDelay,
    minBlockInterval,
    maxDeviationBasisPoints,
    tokenManager,
    positionRouter,
    orderbook,
    {
      ...(await eip1559rapidGas()),
    },
  ]);
  console.log(`> ⛓ Tx submitted: ${mevAegis.deployTransaction.hash}`);
  await mevAegis.deployTransaction.wait(3);
  console.log(`> Deployed at: ${mevAegis.address}`);

  config.Pools.PLP.mevAegis = mevAegis.address;
  writeConfigFile(config);

  const implAddress = await getImplementationAddress(
    ethers.provider,
    mevAegis.address
  );

  console.log(`> Verifying contract on Tenderly...`);
  await tenderly.verify({
    address: implAddress,
    name: "MEVAegis",
  });
  console.log(`> ✅ Done!`);
};

export default func;
func.tags = ["MEVAegis"];
