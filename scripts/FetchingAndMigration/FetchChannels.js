require("@nomiclabs/hardhat-ethers");
require("dotenv").config();
var fs = require("fs");
const { FetchChannels } = require("./EventFetching.js");
const fsPromises = fs.promises;
const ABI_FILE_PATH_CORE =
  "artifacts/contracts/PushCore/PushCoreV2_Temp.sol/PushCoreV2_Temp.json";

const Address = "0x23346B732d56d34EC4e890419fBFB8548216a799";

BigInt.prototype.toJSON = function () {
  return this.toString();
};
async function getAbi(file) {
  const data = await fsPromises.readFile(file, "utf8");
  const abi = JSON.parse(data)["abi"];
  return abi;
}
async function main() {
  const abi = await getAbi(ABI_FILE_PATH_CORE);
  provider = await ethers.provider;
  let Core = new ethers.Contract(Address, abi, provider);

  let filteredArray = await FetchChannels();
  let _channelTypeList = [];
  let _identityList = [];
  let _amountList = [];
  let _channelExpiryTime = [];
  let _updatedChannels = [];
  let _filteredUpdatedChannels = [];
  let _updateCounter = [];
  let _newIdentity = [];
  console.log(filteredArray);

  console.log("Fetching Channel Type and expiry time");

  for (let i = 0; i < filteredArray.length; i++) {
    let Channel = await Core.channels(filteredArray[i]);
    _channelTypeList.push(Channel[0]);
    _channelExpiryTime.push(parseInt(Channel[10]).toString());
  }

  console.log("fetching Identity");

  for (let i = 0; i < filteredArray.length; i++) {
    let eventFilter = Core.filters.AddChannel(filteredArray[i]);
    let events = await Core.queryFilter(eventFilter);
    let latest;
    for (let i = 0; i < events.length; i++) {
      latest = events[i];
      if (events[i].blockNumber > latest.blockNumber) {
        latest = events[i];
      }
    }
    _identityList.push(latest.args[2]);
    _amountList.push(parseInt(ethers.utils.parseEther("50")).toString());
  }

  console.log("Fetching Completed");

  let obj = {
    users: filteredArray,
    channelTypeList: _channelTypeList,
    identityList: _identityList,
    amountList: _amountList,
    channelExpiryTime: _channelExpiryTime,
  };
  fs.writeFileSync(
    "./Data/DevChannelData.json",
    JSON.stringify(obj),
    "utf-8",
    (err) => {
      console.log(err);
    }
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
