import { network } from "hardhat";
import * as fs from "fs";
import MainnetConfig from "../../configs/matic.137.json";
import TenderlyConfig from "../../configs/tenderly.137.json";
import MumbaiConfig from "../../configs/mumbai.80001.json";

export function getConfig() {
  if (network.name === "matic") {
    return MainnetConfig;
  }
  if (network.name === "tenderly") {
    return TenderlyConfig;
  }
  if (network.name === "mumbai") {
    return MumbaiConfig;
  }

  throw new Error("not found config");
}

export function writeConfigFile(config: any) {
  let filePath;
  switch (network.name) {
    case "matic":
      filePath = "./configs/matic.137.json";
      break;
    case "tenderly":
      filePath = "./configs/tenderly.137.json";
      break;
    case "mumbai":
      filePath = "./configs/mumbai.80001.json";
      break;
    default:
      throw Error("Unsupported network");
  }
  console.log(`> Writing ${filePath}`);
  fs.writeFileSync(filePath, JSON.stringify(config, null, 2));
  console.log("> ✅ Done");
}
