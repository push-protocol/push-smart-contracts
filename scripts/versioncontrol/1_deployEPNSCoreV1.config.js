const deploy = {
  network: {
    mainnet: {
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
    daiAddress: null,
    aDaiAddress: null,
    wethAddress: null,
    pushAddress: null,
    uniswapRouterAddress: null,
    aaveLendingAddress: null,
    referralCode: null
  }
}

exports.deploy = deploy
