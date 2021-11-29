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
// npx hardhat verify --network bsctest 0x84f805d74A76A53841B05a830108A212E08df683

// npx hardhat compile && HARDHAT_NETWORK=bscmain node scripts/deploy-zap.js
// npx hardhat verify --network bscmain 0xa27f40B02dD20eBA689791aE0F7E59a18963F521
