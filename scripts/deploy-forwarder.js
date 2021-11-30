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

  const Forwarder = await hre.ethers.getContractFactory('Forwarder');
  const contract = await Forwarder.deploy();
  await contract.deployed();

  console.log('---');
  console.log(`Forwarder contract: ${contract.address}`);
};

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });

// Deploy:
// npx hardhat compile && HARDHAT_NETWORK=bsctest node scripts/deploy-forwarder.js
// npx hardhat verify --network bsctest 0xcAaB0734ca9e499209EBEEf3c3c6Bb9Fdc2EE6A6

// npx hardhat compile && HARDHAT_NETWORK=bscmain node scripts/deploy-forwarder.js
// npx hardhat verify --network bscmain 0xC11E0652ac827B14E13b272fD92d6c44A97fD5A1
