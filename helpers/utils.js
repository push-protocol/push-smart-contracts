const { ethers } = require("hardhat")

const chalk = require("chalk")
const fs = require("fs")

const tokenInfo = {
    // token info to test
    name: 'Ethereum Push Notification Service',
    symbol: 'PUSH',
    decimals: 18,
    supply: 100000000, // 100 Million $PUSH
}

// define functions and constants
const CONSTANT_1K = 1000
const CONSTANT_10K = 10 * CONSTANT_1K
const CONSTANT_100K = 10 * CONSTANT_10K
const CONSTANT_1M = 10 * CONSTANT_100K

bn = function(number, defaultValue = null) { if (number == null) { if (defaultValue == null) { return null } number = defaultValue } return ethers.BigNumber.from(number) }

tokens = function (amount) { return (bn(amount).mul(bn(10).pow(tokenInfo.decimals))).toString() }
tokensBN = function (amount) { return (bn(amount).mul(bn(10).pow(tokenInfo.decimals))) }
bnToInt = function (bnAmount) { return bnAmount.div(bn(10).pow(tokenInfo.decimals)) }

dateToEpoch = function (dated) { return moment(dated, "DD/MM/YYYY HH:mm").valueOf() / 1000 }
timeInSecs = function (days, hours, mins, secs) { return days * hours * mins * secs }
timeInDays = function (secs) { return (secs / (60 * 60 * 24)).toFixed(2) }
timeInDate = function (secs) { return moment(secs * 1000).format("DD MMM YYYY hh:mm a") }

vestedAmount = function (total, now, start, cliffDuration, duration) { return now < start + cliffDuration ? ethers.BigNumber.from(0) : total.mul(now - start).div(duration) }
returnWeight = function (sourceWeight, destBal, destWeight, amount, block, op) {
  // console.log({sourceWeight, destBal, destWeight, amount})
  if (bn(destBal).eq(bn("0"))) return bn(0)
  const dstWeight = bn(destWeight).mul(bn(destBal))
  const srcWeight = bn(sourceWeight).mul(bn(amount))

  const totalWeight = dstWeight.add(srcWeight)
  const totalAmount = bn(destBal).add(amount)

  const totalAmountBy2 = totalAmount.div(bn(2))
  const roundUpWeight = totalWeight.add(totalAmountBy2)
  let holderWeight = roundUpWeight.div(totalAmount)
  if (op == "transfer") {
    return { holderWeight, totalAmount };
  } else {
    holderWeight = block
    return { holderWeight, totalAmount };
  }
}

// Helper Functions
// For Deploy
deploy = async function deploy(name, _args, identifier) {
  const args = _args || []

  console.log(`📄 ${name}`)
  const contractArtifacts = await ethers.getContractFactory(name)
  const contract = await contractArtifacts.deploy(...args)
  await contract.deployed()
  console.log(
    chalk.cyan(name),
    "deployed to:",
    chalk.magenta(contract.address)
  )
  fs.writeFileSync(`artifacts/${name}_${identifier}.address`, contract.address)
  return contract
}

deployContract = async function deployContract(contractName, contractArgs, identifier) {
  let contract = await deploy(contractName, contractArgs, identifier)

  contract.filename = `${contractName} -> ${identifier}`
  contract.deployargs = contractArgs
  contract.customid = identifier

  return contract
}

readArgumentsFile = function readArgumentsFile(contractName) {
  let args = []
  try {
    const argsFile = `./contracts/${contractName}.args`
    if (fs.existsSync(argsFile)) {
      args = JSON.parse(fs.readFileSync(argsFile))
    }
  } catch (e) {
    console.log(e)
  }

  return args
}

