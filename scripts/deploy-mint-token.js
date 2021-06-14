// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  const accounts = await hre.ethers.getSigners();
  const deployer = accounts[0].address;
  console.log(`Deploy from account: ${deployer} / ${process.env.HARDHAT_NETWORK}`);

  // MARK: - Deploy MintClubToken implementation
  const MintClubToken = await hre.ethers.getContractFactory('MintClubToken');
  const token = await MintClubToken.deploy();
  await token.deployed();

  await token.init('Mint.club', 'MINT', { gasLimit: 150000 });

  console.log(`MINT token: ${token.address}`);
};

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
