require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");

require('dotenv').config();
const assert = require('assert').strict;
const privateKey = process.env.PRIVATE_KEY;
assert.ok(privateKey, 'The "PRIVATE_KEY" environment variable is required');

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.7",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  defaultNetwork: "testnet",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545"
    },
    hardhat: {
    },
    testnet: {
      url: "https://http-testnet.cube.network",
      chainId: 1819,
      gasPrice: 20000000000,
      accounts: [privateKey]
    },
    mainnet: {
      url: "https://http-mainnet.cube.network",
      chainId: 1818,
      gasPrice: 20000000000,
      accounts: [privateKey]
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 20000
  }
};
