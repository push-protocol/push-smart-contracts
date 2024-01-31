require("@nomiclabs/hardhat-ethers");
require("dotenv").config();
var fs = require("fs");
const fsPromises = fs.promises;
let data = require("../OldUsers.json");
let start = 140;
let end = 165;

let _users;
let _stakedAmount;
let _stakedWeight;
let _lastStakedBlock;
let _lastClaimedBlock;

let _epochToUserStakedWeight1;

let _epochToUserStakedWeight2;

let _epochToUserStakedWeight3;

let _epochToUserStakedWeight4;
let _userRewardsClaimed;

let _epochToTotalStakedWeight = data.epochToTotalStakedWeight;

const _epochRewards = data.epochRewards;

const ABI_FILE_PATH_CORE =
  "artifacts/contracts/PushStaking/PushFeePoolStaking.sol/PushFeePoolStaking.json";
const DEPLOYED_CONTRACT_ADDRESS = "0x9eb52339B52e71B1EFD5537947e75D23b3a7719B";

async function getAbi(file) {
  const data = await fsPromises.readFile(file, "utf8");
  const abi = JSON.parse(data)["abi"];
  return abi;
}

async function sliceIt(start, end) {
  _users = data.users.slice(start, end);
  _stakedAmount = data.stakedAmount.slice(start, end);
  _stakedWeight = data.stakedWeight.slice(start, end);
  _lastStakedBlock = data.lastStakedBlock.slice(start, end);
  _lastClaimedBlock = data.lastClaimedBlock.slice(start, end);

  _epochToUserStakedWeight1 = data.epochToUserStakedWeight1.slice(start, end);
  _epochToUserStakedWeight2 = data.epochToUserStakedWeight2.slice(start, end);
  _epochToUserStakedWeight3 = data.epochToUserStakedWeight3.slice(start, end);
  _epochToUserStakedWeight4 = data.epochToUserStakedWeight4.slice(start, end);

  _userRewardsClaimed = data.userRewardsClaimed.slice(start, end);
}

async function main() {
  let signer = await ethers.getSigners();
  const abi = await getAbi(ABI_FILE_PATH_CORE);
  let PushFeePool = new ethers.Contract(
    DEPLOYED_CONTRACT_ADDRESS,
    abi,
    signer[0]
  );
  console.log("Migrating Epoch Details");
  await PushFeePool.migrateEpochDetails(
    4,
    _epochRewards,
    _epochToTotalStakedWeight
  );
  for (let i = 0; i < 2; i++) {
    await sliceIt(start, end);

    console.log("Migrating User Details");

    let tx = await PushFeePool.migrateUserData(
      0,
      _users.length,
      _users,
      _stakedAmount,
      _stakedWeight,
      _lastStakedBlock,
      _lastClaimedBlock
    );
    await tx.wait();
    console.log(tx.hash);

    console.log("Migrating User mappings for epoch 1");

    tx = await PushFeePool.migrateUserMappings(
      1,
      0,
      _users.length,
      _users,
      _epochToUserStakedWeight1,
      _userRewardsClaimed
    );
    await tx.wait();
    console.log(tx.hash);
    console.log("Migrating User mappings for epoch 2");

    await PushFeePool.migrateUserMappings(
      2,
      0,
      _users.length,
      _users,
      _epochToUserStakedWeight2,
      _userRewardsClaimed
    );
    console.log("Migrating User mappings for epoch 3");

    await PushFeePool.migrateUserMappings(
      3,
      0,
      _users.length,
      _users,
      _epochToUserStakedWeight3,
      _userRewardsClaimed
    );
    console.log("Migrating User mappings for epoch 4");

    await PushFeePool.migrateUserMappings(
      4,
      0,
      _users.length,
      _users,
      _epochToUserStakedWeight4,
      _userRewardsClaimed
    );

    start = end;
    end = start + 25;
  }

  // await PushFeePool.setMigrationComplete();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
