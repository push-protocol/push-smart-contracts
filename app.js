const chalk = require('chalk');

async function startSetup() {
  const envVerifierLoader = require('./loaders/envVerifier');
  await envVerifierLoader(false);
  console.log(chalk.bgWhite.black('✔️   Setup Completed!'));
  console.log(chalk.bgBlue.white(`Let's npx hardhat and #BUIDL`));
}

startSetup();
