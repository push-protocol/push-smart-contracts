require("@nomiclabs/hardhat-ethers");
require("dotenv").config();
var fs = require("fs");
const fsPromises = fs.promises;

const ABI_FILE_PATH_COMM =
  "artifacts/contracts/PushComm/PushCommV2_5.sol/PushCommV2_5.json";

const comm = "0xc064F30bac07e84500c97A04D21a9d1bfFC72Ec0";

async function getAbi(file) {
  const data = await fsPromises.readFile(file, "utf8");
  const abi = JSON.parse(data)["abi"];
  return abi;
}

BigInt.prototype.toJSON = function () {
  return this.toString();
};

async function main() {
  const abi = await getAbi(ABI_FILE_PATH_COMM);
  provider = await ethers.provider;
  let Comm = new ethers.Contract(comm, abi, provider);
  const name = await Comm.name();
  console.log("fetching Add Channel events from", name);

  let _channelAddress = [];
  let _delegateAddress = [];
  let eventFilter = Comm.filters.AddDelegate();
  let events = await Comm.queryFilter(eventFilter);
  console.log(`Total ${events.length} events found `);

  console.log("fetching delegates for channels");

  for (let i = 0; i < events.length; i++) {
    let channel = events[i].args[0];
    let delegate = events[i].args[1];
    let bool = await Comm.delegatedNotificationSenders(channel, delegate);
    if (bool) {
      _channelAddress.push(channel);
      _delegateAddress.push(delegate);
    }
  }

  let obj = {
    channelAddress: _channelAddress,
    delegateAddress: _delegateAddress,
  };
  fs.writeFileSync(
    "./Data/DevDelegateData.json",
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
