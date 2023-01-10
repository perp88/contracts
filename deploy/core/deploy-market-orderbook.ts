import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers, upgrades, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const config = getConfig();

const minExecutionFee = ethers.utils.parseEther("0.2");
const depositFeeBps = ethers.BigNumber.from(30); // 0.3%

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];

  console.log(`> Deploying MarketOrderbook Contract`);
  const MarketOrderbook = await ethers.getContractFactory(
    "MarketOrderbook",
    deployer
  );

  const orderbook = await upgrades.deployProxy(MarketOrderbook, [
    config.Pools.PLP.poolDiamond, // _pool
    config.Pools.PLP.oracle, // _poolOracle
    config.Tokens.WMATIC, // _weth
    depositFeeBps, // _depositFeeBps
    minExecutionFee, // _minExecutionFee
  ]);
  console.log(`> ⛓ Tx submitted: ${orderbook.deployTransaction.hash}`);
  console.log(`> Waiting tx to be mined...`);
  await orderbook.deployTransaction.wait(3);
  console.log(`> Tx mined!`);
  console.log(`> Deployed at: ${orderbook.address}`);

  config.Pools.PLP.marketOrderbook = orderbook.address;
  writeConfigFile(config);

  console.log(`> Verifying contract on Tenderly...`);
  const implAddress = await getImplementationAddress(
    ethers.provider,
    orderbook.address
  );
  await tenderly.verify({
    address: implAddress,
    name: "MarketOrderbook",
  });
  console.log(`> ✅ Done!`);
};

export default func;
func.tags = ["MarketOrderbook"];
