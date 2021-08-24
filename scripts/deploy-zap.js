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

  const MintClubZapV2 = await hre.ethers.getContractFactory('MintClubZapV2');
  const zap = await MintClubZapV2.deploy();
  await zap.deployed();

  console.log('---');
  console.log(`MintClubZapV2 contract: ${zap.address}`);
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
// npx hardhat verify --network bscmain 0x9a22b3282873a47dD3c77639990c891F49Af5604
