module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // MARK: - Deploy MintClubToken implementation
  const result = await deploy('MintClubToken', {
    from: deployer,
    args: [],
    log: true
  });
  console.log(`Test HUNT is deployed at ${result.contract.address} using ${result.receipt.gasUsed} gas`);

  // let huntTokenAddress = '0x9aab071b4129b083b01cb5a0cb513ce7eca26fa5';
  // if (process.env.HARDHAT_NETWORK !== 'production') {
  //   // Make a mock Hunt token to be used as a reserve token
  //   await execute('MintClubToken', { from: deployer }, 'init', 'Test HuntToken', 'HUNT');

  //   const { ether } = require('@openzeppelin/test-helpers');
  //   await execute('MintClubToken', { from: deployer }, 'mint', deployer, ether('10000000'));

  //   huntTokenAddress = result.contract.address;
  // }

  // await deploy('MintClubBond', {
  //   from: deployer,
  //   args: [huntTokenAddress, result.contract.address],
  //   log: true
  // });
};
module.exports.tags = ['MintClubBond'];
