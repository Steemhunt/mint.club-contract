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

  const MintClubZapV5 = await hre.ethers.getContractFactory('MintClubZapV5');
  const zap = await MintClubZapV5.deploy({ gasLimit: 4000000 });
  await zap.deployed();

  console.log('---');
  console.log(`MintClubZapV5 contract: ${zap.address}`);
};

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });

// Deploy:
// npx hardhat compile && HARDHAT_NETWORK=bsctest node scripts/deploy-zap.js
// npx hardhat verify --network bsctest 0xa2e078F581Ab5f7aFf47dBBAFb7F0139BC17Efa6

// npx hardhat compile && HARDHAT_NETWORK=bscmain node scripts/deploy-zap.js
// npx hardhat verify --network bscmain 0x35A358F72024ac7ca040CAAE314296E5377E6157
