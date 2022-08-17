const chalk = require("chalk");
const {ethers } = require("hardhat");
const { versionVerifier, upgradeVersion } = require('../loaders/versionVerifier')

const {deployContract, verifyAllContracts } = require('../helpers/utils')

async function main() {
  // Version Check
  console.log(chalk.bgBlack.bold.green(`\n✌️  Running Version Checks \n-----------------------\n`))
  const versionDetails = versionVerifier(["epnsProxyAddress", "epnsCoreAdmin"])
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
  const EPNSCoreV1_Temp = await deployContract("EPNSCoreV1_Temp", [], "EPNSCoreV1_Temp");
  deployedContracts.push(EPNSCoreV1_Temp)

  const EPNSCoreAdmin = await ethers.getContractFactory("EPNSCoreAdmin")
  const EPNSCoreAdminInstance = EPNSCoreAdmin.attach(versionDetails.deploy.args.epnsCoreAdmin)
 
  console.log(chalk.bgWhite.bold.black(`\n\t\t\t\n ✅ Upgrading Contract to`), chalk.magenta(`${EPNSCoreV1_Temp.address} \n\t\t\t\n`))
  await EPNSCoreAdminInstance.upgrade(versionDetails.deploy.args.epnsProxyAddress, EPNSCoreV1_Temp.address);
  console.log(chalk.bgWhite.bold.black(`\n\t\t\t\n ✅ Contracts Upgraded  \n\t\t\t\n`))

  return deployedContracts
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });