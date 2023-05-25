const deploy = {
  network: {
    mainnet: {
      version: 1
    },
    goerli: {
      version: 1
    },
    hardhat: {
      version: 1
    },
    localhost: {
      version: 1
    },
    polygonMumbai: {
      version: 1
    },
    bscTestnet: {
      version: 1
    },
    zkEVMTestnet: {
      version: 1
    },
    optimismGoerli: {
      version: 1
    },
    optimismMainnet: {
      version: 1
    },
    polygon: {
      version: 1
    },
    linea: {
      version: 1
    },
    bscMainnet: {
      version: 1
    },
    xdai: {
      version: 1
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
  // args: {
  //   daiAddress: "0x75Ab5AB1Eef154C0352Fc31D2428Cef80C7F8B33",
  //   aDaiAddress: "0x31f30d9A5627eAfeC4433Ae2886Cf6cc3D25E772",
  //   wethAddress: "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6",
  //   pushAddress: "0x2b9bE9259a4F5Ba6344c1b1c07911539642a2D33",
  //   uniswapRouterAddress: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
  //   aaveLendingAddress: "0x5E52dEc931FFb32f609681B8438A51c675cc232d",
  //   referralCode: "0"
  // }
}

exports.deploy = deploy
