const deploy = {
  network: {
    mainnet: {
      version: 1,
    },
    goerli: {
      version: 1,
    },
    polygon: {
      version: 1,
    },
    polygonMumbai: {
      version: 1,
    },
    bnbTestnet: {
      version: 1,
    },
    bnbMainnet: {
      version: 1,
    },
    arbitrumSepolia: {
      version: 1,
    },
    arbitrumMainnet: {
      version: 1,
    },
    optimismSepolia: {
      version: 1,
    },
    optimismMainnet: {
      version: 1,
    },
    hardhat: {
      version: 1,
    },
    localhost: {
      version: 1,
    }
  },
  args: {
    epnsProxyAddress: null,
    epnsCoreAdmin: null
  }
}

exports.deploy = deploy
