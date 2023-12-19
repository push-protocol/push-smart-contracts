const fs = require("fs");
const chalk = require("chalk");
const { config, ethers } = require("hardhat");
const {
  versionVerifier,
  upgradeVersion,
} = require("../loaders/versionVerifier");

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

async function main() {
  // Version Check
  console.log(
    chalk.bgBlack.bold.green(
      `\n✌️  Running Version Checks \n-----------------------\n`
    )
  );
  const versionDetails = versionVerifier(["chainName"]);
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

  const EPNSCommV1 = await deployContract("EPNSCommV1", [], "EPNSCommV1");
  deployedContracts.push(EPNSCommV1);

  const EPNSCommProxy = await deployContract(
    "EPNSCommProxy",
    [
      EPNSCommV1.address,
      adminSigner.address,
      adminSigner.address,
      versionDetails.deploy.args.chainName,
    ],
    "EPNSCommProxy"
  );

  deployedContracts.push(EPNSCommProxy);

  return deployedContracts;
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
