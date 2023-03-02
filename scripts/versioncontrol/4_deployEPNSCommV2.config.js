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
    hardhat: {
      version: 1,
    },
    localhost: {
      version: 1,
    }
  },
  args: {
    epnsProxyAddress: null,
    epnsCommAdmin: null
  }
}

exports.deploy = deploy
