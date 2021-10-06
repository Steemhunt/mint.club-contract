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
// HARDHAT_NETWORK=bsctest node scripts/deploy-zap.js
// npx hardhat verify --network bsctest 0xFC1Ccd12A3aFbf3e6E5ba134Fa446935D20bc2F6

// HARDHAT_NETWORK=bscmain node scripts/deploy-zap.js
// npx hardhat verify --network bscmain 0x9111A272e9dE242Cf9aa7932a42dB3664Ca3eC9D
