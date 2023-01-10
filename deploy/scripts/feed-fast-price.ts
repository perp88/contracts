import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { getConfig } from "../utils/config";
import {
  MEVAegis__factory,
  MockPoolOracle__factory,
  PoolOracle__factory,
} from "../../typechain";

const BigNumber = ethers.BigNumber;

const config = getConfig();

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const mevAegis = MEVAegis__factory.connect(
    config.Pools.PLP.mevAegis,
    deployer
  );
  const poolOracle = PoolOracle__factory.connect(
    config.Pools.PLP.oracle,
    deployer
  );
  const timestamp = (new Date().valueOf() / 1000).toFixed();
  const tx = await mevAegis[
    "setPricesWithBitsAndExecute(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,address,bytes32)"
  ](
    getPriceBits(["17431890", "1282760", "880"]),
    timestamp,
    ethers.constants.MaxUint256,
    ethers.constants.MaxUint256,
    ethers.constants.MaxUint256,
    ethers.constants.MaxUint256,
    ethers.constants.MaxUint256,
    ethers.constants.MaxUint256,
    deployer.address,
    "0x0000000000000000000000000000000000000000000000000000000000000000",
    { gasLimit: 10000000 }
  );
  console.log(tx.hash);
  await tx.wait();

  // WBTC
  console.log(
    "WBTC fast price: ",
    await mevAegis.getPrice(
      config.Tokens.WBTC,
      await poolOracle.getLatestPrimaryPrice(config.Tokens.WBTC),
      true
    )
  );
  console.log(
    "WBTC pool oracle price: ",
    await poolOracle.getPrice(config.Tokens.WBTC, true),
    await poolOracle.getPrice(config.Tokens.WBTC, false)
  );
  console.log(await mevAegis.favorFastPrice(config.Tokens.WBTC));
  console.log(
    "WBTC getPriceData",
    await mevAegis.getPriceData(config.Tokens.WBTC)
  );

  // WETH
  console.log(
    "WETH fast price: ",
    await mevAegis.getPrice(
      config.Tokens.WETH,
      await poolOracle.getLatestPrimaryPrice(config.Tokens.WETH),
      true
    )
  );
  console.log(
    "WETH pool oracle price: ",
    await poolOracle.getPrice(config.Tokens.WETH, true),
    await poolOracle.getPrice(config.Tokens.WETH, false)
  );
  console.log(await mevAegis.favorFastPrice(config.Tokens.WETH));

  // WMATIC
  console.log(
    "WMATIC fast price: ",
    await mevAegis.getPrice(
      config.Tokens.WMATIC,
      await poolOracle.getLatestPrimaryPrice(config.Tokens.WMATIC),
      true
    )
  );
  console.log(
    "WMATIC pool oracle price: ",
    await poolOracle.getPrice(config.Tokens.WMATIC, true),
    await poolOracle.getPrice(config.Tokens.WMATIC, false)
  );
  console.log(await mevAegis.favorFastPrice(config.Tokens.WMATIC));
  console.log("Done");
};

function getPriceBits(prices: string[]) {
  if (prices.length > 8) {
    throw new Error("max prices.length exceeded");
  }

  let priceBits = BigNumber.from(0);

  for (let j = 0; j < 8; j++) {
    let index = j;
    if (index >= prices.length) {
      break;
    }

    const price = BigNumber.from(prices[index]);
    if (price.gt(BigNumber.from("2147483648"))) {
      // 2^31
      throw new Error(`price exceeds bit limit ${price.toString()}`);
    }

    priceBits = priceBits.or(price.shl(j * 32));
  }

  return priceBits.toString();
}

export default func;
func.tags = ["FeedFastPrice"];
