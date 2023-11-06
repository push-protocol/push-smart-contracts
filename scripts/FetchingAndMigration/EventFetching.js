require("@nomiclabs/hardhat-ethers");
require("dotenv").config();
var fs = require("fs");
const fsPromises = fs.promises;

const ABI_FILE_PATH_CORE =
  "artifacts/contracts/PushCore/PushCoreV2_Temp.sol/PushCoreV2_Temp.json";

const Address = "0x23346B732d56d34EC4e890419fBFB8548216a799";

async function getAbi(file) {
  const data = await fsPromises.readFile(file, "utf8");
  const abi = JSON.parse(data)["abi"];
  return abi;
}

async function FetchChannels() {
  const abi = await getAbi(ABI_FILE_PATH_CORE);
  provider = await ethers.provider;
  let Core = new ethers.Contract(Address, abi, provider);

  const name = await Core.name();
  console.log("fetching Add Channel events from", name);

  let channelAddress = [];
  let filteredArray = [];

  let eventFilter = Core.filters.AddChannel();
  let events = await Core.queryFilter(eventFilter);
  console.log(`Total ${events.length} Add events found `);

  for (let i = 0; i < events.length; i++) {
    let user = events[i].args[0];
    channelAddress.push(user);
  }
  channelAddress = channelAddress.sort();
  let checkDuplicate;
  for (let i = 0; i < channelAddress.length; ++i) {
    if (channelAddress[i] == checkDuplicate) {
      continue;
    } else {
      let channel = await Core.channels(channelAddress[i]);
      if (channel[1] != 1) {
        continue;
      } else {
        filteredArray.push(channelAddress[i]);
        checkDuplicate = channelAddress[i];
      }
    }
  }
  console.log(filteredArray.length, "Unique addresses found");

  return filteredArray;
}

async function fetchUpdatedChannels() {
  console.log("fetching update channel events");
  let Filter = Core.filters.UpdateChannel();
  let eventss = await Core.queryFilter(Filter);

  console.log(eventss);
  console.log(`Total ${eventss} update events found`);

  // for (let i = 0; i < updateEvents.length; i++) {
  //   let user = updateEvents[i].args[0];
  //   _updatedChannels.push(user);
  // }
  // _updatedChannels = _updatedChannels.sort();
  // let checkDup;
  // for (let i = 0; i < _updatedChannels.length; ++i) {
  //   if (_updatedChannels[i] == checkDup) {
  //     continue;
  //   } else {
  //     let channel = await Core.channels(_updatedChannels[i]);

  //     let state = channel[1];

  //     if (state != 1) {
  //       continue;
  //     } else {
  //       _filteredUpdatedChannels.push(_updatedChannels[i]);
  //       checkDup = _updatedChannels[i];
  //     }
  //   }
  // }
}

module.exports = {
  FetchChannels: FetchChannels,
  fetchUpdatedChannels: fetchUpdatedChannels,
};
