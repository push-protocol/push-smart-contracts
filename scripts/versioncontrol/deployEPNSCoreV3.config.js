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
      version: 3
    },
    rinkeby: {
      version: 3
    },
    hardhat: {
      version: 1
    },
    localhost: {
      version: 1
    }
  },
  args: {
    epnsProxyAddress: "0x6A5aC83f9f6C2849e40A027f7A0d68032Ebf28F8"
  }
}

exports.deploy = deploy