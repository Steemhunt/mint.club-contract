/// ENVVAR
// - ENABLE_GAS_REPORT
// - COMPILE_MODE

require('dotenv').config();

const path = require('path');
const argv = require('yargs/yargs')()
  .env('')
  .boolean('enableGasReport')
  .boolean('ci')
  .string('compileMode')
  .argv;

require('@nomiclabs/hardhat-truffle5');
require('@nomiclabs/hardhat-solhint');
require('solidity-coverage');

require('hardhat-gas-reporter');
require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-web3');

require('hardhat-deploy');

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: '0.8.3',
    namedAccounts: {
      deployer: 0
    },
    settings: {
      optimizer: {
        enabled: argv.enableGasReport || argv.compileMode === 'production',
        runs: 800,
      },
    },
  },
  networks: {
    hardhat: {
      blockGasLimit: 14000000,
    },
    goerli: {
      url: `https://eth-goerli.alchemyapi.io/v2/${process.env.ARCHEMY_PROJECT_ID}`,
      accounts: [process.env.TESTER_PRIVATE_KEY]
    }
  },
  gasReporter: {
    currency: 'USD',
    gasPrice: 40,
    coinmarketcap: process.env.COIN_MARKET_CAP_API
  },
};

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task('accounts', 'Prints the list of accounts', async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});
