require("@nomiclabs/hardhat-ethers");
require("dotenv").config();
var fs = require("fs");
const fsPromises = fs.promises;
let data = require("../../Data/DevChannelData.json");
let _startIndex = 100;
let _endIndex = 101;

const _users = data.users;
const _channelExpiryTime = data.channelExpiryTime;
const _amountList = data.amountList;
const _identityList = data.identityList;
const _channelTypeList = data.channelTypeList;
console.log(_users.length);
const ABI_FILE_PATH_CORE =
  "artifacts/contracts/PushCore/PushCoreV2_Temp.sol/PushCoreV2_Temp.json";
const DEPLOYED_CONTRACT_ADDRESS = "0x2dFC2A866eac363cAFF516b5ce7aCd6bae1F21C1";

async function getAbi(file) {
  const data = await fsPromises.readFile(file, "utf8");
  const abi = JSON.parse(data)["abi"];
  return abi;
}

async function main() {
  let signer = await ethers.getSigners();
  const abi = await getAbi(ABI_FILE_PATH_CORE);
  let Core = new ethers.Contract(DEPLOYED_CONTRACT_ADDRESS, abi, signer[0]);
  console.log("Migrating to", await Core.name());
  let tx = await Core.migrateChannelData(
    _startIndex,
    _endIndex,
    _users,
    _channelTypeList,
    _identityList,
    _amountList,
    _channelExpiryTime
  );
  // console.log(tx.hash);

  // await Core.setMigrationComplete();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