// Verify All Contracts
verifyAllContracts = async function verifyAllContracts(deployedContracts, versionDetails) {
  return new Promise(async function(resolve, reject) {
    try {
      if (deployedContracts.length == 0) resolve()

        const path = require("path")

        const deployment_path = path.join('artifacts', 'deployment_info')
        const network_path = path.join(deployment_path, hre.network.name)
        const bulk_path = path.join(network_path, process.env.FS_BULK_EXPORT)

        if (!fs.existsSync(deployment_path)) {
          fs.mkdirSync(deployment_path)
        }

        if (!fs.existsSync(network_path)) {
          fs.mkdirSync(network_path)
        }

        if (!fs.existsSync(bulk_path)) {
          fs.mkdirSync(bulk_path)
        }

        let allContractsInfo = '-----\nVersion: ' + versionDetails.version + '\n-----'

        for await (contract of deployedContracts) {
          allContractsInfo = allContractsInfo + '\n-----'

          let contractInfo = `custom id: ${contract.customid}\nfilename: ${contract.filename}\naddress: ${contract.address}\nargs: ${contract.deployargs}`
          fs.writeFileSync(`${network_path}/${contract.filename}.address`, contractInfo)

          const arguments = contract.deployargs

          if (hre.network.name != "hardhat" && hre.network.name != "localhost") {
            // Mostly a real network, verify
            const { spawnSync } = require( 'child_process' )
            const ls = spawnSync( `npx`, [ 'hardhat', 'verify', '--network', hre.network.name, contract.address, '--contract', `contracts/${contract.customid}.sol:${contract.customid}` ].concat(arguments) )

            console.log( `Error: ${ ls.stderr.toString() }` )
            console.log( `Output: ${ ls.stdout.toString() }` )

            contractInfo = `${contractInfo}\nError: ${ ls.stderr.toString() }\nOutput: ${ ls.stdout.toString() }`
          }
          else {
            console.log(chalk.bgWhiteBright.black(`${contract.filename}.sol`), chalk.bgRed.white(` is on Hardhat network... skipping`))
            contractInfo = contractInfo + "\nOutput: " + hre.network.name + " Network... skipping"
          }

          allContractsInfo = allContractsInfo + "\n" + contractInfo
        }

        fs.writeFileSync(`${bulk_path}/Bulk -> ${contract.customid}.add`, allContractsInfo)

        resolve()
    } catch (error) {
      console.log(error)
    }
  })
}

// For Distributing funds
distributeInitialFunds = async function distributeInitialFunds(tokenContract, contract, amount, signer) {
  let balance;
  console.log(chalk.bgBlue.white(`Distributing Initial Funds`))
  console.log(chalk.bgBlack.white(`Sending Funds to ${contract.filename}`), chalk.green(`${ethers.utils.formatUnits(amount)} PUSH`))

  balance = await tokenContract.balanceOf(signer.address)
  console.log(chalk.bgBlack.white(`Push Token Balance Before Transfer:`), chalk.yellow(`${ethers.utils.formatUnits(balance)} PUSH`))
  const tx = await tokenContract.transfer(contract.address, amount)
  await tx.wait()

  balance = await tokenContract.balanceOf(signer.address)
  console.log(chalk.bgBlack.white(`Push Token Balance After Transfer:`), chalk.yellow(`${ethers.utils.formatUnits(balance)} PUSH`))

  console.log(chalk.bgBlack.white(`Transaction hash:`), chalk.gray(`${tx.hash}`))
  console.log(chalk.bgBlack.white(`Transaction etherscan:`), chalk.gray(`https://${hre.network.name}.etherscan.io/tx/${tx.hash}`))
}

// For Distributing funds from CommUnlocked
sendFromCommUnlocked = async function sendFromCommUnlocked(tokenContract, reservesContract, reservesOwner, receiverAddr, amount) {
  let balance;
  console.log(chalk.bgBlue.white(`Sending Funds from Comm Unlocked`))
  console.log(chalk.bgBlack.white(`Sending Funds to ${receiverAddr}`), chalk.green(`${ethers.utils.formatUnits(amount)} PUSH`))

  balance = await tokenContract.balanceOf(receiverAddr)
  console.log(chalk.bgBlack.white(`Receiver Push Token Balance Before Transfer:`), chalk.yellow(`${ethers.utils.formatUnits(balance)} PUSH`))

  const tx = await reservesContract.connect(reservesOwner).transferTokensToAddress(receiverAddr, amount)
  await tx.wait()

  balance = await tokenContract.balanceOf(receiverAddr)
  console.log(chalk.bgBlack.white(`Receiver Push Token Balance After Transfer:`), chalk.yellow(`${ethers.utils.formatUnits(balance)} PUSH`))

  console.log(chalk.bgBlack.white(`Transaction hash:`), chalk.gray(`${tx.hash}`))
  console.log(chalk.bgBlack.white(`Transaction etherscan:`), chalk.gray(`https://${hre.network.name}.etherscan.io/tx/${tx.hash}`))
}

