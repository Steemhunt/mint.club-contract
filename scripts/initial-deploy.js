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

  // Make a mock Hunt token to be used as a reserve token
  await token.init('Mint Club', 'MINT', { gasLimit: 150000 });

  if (process.env.HARDHAT_NETWORK !== 'production') {
    await token.mint(deployer, '800000000000000000000000000000', { gasLimit: 100000 }); // 800B test tokens
  }

  const MintClubBond = await hre.ethers.getContractFactory('MintClubBond');
  const bond = await MintClubBond.deploy(token.address, token.address);
  await bond.deployed();

  console.log('---');
  console.log(`MINT token: ${token.address}`);
  console.log(`MintClubBond contract: ${bond.address}`);
};

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
