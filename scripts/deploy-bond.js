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

  const BASE_TOKEN = '0x1f3Af095CDa17d63cad238358837321e95FC5915'; // MINT Token mainnet

  // MARK: - Deploy MintClubToken implementation
  const MintClubToken = await hre.ethers.getContractFactory('MintClubToken');
  const token = await MintClubToken.deploy();
  await token.deployed();

  console.log(`Token implementation is deployed at ${token.address}`);

  // Make a mock Hunt token to be used as a reserve token
  await token.init('Mint.club Token Implementation', 'MINT_CLUB_TOKEN_IMPLEMENTATION', { gasLimit: 150000 });

  const MintClubBond = await hre.ethers.getContractFactory('MintClubBond');
  const bond = await MintClubBond.deploy(BASE_TOKEN, token.address);
  await bond.deployed();

  console.log('---');
  console.log(`MINT token: ${BASE_TOKEN}`);
  console.log(`MintClubToken implementation: ${token.address}`);
  console.log(`MintClubBond contract: ${bond.address}`);
};

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