// Get private key from mneomonic
extractWalletFromMneomonic = async function (mnemonic) {
  const bip39 = require("bip39");
  const { hdkey } = require('ethereumjs-wallet')

  const seed = await bip39.mnemonicToSeed(mnemonic);
  const hdwallet = hdkey.fromMasterSeed(seed);
  const wallet_hdpath = "m/44'/60'/0'/0/";
  const account_index = 0;
  const fullPath = wallet_hdpath + account_index;
  const wallet = hdwallet.derivePath(fullPath).getWallet();
  const privateKey = "0x" + wallet.privateKey.toString("hex");

  const EthUtil = require("ethereumjs-util");
  const address = "0x" + EthUtil.privateToAddress(wallet.privateKey).toString("hex");

  return {
    privateKey: privateKey,
    address: address
  }
}

const ADJUST_FOR_FLOAT = bn(10 ** 7)

const ChannelAction = {
    ChannelAdded: 1,
    ChannelRemoved: 2,
    ChannelUpdated: 3,
}

const SubscriberAction = {
    SubscriberAdded: 1,
    SubscriberRemoved: 2,
    SubscriberUpdated: 3,
}

const readjustFairShareOfChannels = (
    _action,
    _channelWeight,
    _oldChannelWeight,
    _groupFairShareCount,
    _groupNormalizedWeight,
    _groupHistoricalZ,
    _groupLastUpdate,
    blockNumber
) => {
    let groupModCount = _groupFairShareCount;
    let adjustedNormalizedWeight = _groupNormalizedWeight; //_groupNormalizedWeight;
    let totalWeight = adjustedNormalizedWeight.mul(groupModCount);
    // Increment or decrement count based on flag
    if (_action == ChannelAction.ChannelAdded) {
        groupModCount = groupModCount.add(1);
        totalWeight = totalWeight.add(_channelWeight);
    }
    else if (_action == ChannelAction.ChannelRemoved) {
        groupModCount = groupModCount.sub(1);
        totalWeight = totalWeight.add(_channelWeight).sub(_oldChannelWeight);
    }
    else if (_action == ChannelAction.ChannelUpdated) {
        totalWeight = totalWeight.add(_channelWeight).sub(_oldChannelWeight);
    }
    else {
        return
    }

    // now calculate the historical constant
    // z = z + nxw
    // z is the historical constant
    // n is the previous count of group fair share
    // x is the differential between the latest block and the last update block of the group
    // w is the normalized average of the group (ie, groupA weight is 1 and groupB is 2 then w is (1+2)/2 = 1.5)
    let n = groupModCount;
    let x = blockNumber.sub(_groupLastUpdate);
    let w = totalWeight.div(groupModCount);
    let z = _groupHistoricalZ;

    let nx = n.mul(x);
    let nxw = nx.mul(w);

    // Save Historical Constant and Update Last Change Block
    z = z.add(nxw);

    if (n == 1) {
        // z should start from here as this is first channel
        z = 0;
    }

    // Update return variables
    const groupNewCount = groupModCount;
    const groupNewNormalizedWeight = w;
    const groupNewHistoricalZ = z;
    const groupNewLastUpdate = blockNumber;

    return {
        groupNewCount,
        groupNewNormalizedWeight,
        groupNewHistoricalZ,
        groupNewLastUpdate
    }
}

