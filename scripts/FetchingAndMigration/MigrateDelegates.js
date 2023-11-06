require("@nomiclabs/hardhat-ethers");
require("dotenv").config();
var fs = require("fs");
const fsPromises = fs.promises;
let data = require("../../Data/DevDelegateData.json");

const _channelAddress = data.channelAddress;
const _delegateAddress = data.delegateAddress;

const ABI_FILE_PATH_COMM =
  "artifacts/contracts/PushComm/PushCommV2_5.sol/PushCommV2_5.json";
const DEPLOYED_CONTRACT_ADDRESS = "0x88Fbd32053b4CDe8602668261736C3B3FfE5D683";

async function getAbi(file) {
  const data = await fsPromises.readFile(file, "utf8");
  const abi = JSON.parse(data)["abi"];
  return abi;
}

async function main() {
  let signer = await ethers.getSigners();
  const abi = await getAbi(ABI_FILE_PATH_COMM);
  let Comm = new ethers.Contract(DEPLOYED_CONTRACT_ADDRESS, abi, signer[0]);
  console.log("Migrating");
  let tx = await Comm.migrateDelegates(_channelAddress, _delegateAddress);
  // console.log(tx);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
