import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { MEVAegis__factory, PoolOracle__factory } from "../../typechain";
import { getConfig } from "../utils/config";
import { eip1559rapidGas } from "../utils/gas";

const config = getConfig();

const minAuthorizations = 1;
const signers = [
  "0x6a5D2BF8ba767f7763cd342Cb62C5076f9924872",
  "0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a",
]; // DEPLOYER
const updaters = [
  "0x3A16765161fEeC1E5d8a80020d4974e5032A23B1",
  "0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a",
]; // ORDER EXECUTOR

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const mevAegis = MEVAegis__factory.connect(
    config.Pools.PLP.mevAegis,
    deployer
  );

  console.log("> Init MEVAegis");
  const tx = await mevAegis.init(minAuthorizations, signers, updaters, {
    ...(await eip1559rapidGas()),
  });
  console.log(`> ⛓ Tx submitted: ${tx.hash}`);
  console.log(`> Waiting for tx to be mined...`);
  await tx.wait(3);
  console.log(`> ✅ Done`);
};

export default func;
func.tags = ["InitMEVAegis"];