const readjustFairShareOfSubscribers = (
    _action,
    _channelFairShareCount,
    _channelHistoricalZ,
    _channelLastUpdate,
    blockNumber
) => {
    let channelModCount = _channelFairShareCount;
    let prevChannelCount = channelModCount;

    // Increment or decrement count based on flag
    if (_action == SubscriberAction.SubscriberAdded) {
        channelModCount = channelModCount.add(1);
    }
    else if (_action == SubscriberAction.SubscriberRemoved) {
        channelModCount = channelModCount.sub(1);
    }
    else if (_action == SubscriberAction.SubscriberUpdated) {
        // do nothing, it's happening after a reset of subscriber last update count

    }
    else {
        return
    }

    // to calculate the historical constant
    // z = z + nx
    // z is the historical constant
    // n is the total prevoius subscriber count
    // x is the difference bewtween the last changed block and the current block
    let x = blockNumber.sub(_channelLastUpdate);
    let nx = prevChannelCount.mul(x);
    let z = _channelHistoricalZ.add(nx);

    // Define Values
    channelNewFairShareCount = channelModCount;
    channelNewHistoricalZ = z;
    channelNewLastUpdate = blockNumber;

    return {
        channelNewFairShareCount,
        channelNewHistoricalZ,
        channelNewLastUpdate,
    }
}

const calcChannelFairShare = (
    currentBlock,
    channelStartBlock,
    channelWeight,
    groupHistoricalZ,
    groupFairShareCount,
    groupLastUpdate,
    groupNormalizedWeight
) => {
    // formula is ratio = da / z + (nxw)
    // d is the difference of blocks from given block and the last update block of the entire group
    // a is the actual weight of that specific group
    // z is the historical constant
    // n is the number of channels
    // x is the difference of blocks from given block and the last changed start block of group
    // w is the normalized weight of the groups

    const d = currentBlock - channelStartBlock;
    const a = channelWeight;
    const z = groupHistoricalZ;
    const n = groupFairShareCount;
    const x = currentBlock - groupLastUpdate;
    const w = groupNormalizedWeight;

    const NXW = n * x * w;
    const ZNXW = z + NXW;
    const da = d * a;

    // eslint-disable-next-line camelcase
    return (da * ADJUST_FOR_FLOAT) / ZNXW;
};

const calcSubscriberFairShare = (
    currentBlock,
    memberLastUpdate,
    channelHistoricalZ,
    channelLastUpdate,
    channelFairShareCount
) => {
    // formula is ratio = d / z + (nx)
    // d is the difference of blocks from given block and the start block of subscriber
    // z is the historical constant
    // n is the number of subscribers of channel
    // x is the difference of blocks from given block and the last changed start block of channel
    const d = currentBlock - memberLastUpdate;
    const z = channelHistoricalZ;
    const x = currentBlock - channelLastUpdate;

    const nx = channelFairShareCount * x;
    console.log('nx', nx)
    return (d * ADJUST_FOR_FLOAT) / (z + nx); // == d / z + n * x
};

const getPubKey = async (
    signer
) => {
    const message = "epns.io"
    const signature = await signer.signMessage(message)
    const msgHash = ethers.utils.hashMessage(message);
    const msgHashBytes = ethers.utils.arrayify(msgHash);
    const recoveredPubKey = ethers.utils.recoverPublicKey(msgHashBytes, signature);

    return ethers.utils.arrayify(recoveredPubKey);
}

module.exports = {
    calcChannelFairShare,
    calcSubscriberFairShare,
    readjustFairShareOfChannels,
    readjustFairShareOfSubscribers,
    getPubKey,
    ChannelAction,
    SubscriberAction,
    CONSTANT_1K,
    CONSTANT_10K,
    CONSTANT_100K,
    CONSTANT_1M,
    bn,
    tokens,
    tokensBN,
    bnToInt,
    dateToEpoch,
    timeInSecs,
    timeInDays,
    timeInDate,
    vestedAmount,
    returnWeight,
    deploy,
    deployContract,
    readArgumentsFile,
    verifyAllContracts,
    distributeInitialFunds,
    sendFromCommUnlocked,
    extractWalletFromMneomonic
}
