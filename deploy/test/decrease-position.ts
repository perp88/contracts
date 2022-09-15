// import { HardhatRuntimeEnvironment } from "hardhat/types";
// import { DeployFunction } from "hardhat-deploy/types";
// import { ethers } from "hardhat";
// import {
//   ERC20__factory,
//   MintableTokenInterface__factory,
//   PoolRouter__factory,
// } from "../../typechain";
// import { getConfig } from "../utils/config";

// const config = getConfig();

// const POOL_ROUTER = config.PoolRouter;
// const COLLATERAL_TOKEN = config.Tokens.DAI;
// const INDEX_TOKEN = config.Tokens.WBTC;

// const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
//   const deployer = (await ethers.getSigners())[0];
//   const poolRouter = PoolRouter__factory.connect(POOL_ROUTER, deployer);
//   const collateralToken = ERC20__factory.connect(COLLATERAL_TOKEN, deployer);

//   await (
//     await poolRouter.decreasePosition(
//       config.Pools.PLP.poolDiamond,
//       0,
//       COLLATERAL_TOKEN,
//       INDEX_TOKEN,
//       ethers.utils.parseUnits("1000", 18),
//       ethers.utils.parseUnits("10000", 30),
//       false,
//       deployer.address,
//       ethers.constants.MaxUint256,
//       0,
//       { gasLimit: 10000000 }
//     )
//   ).wait();
//   console.log(`Execute decreasePosition`);
// };

// export default func;
// func.tags = ["DecreasePosition"];