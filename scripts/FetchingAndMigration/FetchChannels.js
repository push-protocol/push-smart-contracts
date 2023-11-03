require("@nomiclabs/hardhat-ethers");
require("dotenv").config();
var fs = require("fs");
const fsPromises = fs.promises;

const ABI_FILE_PATH_CORE =
  "artifacts/contracts/PushCore/PushCoreV2_Temp.sol/PushCoreV2_Temp.json";

const core = "0x23346B732d56d34EC4e890419fBFB8548216a799";

async function getAbi(file) {
  const data = await fsPromises.readFile(file, "utf8");
  const abi = JSON.parse(data)["abi"];
  return abi;
}

BigInt.prototype.toJSON = function () {
  return this.toString();
};

async function main() {
  const abi = await getAbi(ABI_FILE_PATH_CORE);
  provider = await ethers.provider;
  let Core = new ethers.Contract(core, abi, provider);
  const name = await Core.name();
  console.log("fetching Add Channel events from", name);

  let channelAddress = [];
  let filteredArray = [];
  let eventFilter = Core.filters.AddChannel();
  let events = await Core.queryFilter(eventFilter);
  console.log(`Total ${events.length} events found `);

  for (let i = 0; i < events.length; i++) {
    let user = events[i].args[0];
    channelAddress.push(user);
  }
  channelAddress = channelAddress.sort();
  let checkDup;
  for (let i = 0; i < channelAddress.length; ++i) {
    if (channelAddress[i] == checkDup) {
      continue;
    } else {
      let channel = await Core.channels(channelAddress[i]);

      let state = channel[1];

      if (state != 1) {
        continue;
      } else {
      filteredArray.push(channelAddress[i]);
      checkDup = channelAddress[i];
    }
    }
  }
  console.log(filteredArray.length, "Unique addresses found");

  let _channelTypeList = [];
  let _identityList = [];
  let _amountList = [];
  let _channelExpiryTime = [];

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
    let _identity = events[0].args[2];
    _identityList.push(_identity);
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
    "./StagingData.json",
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
