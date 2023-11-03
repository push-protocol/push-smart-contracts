const deploy = {
  network: {
    mainnet: {
      version: 1,
    },
    goerli: {
      version: 1,
    },
    sepolia: {
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
    arbitrumTestnet: {
      version: 1,
    },
    arbitrumMainnet: {
      version: 1,
    },
    optimismGoerli: {
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
    },
  },
  args: {
    daiAddress: "0x0000000000000000000000000000000000000000",
    aDaiAddress: "0x0000000000000000000000000000000000000000",
    wethAddress: "0x0000000000000000000000000000000000000000",
    pushAddress: "0x37c779a1564dcc0e3914ab130e0e787d93e21804",
    uniswapRouterAddress: "0x0000000000000000000000000000000000000000",
    aaveLendingAddress: "0x0000000000000000000000000000000000000000",
    referralCode: "0",
  },
};

exports.deploy = deploy;
