// Load Libraries
const chalk = require("chalk");
const fs = require("fs");

require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-ethers");
require("hardhat-gas-reporter");

require("dotenv").config();

const defaultNetwork = "hardhat";

module.exports = {
  contractSizer: {
    alphaSort: false,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
    only: [],
  },
  defaultNetwork,

  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      // forking: {
      //   url:
      //     `https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API}`,
      //     blockNumber: 15917401
      // },
    },
    localhost: {
      url: "http://localhost:8545",
      
    },

    // ETH Network
    goerli: {
      url: `https://goerli.infura.io/v3/${process.env.INFURA_PROJECT_ID}`, // <---- YOUR INFURA ID! (or it won't work)
      accounts: [process.env.PRIVATE],
    },
    sepolia: {
      url: `https://sepolia.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
      accounts: [process.env.PRIVATE],
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_PROJECT_ID}`, // <---- YOUR INFURA ID! (or it won't work)
      accounts: [process.env.PRIVATE],
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API,
  },

  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 99999,
      },
    },
  },
};
