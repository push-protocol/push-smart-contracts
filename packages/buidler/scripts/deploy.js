const fs = require("fs");
const chalk = require("chalk");
const { config, ethers } = require("@nomiclabs/buidler");

async function deploy(name, _args) {
  const args = _args || [];

  console.log(`📄 ${name}`);
  const contractArtifacts = await ethers.getContractFactory(name);
  const contract = await contractArtifacts.deploy(...args);
  console.log(
    chalk.cyan(name),
    "deployed to:",
    chalk.magenta(contract.address)
  );
  fs.writeFileSync(`artifacts/${name}.address`, contract.address);
  console.log("\n");
  return contract;
}

const isSolidity = (fileName) =>
  fileName.indexOf(".sol") >= 0 && fileName.indexOf(".swp.") < 0;

function readArgumentsFile(contractName) {
  let args = [];
  try {
    const argsFile = `./contracts/${contractName}.args`;
    if (fs.existsSync(argsFile)) {
      args = JSON.parse(fs.readFileSync(argsFile));
    }
  } catch (e) {
    console.log(e);
  }

  return args;
}

async function autoDeploy() {
  const contractList = fs.readdirSync(config.paths.sources);
  return contractList
    .filter((fileName) => isSolidity(fileName))
    .reduce((lastDeployment, fileName) => {
      const contractName = fileName.replace(".sol", "");
      const args = readArgumentsFile(contractName);

      // Wait for last deployment to complete before starting the next
      return lastDeployment.then((resultArrSoFar) =>
        deploy(contractName, args).then((result) => [...resultArrSoFar, result])
      );
    }, Promise.resolve([]));
}

async function main() {
  console.log("📡 Deploy \n");
  // auto deploy to read contract directory and deploy them all (add ".args" files for arguments)
  // await autoDeploy();
  // OR
  // custom deploy (to use deployed addresses dynamically for example:)
  const [adminSigner, aliceSigner, bobSigner] = await ethers.getSigners();

  const admin = await adminSigner.getAddress();
  // const admin = '0xA1bFBd2062f298a46f3E4160C89BEDa0716a3F51'; //admin of timelock, gets handed over to the governor.
  const AAVE_LENDING_POOL = "0x1c8756FD2B28e9426CDBDcC7E3c4d64fa9A54728";
  const DAI = "0xf80A32A835F79D7787E8a8ee5721D0fEaFd78108";
  const ADAI = "0xcB1Fe6F440c49E9290c3eb7f158534c2dC374201";
  const referralCode = 0;
  const delay = 0; // uint for the timelock delay

  // const epns = await deploy("EPNS");
  const core = await deploy("EPNSCore");

  // const timelock = await deploy("Timelock", [admin, delay]); // governor and a guardian,

  let logic = core.address;
  // let governance = timelock.address;
  let governance = '0x0a651cF7A9b60082fecdb5f30DB7914Fd7d2cf93';
  // const governorAlpha = await deploy("GovernorAlpha", [
  //   governance,
  //   epns.address,
  //   admin,
  // ]);

  // const currBlock = await ethers.provider.getBlock('latest');
  //
  // const eta = currBlock.timestamp;
  // const coder = new ethers.utils.AbiCoder();

  // let data = coder.encode(['address'], [governorAlpha.address]);

  // await timelock.functions.queueTransaction(timelock.address, '0', 'setPendingAdmin(address)', data, (eta + 1));
  // await ethers.provider.send('evm_mine');
  // await ethers.provider.send('evm_mine');
  // await timelock.functions.executeTransaction(timelock.address, '0', 'setPendingAdmin(address)', data, (eta + 1));

  const coreProxy = await deploy("EPNSProxy", [
    logic,
    governance,
    AAVE_LENDING_POOL,
    DAI,
    ADAI,
    referralCode,
    {gasLimit: 8000000}
  ]);

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
