const deploy = {
  network: {
    mainnet: {
      version: 1
    },
    goerli: {
      version: 1
    },
    kovan: {
      version: 1
    },
    ropsten: {
      version: 1
    },
    rinkeby: {
      version: 1
    },
    hardhat: {
      version: 2
    },
    localhost: {
      version: 1
    }
  },
  args: {
    daiAddress: "0xf80A32A835F79D7787E8a8ee5721D0fEaFd78108",
    aDaiAddress: "0xcB1Fe6F440c49E9290c3eb7f158534c2dC374201",
    wethAddress: "0xc778417E063141139Fce010982780140Aa0cD5Ab",
    pushAddress: "0xf418588522d5dd018b425E472991E52EBBeEEEEE",
    uniswapRouterAddress: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
    aaveLendingAddress: "0x1c8756FD2B28e9426CDBDcC7E3c4d64fa9A54728",
    referralCode: "0"
  }
}

exports.deploy = deploy
