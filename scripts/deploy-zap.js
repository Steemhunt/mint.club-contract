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

  const MintClubZapV6 = await hre.ethers.getContractFactory("MintClubZapV6");
  const zap = await MintClubZapV6.deploy({ gasLimit: 4000000 });
  await zap.deployed();

  console.log("---");
  console.log(`MintClubZapV6 contract: ${zap.address}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

// Deploy:
// npx hardhat compile && HARDHAT_NETWORK=bsctest node scripts/deploy-zap.js
// npx hardhat verify --network bsctest 0x2B50078e9913dEf1073A5fE5FE53FB9f558B1803

// npx hardhat compile && HARDHAT_NETWORK=bscmain node scripts/deploy-zap.js
// npx hardhat verify --network bscmain 0x070F062C43aa593AA826FBA1A986Ab55Ca426523
