// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  const accounts = await hre.ethers.getSigners();
  const deployer = accounts[0].address;
  console.log(`Deploy from account: ${deployer}`);

  const MintClubZapV3 = await hre.ethers.getContractFactory('MintClubZapV3');
  const zap = await MintClubZapV3.deploy();
  await zap.deployed();

  console.log('---');
  console.log(`MintClubZapV3 contract: ${zap.address}`);
};

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });

// Deploy:
// npx hardhat compile
// HARDHAT_NETWORK=bscmain node scripts/deploy-zap.js
// npx hardhat verify --network bsctest 0xa41aa441D4036eF40846E4B331fd1c3fd4200937
