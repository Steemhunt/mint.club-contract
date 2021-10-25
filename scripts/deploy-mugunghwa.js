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

  const BASE_TOKEN = '0x4d24BF63E5d6E03708e2DFd5cc8253B3f22FE913'; // Testnet MINT

  const MugunghwaGame = await hre.ethers.getContractFactory('MugunghwaGame');
  const game = await MugunghwaGame.deploy(BASE_TOKEN);
  await game.deployed();

  console.log('---');
  console.log(`MugunghwaGame contract: ${game.address}`);
};

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });

// Deploy:
// npx hardhat compile && HARDHAT_NETWORK=bsctest node scripts/deploy-mugunghwa.js
// npx hardhat verify --network bsctest 0xB91315eF14cCF9f9593112341a426984Bb1AD13c "0x4d24BF63E5d6E03708e2DFd5cc8253B3f22FE913"

// HARDHAT_NETWORK=bscmain node scripts/deploy-mugunghwa.js
// npx hardhat verify --network bscmain 0x00
