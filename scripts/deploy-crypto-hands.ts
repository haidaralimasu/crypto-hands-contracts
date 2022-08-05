const { ethers } = require("hardhat");
import { verify } from "../utils/verify";

async function main() {
  const CryptoHands = await ethers.getContractFactory("CryptoHands");

  const baseUri = "iambaseuri";
  const hiddenUri = "iamhiddenuri";

  const chArgs = [baseUri, hiddenUri];

  const cryptoHands = await CryptoHands.deploy(baseUri, hiddenUri);

  await cryptoHands.deployed();

  if (process.env.ETHERSCAN_API_KEY) {
    console.log("Verifying...");
    await verify(cryptoHands.address, chArgs);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
