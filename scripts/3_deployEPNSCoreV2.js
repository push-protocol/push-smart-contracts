const fs = require("fs");
const chalk = require("chalk");
const { config, ethers } = require("hardhat");
const { versionVerifier, upgradeVersion } = require('../loaders/versionVerifier')

const { bn, tokens, bnToInt, timeInDays, timeInDate, readArgumentsFile, deployContract, verifyAllContracts } = require('../helpers/utils')

async function main() {
  // Version Check
  console.log(chalk.bgBlack.bold.green(`\n✌️  Running Version Checks \n-----------------------\n`))
  const versionDetails = versionVerifier(["epnsProxyAddress", "epnsAdmin"])
  console.log(chalk.bgWhite.bold.black(`\n\t\t\t\n Version Control Passed \n\t\t\t\n`))

  // First deploy all contracts
  console.log(chalk.bgBlack.bold.green(`\n📡 Deploying Contracts \n-----------------------\n`))
  const deployedContracts = await setupAllContracts(versionDetails)
  console.log(chalk.bgWhite.bold.black(`\n\t\t\t\n All Contracts Deployed \n\t\t\t\n`))

  // Try to verify
  console.log(chalk.bgBlack.bold.green(`\n📡 Verifying Contracts \n-----------------------\n`))
  await verifyAllContracts(deployedContracts, versionDetails)
  console.log(chalk.bgWhite.bold.black(`\n\t\t\t\n All Contracts Verified \n\t\t\t\n`))

  // Upgrade Version
  console.log(chalk.bgBlack.bold.green(`\n📟 Upgrading Version   \n-----------------------\n`))
  upgradeVersion()
  console.log(chalk.bgWhite.bold.black(`\n\t\t\t\n ✅ Version upgraded    \n\t\t\t\n`))
}

async function setupAllContracts(versionDetails) {
  let deployedContracts = []
  console.log("📡 Deploy \n");
  // auto deploy to read contract directory and deploy them all (add ".args" files for arguments)
  // await autoDeploy();
  // OR
  // custom deploy (to use deployed addresses dynamically for example:)
  const [adminSigner, aliceSigner, bobSigner, eventualAdmin] = await ethers.getSigners();

  const EPNSCoreV2 = await deployContract("EPNSCoreV2", [], "EPNSCoreV2");
  deployedContracts.push(EPNSCoreV2)

  const EPNSAdmin = await ethers.getContractFactory("EPNSAdmin")
  const epnsAdminInstance = EPNSAdmin.attach(versionDetails.deploy.args.epnsAdmin)

  console.log(chalk.bgWhite.bold.black(`\n\t\t\t\n ✅ Upgrading Contract to`), chalk.magenta(`${EPNSCoreV2.address} \n\t\t\t\n`))
  await epnsAdminInstance.upgrade(versionDetails.deploy.args.epnsProxyAddress, EPNSCoreV2.address);
  console.log(chalk.bgWhite.bold.black(`\n\t\t\t\n ✅ Contracts Upgraded  \n\t\t\t\n`))

  return deployedContracts
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
