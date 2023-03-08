// Load Libraries
const chalk = require('chalk');
const fs = require("fs");

require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-ethers");
// require("hardhat-gas-reporter");

const { ethers } = require("ethers");
const { isAddress, getAddress, formatUnits, parseUnits } = ethers.utils;

// Check ENV File first and load ENV
verifyENV();
async function verifyENV() {
  const envVerifierLoader = require('./loaders/envVerifier');
  envVerifierLoader(true);
}

require('dotenv').config();

const defaultNetwork = "hardhat";

function mnemonic() {
  try {
    return fs.readFileSync("./mnemonic.txt").toString().trim();
  } catch (e) {
    if (defaultNetwork !== "localhost") {
      console.log(
        "☢️ WARNING: No mnemonic file created for a deploy account. Try `yarn run generate` and then `yarn run account`."
      );
    }
  }
  return "";
}

module.exports = {
  defaultNetwork,

  // don't forget to set your provider like:
  // REACT_APP_PROVIDER=https://dai.poa.network in packages/react-app/.env
  // (then your frontend will talk to your contracts on the live network!)
  // (you will need to restart the `yarn run start` dev server after editing the .env)

  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      forking: {
        url:
          `https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API}`,
          blockNumber: 15917401
      },
    },
    localhost: {
      url: "http://localhost:8545",
      /*
        notice no mnemonic here? it will just use account 0 of the buidler node to deploy
        (you can put in a mnemonic here to set the deployer locally)
      */
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_PROJECT_ID}`, // <---- YOUR INFURA ID! (or it won't work)
      accounts: {
        mnemonic: mnemonic(),
      },
    },
    ropsten: {
      url: `https://ropsten.infura.io/v3/${process.env.INFURA_PROJECT_ID}`, // <---- YOUR INFURA ID! (or it won't work)
      accounts: {
        mnemonic: mnemonic(),
      },
    },
    kovan: {
      url: `https://kovan.infura.io/v3/${process.env.INFURA_PROJECT_ID}`, // <---- YOUR INFURA ID! (or it won't work)
      accounts: {
        mnemonic: mnemonic(),
      },
    },
    goerli: {
      url: `https://goerli.infura.io/v3/${process.env.INFURA_PROJECT_ID}`, // <---- YOUR INFURA ID! (or it won't work)
      accounts: {
        mnemonic: mnemonic(),
      },
    },
    polygonMumbai: {
      url: `https://polygon-mumbai.infura.io/v3/${process.env.INFURA_PROJECT_ID}`, // <---- YOUR INFURA ID! (or it won't work)
      accounts: {
        mnemonic: mnemonic(),
      },
    },
    polygon: {
      url: `https://polygon-mainnet.infura.io/v3/${process.env.INFURA_PROJECT_ID}`, // <---- YOUR INFURA ID! (or it won't work)
      accounts: {
        mnemonic: mnemonic(),
      },
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_PROJECT_ID}`, // <---- YOUR INFURA ID! (or it won't work)
      aaccounts: {
        mnemonic: mnemonic(),
      },
    },

    xdai: {
      url: "https://dai.poa.network",
      gasPrice: 1000000000,
      accounts: {
        mnemonic: mnemonic(),
      },
    },
  },
  etherscan: {
   // Your API key for Etherscan and Polygonscan
   apiKey: process.env.ETHERSCAN_API,
   //apiKey: process.env.POLYGONSCAN_API
 },
  solidity: {
    version: "0.6.11",
    settings: {
      optimizer: {
        enabled: true,
        runs: 99999,
      },
    },
  },
};
// ENABLE / DISABLE DEBUG
const DEBUG = true;

function debug(text) {
  if (DEBUG) {
    console.log(text);
  }
}

// To Generate mnemonic
function mnemonic() {
  try {
    return fs.readFileSync("./wallets/main_mnemonic.txt").toString().trim();
  } catch (e) {
    if (defaultNetwork !== "localhost") {
      console.log(
        "☢️ WARNING: No mnemonic file created for a deploy account. Try `npx hardhat generate` and then `npx hardhat account`."
      );
    }
  }
  return "";
}

function getPrivateKey() {
  try {
    const key = fs.readFileSync("./wallets/main_privateKey.txt").toString().trim();
    return [key];
  } catch (e) {
    if (defaultNetwork !== "localhost") {
      console.log(
        "☢️ WARNING: No mnemonic / private key file created for a deploy account. Try `npx hardhat generate` and then `npx hardhat account`."
      );
    }
  }

  return "";
}

task(
  "generate",
  "Create a mnemonic for builder deploys",
  async (_, { ethers }) => {
    const generate = async (isSecondary) => {
      const bip39 = require("bip39");
      const { hdkey } = require('ethereumjs-wallet')

      const mnemonic = bip39.generateMnemonic();
      const seed = await bip39.mnemonicToSeed(mnemonic);
      const hdwallet = hdkey.fromMasterSeed(seed);
      const wallet_hdpath = "m/44'/60'/0'/0/";
      const account_index = 0;
      const fullPath = wallet_hdpath + account_index;
      const wallet = hdwallet.derivePath(fullPath).getWallet();
      const privateKey = "0x" + wallet.privateKey.toString("hex");


      if (DEBUG) console.log(chalk.bgGreen.bold.black(`\n\t\t\t`))
      if (DEBUG) console.log(chalk.bgBlack.bold.white(` 💰 Wallet - ${isSecondary ? "alt_wallet" : "main_wallet"} | ${privateKey} `))
      if (DEBUG) console.log(chalk.bgGreen.bold.black(`\t\t\t\n`))
      if (DEBUG) console.log("mnemonic", mnemonic);
      if (DEBUG) console.log("seed", seed);
      if (DEBUG) console.log("fullPath", fullPath);
      if (DEBUG) console.log("privateKey", privateKey);

      const EthUtil = require("ethereumjs-util");
      const address = "0x" + EthUtil.privateToAddress(wallet.privateKey).toString("hex");

      console.log(
        "🔐 Account Generated as " +
          address +
          ".txt and set as mnemonic in packages/buidler"
      );
      console.log(
        "💬 Use 'npx hardhat account' to get more information about the deployment account."
      );

      if (isSecondary) {
        fs.writeFileSync("./wallets/alt_" + address + ".txt", mnemonic.toString() + "\n" + privateKey);
        fs.writeFileSync("./wallets/alt_mnemonic.txt", mnemonic.toString());
        fs.writeFileSync("./wallets/alt_private.txt", privateKey.toString());
      }
      else {
        fs.writeFileSync("./wallets/main_" + address + ".txt", mnemonic.toString() + "\n" + privateKey);
        fs.writeFileSync("./wallets/main_mnemonic.txt", mnemonic.toString());
        fs.writeFileSync("./wallets/main_privatekey.txt", privateKey.toString());
      }

      if (DEBUG) console.log("\n------\n");
    }

    await generate()
    await generate(true)
  }
);

task(
  "account",
  "Get balance informations for the deployment account.",
  async (_, { ethers }) => {
    const showAccount = async (walletName) => {

      const { hdkey } = require('ethereumjs-wallet')

      const bip39 = require("bip39");
      const mnemonic = fs.readFileSync(`./wallets/${walletName}_mnemonic.txt`).toString().trim();
      const seed = await bip39.mnemonicToSeed(mnemonic);
      const hdwallet = hdkey.fromMasterSeed(seed);
      const wallet_hdpath = "m/44'/60'/0'/0/";
      const account_index = 0;
      const fullPath = wallet_hdpath + account_index;
      const wallet = hdwallet.derivePath(fullPath).getWallet();
      const privateKey = "0x" + wallet.privateKey.toString("hex");
      const EthUtil = require("ethereumjs-util");
      const address =
        "0x" + EthUtil.privateToAddress(wallet.privateKey).toString("hex");


      if (DEBUG) console.log(chalk.bgGreen.bold.black(`\n\t\t\t`))
      if (DEBUG) console.log(chalk.bgBlack.bold.white(` 💰 Wallet - ${walletName} | ${privateKey} `))
      if (DEBUG) console.log(chalk.bgGreen.bold.black(`\t\t\t\n`))

      if (DEBUG) console.log("mnemonic", mnemonic);
      if (DEBUG) console.log("seed", seed);
      if (DEBUG) console.log("fullPath", fullPath);
      if (DEBUG) console.log("privateKey", privateKey);
      if (DEBUG) console.log("‍📬 Deployer Account is " + address);
      const qrcode = require("qrcode-terminal");
      qrcode.generate(address);

      for (const n in config.networks) {
        // console.log(config.networks[n],n)
        try {
          const provider = new ethers.providers.JsonRpcProvider(
            config.networks[n].url
          );
          const balance = await provider.getBalance(address);
          console.log(" -- " + n + " --  -- -- 📡 ");
          console.log("   balance: " + ethers.utils.formatEther(balance));
          console.log(
              // eslint-disable-next-line no-await-in-loop
            "   nonce: " + (await provider.getTransactionCount(address))
          );
        } catch (e) {
          if (DEBUG) {
            console.log(e);
          }
        }
      }

      if (DEBUG) console.log("\n------\n");
    }

    await showAccount("main")
    await showAccount("alt")
  }
);

async function addr(ethers, addr) {
  if (isAddress(addr)) {
    return getAddress(addr);
  }
  const accounts = await ethers.provider.listAccounts();
  if (accounts[addr] !== undefined) {
    return accounts[addr];
  }
  throw `Could not normalize address: ${addr}`;
}

task("accounts", "Prints the list of accounts", async (_, { ethers }) => {
  const accounts = await ethers.provider.listAccounts();
  accounts.forEach((account) => console.log(account));
});

task("blockNumber", "Prints the block number", async (_, { ethers }) => {
  const blockNumber = await ethers.provider.getBlockNumber();
  console.log(blockNumber);
});

task("balance", "Prints an account's balance")
  .addPositionalParam("account", "The account's address")
  .setAction(async (taskArgs, { ethers }) => {
    const balance = await ethers.provider.getBalance(
      await addr(ethers, taskArgs.account)
    );
    console.log(formatUnits(balance, "ether"), "ETH");
  }
);

function send(signer, txparams) {
  return signer.sendTransaction(txparams, (error, transactionHash) => {
    if (error) {
      debug(`Error: ${error}`);
    }
    debug(`transactionHash: ${transactionHash}`);
    // checkForReceipt(2, params, transactionHash, resolve)
  });
}

task("send", "Send ETH")
  .addParam("from", "From address or account index")
  .addOptionalParam("to", "To address or account index")
  .addOptionalParam("amount", "Amount to send in ether")
  .addOptionalParam("data", "Data included in transaction")
  .addOptionalParam("gasPrice", "Price you are willing to pay in gwei")
  .addOptionalParam("gasLimit", "Limit of how much gas to spend")

  .setAction(async (taskArgs, { network, ethers }) => {
    const from = await addr(ethers, taskArgs.from);
    debug(`Normalized from address: ${from}`);
    const fromSigner = await ethers.provider.getSigner(from);

    let to;
    if (taskArgs.to) {
      to = await addr(ethers, taskArgs.to);
      debug(`Normalized to address: ${to}`);
    }

    const txRequest = {
      from: await fromSigner.getAddress(),
      to,
      value: parseUnits(
        taskArgs.amount ? taskArgs.amount : "0",
        "ether"
      ).toHexString(),
      nonce: await fromSigner.getTransactionCount(),
      gasPrice: parseUnits(
        taskArgs.gasPrice ? taskArgs.gasPrice : "1.001",
        "gwei"
      ).toHexString(),
      gasLimit: taskArgs.gasLimit ? taskArgs.gasLimit : 24000,
      chainId: network.config.chainId,
    };

    if (taskArgs.data !== undefined) {
      txRequest.data = taskArgs.data;
      debug(`Adding data to payload: ${txRequest.data}`);
    }
    debug(txRequest.gasPrice / 1000000000 + " gwei");
    debug(JSON.stringify(txRequest, null, 2));

    return send(fromSigner, txRequest);
  }
);
