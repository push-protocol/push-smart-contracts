require("dotenv").config();

const moment = require("moment");
const hre = require("hardhat");

const fs = require("fs");
const chalk = require("chalk");
const { config, ethers } = require("hardhat");

const {
  bn,
  tokens,
  bnToInt,
  timeInDays,
  timeInDate,
  readArgumentsFile,
  deployContract,
  verifyAllContracts,
} = require("../helpers/utils");
const {
  versionVerifier,
  upgradeVersion,
} = require("../loaders/versionVerifier");

async function main() {
  // Version Check
  console.log(
    chalk.bgBlack.bold.green(
      `\n✌️  Running Version Checks \n-----------------------\n`
    )
  );
  const versionDetails = versionVerifier([
    "daiAddress",
    "aDaiAddress",
    "wethAddress",
    "pushAddress",
    "uniswapRouterAddress",
    "aaveLendingAddress",
    "referralCode",
  ]);
  console.log(
    chalk.bgWhite.bold.black(`\n\t\t\t\n Version Control Passed \n\t\t\t\n`)
  );

  // First deploy all contracts
  console.log(
    chalk.bgBlack.bold.green(
      `\n📡 Deploying Contracts \n-----------------------\n`
    )
  );
  const deployedContracts = await setupAllContracts(versionDetails);
  console.log(
    chalk.bgWhite.bold.black(`\n\t\t\t\n All Contracts Deployed \n\t\t\t\n`)
  );

  // Try to verify
  console.log(
    chalk.bgBlack.bold.green(
      `\n📡 Verifying Contracts \n-----------------------\n`
    )
  );
  await verifyAllContracts(deployedContracts, versionDetails);
  console.log(
    chalk.bgWhite.bold.black(`\n\t\t\t\n All Contracts Verified \n\t\t\t\n`)
  );

  // Upgrade Version
  console.log(
    chalk.bgBlack.bold.green(
      `\n📟 Upgrading Version   \n-----------------------\n`
    )
  );
  upgradeVersion();
  console.log(
    chalk.bgWhite.bold.black(`\n\t\t\t\n ✅ Version upgraded    \n\t\t\t\n`)
  );
}
async function setupAllContracts(versionDetails) {
  let deployedContracts = [];
  console.log("📡 Deploy \n");
  const [adminSigner, aliceSigner, bobSigner, eventualAdmin] =
    await ethers.getSigners();

  const EPNSCoreV1 = await deployContract("EPNSCoreV1", [], "EPNSCoreV1");
  deployedContracts.push(EPNSCoreV1);

  const EPNSCoreProxy = await deployContract(
    "EPNSCoreProxy",
    [
      EPNSCoreV1.address,
      adminSigner.address,
      adminSigner.address,
      versionDetails.deploy.args.pushAddress,
      versionDetails.deploy.args.wethAddress,
      versionDetails.deploy.args.uniswapRouterAddress,
      versionDetails.deploy.args.aaveLendingAddress,
      versionDetails.deploy.args.daiAddress,
      versionDetails.deploy.args.aDaiAddress,
      parseInt(versionDetails.deploy.args.referralCode),
    ],
    "EPNSCoreProxy"
  );

  deployedContracts.push(EPNSCoreProxy);

  return deployedContracts;
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
