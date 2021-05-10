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

  // MARK: - Deploy MintClubToken implementation
  const MintClubToken = await hre.ethers.getContractFactory('MintClubToken');
  const token = await MintClubToken.deploy();
  await token.deployed();

  console.log(`Token implementation is deployed at ${token.address}`);

  let huntTokenAddress = '0x9aab071b4129b083b01cb5a0cb513ce7eca26fa5';
  if (process.env.HARDHAT_NETWORK !== 'production') {
    // Make a mock Hunt token to be used as a reserve token
    await token.init('Test HuntToken', 'TESTHUNT');
    await token.mint(deployer, '10000000000000000000000000'); // 10M test tokens

    huntTokenAddress = token.address;
  }

  const MintClubBond = await hre.ethers.getContractFactory('MintClubBond');
  const bond = await MintClubBond.deploy(huntTokenAddress, token.address);
  await bond.deployed();

  console.log(`MintClubBond is deployed at ${bond.address}`);
};

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
