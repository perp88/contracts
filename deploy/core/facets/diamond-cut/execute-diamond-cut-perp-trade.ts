import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import {
  DiamondCutFacet__factory,
  PerpTradeFacet__factory,
} from "../../../../typechain";
import { getConfig } from "../../../utils/config";
import { eip1559rapidGas } from "../../../utils/gas";

const config = getConfig();

enum FacetCutAction {
  Add,
  Replace,
  Remove,
}

const facetCuts = [
  {
    facetAddress: config.Pools.PLP.facets.perpTrade,
    action: FacetCutAction.Replace,
    functionSelectors: [
      PerpTradeFacet__factory.createInterface().getSighash(
        "checkLiquidation(address,address,address,bool,bool)"
      ),
      PerpTradeFacet__factory.createInterface().getSighash(
        "decreasePosition(address,uint256,address,address,uint256,uint256,bool,address)"
      ),
      PerpTradeFacet__factory.createInterface().getSighash(
        "increasePosition(address,uint256,address,address,uint256,bool)"
      ),
      PerpTradeFacet__factory.createInterface().getSighash(
        "liquidate(address,uint256,address,address,bool,address)"
      ),
    ],
  },
];

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];

  const poolDiamond = DiamondCutFacet__factory.connect(
    config.Pools.PLP.poolDiamond,
    deployer
  );

  console.log(`> Diamond cutting perp trade facet`);
  const tx = await poolDiamond.diamondCut(
    facetCuts,
    ethers.constants.AddressZero,
    "0x",
    await eip1559rapidGas()
  );
  console.log(`> ⛓ Tx submitted: ${tx.hash}`);
  console.log(`> Waiting for tx to be mined...`);
  await tx.wait(3);
  console.log(`> ✅ Diamond cut perp trade facet`);
};

export default func;
func.tags = ["ExecuteDiamondCut-PerpTrade"];
