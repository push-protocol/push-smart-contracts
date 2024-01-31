require("@nomiclabs/hardhat-ethers");
require("dotenv").config();
const { BigNumber } = require("ethers");
var fs = require("fs");
var _ = require('lodash');

const fsPromises = fs.promises;

let OldData = require("../OldUsers.json");

const ABI_FILE_PATH_CORE =
  "artifacts/contracts/PushCore/PushCoreV2_Temp.sol/PushCoreV2_Temp.json";
const core = "0x9eb52339B52e71B1EFD5537947e75D23b3a7719B";
// const core = "0x66329Fdd4042928BfCAB60b179e1538D56eeeeeE";

const mappingSlot = 11;

async function getAbi(file) {
  const data = await fsPromises.readFile(file, "utf8");
  const abi = JSON.parse(data)["abi"];
  return abi;
}

async function getEpochToUserStakedWeight(user, epoch) {
  const userFessInfoSlotHash = ethers.utils.solidityKeccak256(
    ["uint256", "uint256"],
    [user, mappingSlot] // key, mapping slot
  );

  const eTUSWtMappingSlot = ethers.BigNumber.from(userFessInfoSlotHash)
    .add(4)
    .toHexString();

  const eTUSWtSlot = ethers.utils.solidityKeccak256(
    ["uint256", "uint256"],
    [epoch, eTUSWtMappingSlot] // key, mapping slot
  );
  return await provider.getStorageAt(core, eTUSWtSlot);
}

BigInt.prototype.toJSON = function () {
  return FetchHelper.toString();
};

const TILL_EPOCH = 4;
const FetchHelper = {
  getEpochsIdArr: (n) => Array.from({ length: n }, (_, i) => i + 1),

  fetchEpochToTotalStakedWeight: async () => {
    return await Promise.all(
      FetchHelper.getEpochsIdArr(TILL_EPOCH).map((el) =>
        EPNSCoreV1Proxy.epochToTotalStakedWeight(el)
      )
    ).then((res) => res.map((el) => el.toString()));
  },

  fetchEpochRewards: async () => {
    return await Promise.all(
      FetchHelper.getEpochsIdArr(TILL_EPOCH).map((el) =>
        EPNSCoreV1Proxy.epochRewards(el)
      )
    ).then((res) => res.map((el) => el.toString()));
  },

  fetchEpochInfo: async () => {
    const [_epochToTotalStakedWeight, _epochRewards] = await Promise.all([
      FetchHelper.fetchEpochToTotalStakedWeight(),
      FetchHelper.fetchEpochRewards(),
    ]);

    return { _epochToTotalStakedWeight, _epochRewards };
  },

  fetchUserFeesInfos: async (usersList) => {
    return await Promise.all(
      usersList.map((el) => EPNSCoreV1Proxy.userFeesInfo(el))
    );
  },

  fetchUserRewardsClaimed: async (usersList) => {
    return await Promise.all(
      usersList.map((el) => EPNSCoreV1Proxy.usersRewardsClaimed(el))
    );
  },

  fetchUserInfos: async (userList) => {
    const [userFeesInfos, userRewardsClaimed] = await Promise.all([
      FetchHelper.fetchUserFeesInfos(userList),
      FetchHelper.fetchUserRewardsClaimed(userList),
    ]);

    let _stakedAmount = [];
    let _stakedWeight = [];
    let _lastStakedBlock = [];
    let _lastClaimedBlock = [];
    let _userRewardsClaimed = [];

    for (let i = 0; i < userList.length; ++i) {
      let userFeeInfo = userFeesInfos[i];
      _stakedAmount.push(userFeeInfo.stakedAmount.toString());
      _stakedWeight.push(userFeeInfo.stakedWeight.toString());
      _lastStakedBlock.push(userFeeInfo.lastStakedBlock.toString());
      _lastClaimedBlock.push(userFeeInfo.lastClaimedBlock.toString());
      _userRewardsClaimed.push(userRewardsClaimed[i].toString());
    }

    return {
      _stakedAmount,
      _stakedWeight,
      _lastStakedBlock,
      _lastClaimedBlock,
      _userRewardsClaimed,
    };
  },

  getEpochToUserStakedWeight: async (users) => {
    const fetchEpochToUserStakedWeight = async (epochId, users) => {
      const epochToStakedWts = await Promise.all(
        users.map((user) => getEpochToUserStakedWeight(user, epochId))
      );
      return epochToStakedWts.map((el) => BigNumber.from(el).toString());
    };

    // const epochsArr = FetchHelper.getEpochsIdArr(TILL_EPOCH)
    // const stakedWts = await Promise.all(epochsArr.map(el => fetchEpochToUserStakedWeight(el, users)))
    const stakedWts = [];
    for (let i = 1; i < TILL_EPOCH + 1; i++) {
      stakedWts.push(await fetchEpochToUserStakedWeight(i, users));
    }

    let stakedWtsJSON = {};
    stakedWts.map((el, idx) => {
      stakedWtsJSON[`epochToUserStakedWeight${idx + 1}`] = el;
    });

    return stakedWtsJSON;
  },

  fetchAll: async (filteredArray) => {
    const [epochInfo, userInfo] = await Promise.all([
      FetchHelper.fetchEpochInfo(),
      FetchHelper.fetchUserInfos(filteredArray),
    ]);

    return {
      epochInfo,
      userInfo,
    };
  },
};

const getUserArray = async (contract) => {
  let userArray = [];
  let filteredArray = [];
  let eventFilter = contract.filters.Staked();
  let events = await contract.queryFilter(eventFilter);
  console.log(`Total ${events.length} events found `);
  for (let i = 0; i < events.length; i++) {
    let user = events[i].args[0];
    userArray.push(user);
  }
  userArray = userArray.sort();

  let checkDup;
  for (let i = 0; i < userArray.length; ++i) {
    if (userArray[i] == checkDup) {
      continue;
    } else {
      filteredArray.push(userArray[i]);
      checkDup = userArray[i];
    }
  }

  return filteredArray;
};

let EPNSCoreV1Proxy;

async function main() {
  const abi = await getAbi(ABI_FILE_PATH_CORE);
  provider = ethers.provider;
  EPNSCoreV1Proxy = new ethers.Contract(core, abi, provider);

  // Old contract
  const usersArray = await getUserArray(EPNSCoreV1Proxy);
  console.log(usersArray.length, "Unique addresses found");

  console.log("fetching user and epoch info");
  const { epochInfo, userInfo } = await FetchHelper.fetchAll(usersArray);

  const { _epochToTotalStakedWeight, _epochRewards } = epochInfo;
  const {
    _lastClaimedBlock,
    _lastStakedBlock,
    _stakedAmount,
    _stakedWeight,
    _userRewardsClaimed,
  } = userInfo;

  console.log("fetching st wt");
  const stakedWeightInfo = await FetchHelper.getEpochToUserStakedWeight(
    usersArray
  );

  let obj = {
    users: usersArray,
    epochToTotalStakedWeight: _epochToTotalStakedWeight,
    epochRewards: _epochRewards,
    stakedAmount: _stakedAmount,
    stakedWeight: _stakedWeight,
    lastStakedBlock: _lastStakedBlock,
    lastClaimedBlock: _lastClaimedBlock,
    userRewardsClaimed: _userRewardsClaimed,
    ...stakedWeightInfo,
  };

  fs.writeFileSync("./NewUsers.json", JSON.stringify(obj), "utf-8", (err) => {
    console.log(err);
  });
  let NewData = require("../NewUsers.json");
  console.log(_.isEqual(OldData, NewData));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
