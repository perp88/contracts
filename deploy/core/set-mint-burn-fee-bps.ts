import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { AdminFacetInterface__factory } from "../../typechain";
import { getConfig } from "../utils/config";
import { eip1559rapidGas } from "../utils/gas";

const config = getConfig();
const mintBurnFeeBps = 25;

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const pool = AdminFacetInterface__factory.connect(
    config.Pools.PLP.poolDiamond,
    deployer
  );
  const tx = await pool.setMintBurnFeeBps(mintBurnFeeBps, {
    ...(await eip1559rapidGas()),
  });
  console.log(`> Execute setMintBurnFeeBps`);
  console.log(`> ⛓ Tx submitted: ${tx.hash}`);
  console.log(`> Waiting for tx to be mined...`);
  await tx.wait(3);
  console.log(`> ✅ Done`);
};

export default func;
func.tags = ["SetMintBurnFeeBps"];
