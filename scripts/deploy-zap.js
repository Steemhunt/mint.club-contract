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

  const MintClubZapV4 = await hre.ethers.getContractFactory('MintClubZapV4');
  const zap = await MintClubZapV4.deploy({ gasLimit: 4000000 });
  await zap.deployed();

  console.log('---');
  console.log(`MintClubZapV4 contract: ${zap.address}`);
};

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });

// Deploy:
// npx hardhat compile && HARDHAT_NETWORK=bsctest node scripts/deploy-zap.js
// npx hardhat verify --network bsctest 0x82FB619149c3834f3185dBfdF7E6D8307DdE769D

// npx hardhat compile && HARDHAT_NETWORK=bscmain node scripts/deploy-zap.js
// npx hardhat verify --network bscmain 0x0fd056274EE61497D0dB17A88F1C2DCa4f49175a
