const { ethers, waffle } = require("hardhat");

const { tokensBN, bn } = require("../../helpers/utils");

const { epnsContractFixture, tokenFixture } = require("../common/fixturesV2");
const { expect } = require("../common/expect");
const { parseEther } = require("ethers/lib/utils");
const createFixtureLoader = waffle.createFixtureLoader;

const weiToEth = (eth) => ethers.utils.formatEther(eth);

describe("EPNS CoreV2 Protocol", function () {
  const ADD_CHANNEL_MIN_POOL_CONTRIBUTION = tokensBN(50);
  const ADD_CHANNEL_MAX_POOL_CONTRIBUTION = tokensBN(250000 * 50);
  const ADJUST_FOR_FLOAT = 10 ** 7;

  let PushToken;
  let EPNSCoreV1Proxy;
  let EPNSCommV1Proxy;
  let PushFeePoolV1Proxy;
  let ADMIN;
  let ALICE;
  let BOB;
  let CHARLIE;
  let CHANNEL_CREATOR;
  let ADMINSIGNER;
  let ALICESIGNER;
  let BOBSIGNER;
  let CHARLIESIGNER;
  let CHANNEL_CREATORSIGNER;

  let loadFixture;
  before(async () => {
    [wallet, other] = await ethers.getSigners();
    loadFixture = createFixtureLoader([wallet, other]);
  });

  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    const [
      adminSigner,
      aliceSigner,
      bobSigner,
      charlieSigner,
      channelCreatorSigner,
    ] = await ethers.getSigners();

    ADMINSIGNER = adminSigner;
    ALICESIGNER = aliceSigner;
    BOBSIGNER = bobSigner;
    CHARLIESIGNER = charlieSigner;
    CHANNEL_CREATORSIGNER = channelCreatorSigner;

    ADMIN = await adminSigner.getAddress();
    ALICE = await aliceSigner.getAddress();
    BOB = await bobSigner.getAddress();
    CHARLIE = await charlieSigner.getAddress();
    CHANNEL_CREATOR = await channelCreatorSigner.getAddress();

    ({
      PROXYADMIN,
      EPNSCoreV1Proxy,
      EPNSCommV1Proxy,
      PushFeePoolV1Proxy,
      ROUTER,
      PushToken,
    } = await loadFixture(epnsContractFixture));
  });

  describe("Stake and migration tests", () => {
    const CHANNEL_TYPE = 2;
    const EPOCH_DURATION = 21 * 7156;
    const TEST_CHANNEL_CTX = ethers.utils.toUtf8Bytes(
      "test-channel-hello-world"
    );

    beforeEach(async function () {
      /** INITIAL SET-UP **/
      await EPNSCoreV1Proxy.connect(ADMINSIGNER).setMinPoolContribution(
        ethers.utils.parseEther("1")
      );
      await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(
        EPNSCommV1Proxy.address
      );
      await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(
        EPNSCoreV1Proxy.address
      );

      /** PUSH Token Transfers **/
      await PushToken.transfer(
        BOB,
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000)
      );
      await PushToken.transfer(
        ALICE,
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000)
      );
      await PushToken.transfer(
        CHARLIE,
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000)
      );
      await PushToken.transfer(
        ADMIN,
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000)
      );
      await PushToken.transfer(
        CHANNEL_CREATOR,
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000)
      );

      await PushToken.connect(BOBSIGNER).approve(
        EPNSCoreV1Proxy.address,
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000)
      );
      await PushToken.connect(ADMINSIGNER).approve(
        EPNSCoreV1Proxy.address,
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000)
      );
      await PushToken.connect(ALICESIGNER).approve(
        EPNSCoreV1Proxy.address,
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000)
      );
      await PushToken.connect(CHARLIESIGNER).approve(
        EPNSCoreV1Proxy.address,
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000)
      );
      await PushToken.connect(CHANNEL_CREATORSIGNER).approve(
        EPNSCoreV1Proxy.address,
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000)
      );

      await PushToken.connect(BOBSIGNER).approve(
        PushFeePoolV1Proxy.address,
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000)
      );
      await PushToken.connect(ADMINSIGNER).approve(
        PushFeePoolV1Proxy.address,
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000)
      );
      await PushToken.connect(ALICESIGNER).approve(
        PushFeePoolV1Proxy.address,
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000)
      );
      await PushToken.connect(CHARLIESIGNER).approve(
        PushFeePoolV1Proxy.address,
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000)
      );
      await PushToken.connect(CHANNEL_CREATORSIGNER).approve(
        PushFeePoolV1Proxy.address,
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000)
      );

      await PushFeePoolV1Proxy.connect(ADMINSIGNER).initializeStake();

      //Holder Delegation for old contract

      await PushToken.connect(BOBSIGNER).setHolderDelegation(
        EPNSCoreV1Proxy.address,
        true
      );
      await PushToken.connect(ADMINSIGNER).setHolderDelegation(
        EPNSCoreV1Proxy.address,
        true
      );
      await PushToken.connect(ALICESIGNER).setHolderDelegation(
        EPNSCoreV1Proxy.address,
        true
      );
      await PushToken.connect(CHARLIESIGNER).setHolderDelegation(
        EPNSCoreV1Proxy.address,
        true
      );
      await PushToken.connect(CHANNEL_CREATORSIGNER).setHolderDelegation(
        EPNSCoreV1Proxy.address,
        true
      );

      //Holder Delegation for new contract
      await PushToken.connect(BOBSIGNER).setHolderDelegation(
        PushFeePoolV1Proxy.address,
        true
      );
      await PushToken.connect(ADMINSIGNER).setHolderDelegation(
        PushFeePoolV1Proxy.address,
        true
      );
      await PushToken.connect(ALICESIGNER).setHolderDelegation(
        PushFeePoolV1Proxy.address,
        true
      );
      await PushToken.connect(CHARLIESIGNER).setHolderDelegation(
        PushFeePoolV1Proxy.address,
        true
      );
      await PushToken.connect(CHANNEL_CREATORSIGNER).setHolderDelegation(
        PushFeePoolV1Proxy.address,
        true
      );
    });
    //*** Helper Functions - Related to Channel, Tokens and Stakes ***//
    const addPoolFees = async (signer, amount) => {
      await EPNSCoreV1Proxy.connect(signer).addPoolFees(tokensBN(amount));
    };

    const createChannel = async (signer) => {
      await EPNSCoreV1Proxy.connect(signer).createChannelWithPUSH(
        CHANNEL_TYPE,
        TEST_CHANNEL_CTX,
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION,
        0
      );
    };

    const stakeToNewContract = async (signer, amount) => {
      await PushFeePoolV1Proxy.connect(signer).stake(tokensBN(amount));
    };
    const stakeToOldContract = async (signer, amount) => {
      await EPNSCoreV1Proxy.connect(signer).stake(tokensBN(amount));
    };

    const stakeAtSingleBlock = async (stakeInfos) => {
      await ethers.provider.send("evm_setAutomine", [false]);
      await Promise.all(
        stakeInfos.map((stakeInfos) =>
          stakePushTokens(stakeInfos[0], stakeInfos[1])
        )
      );
      await network.provider.send("evm_mine");
      await ethers.provider.send("evm_setAutomine", [true]);
    };
    //*** Helper Functions - Related to Block numbers, Jump Blocks, Epochs and Rewards ***//

    const getCurrentBlock = async () => {
      const currentBlock = await ethers.provider.getBlock("latest");
      return currentBlock;
    };

    /** ⛔️ Not used currently - Prefer using passBlockNumbers **/
    const jumpToBlockNumber = async (blockNumber) => {
      blockNumber = blockNumber.toNumber();
      const currentBlock = await ethers.provider.getBlock("latest");
      const numBlockToIncrease = blockNumber - currentBlock.number;
      const blockIncreaseHex = `0x${numBlockToIncrease.toString(16)}`;
      await ethers.provider.send("hardhat_mine", [blockIncreaseHex]);
    };

    const passBlockNumers = async (blockNumber) => {
      blockNumber = `0x${blockNumber.toString(16)}`;
      await ethers.provider.send("hardhat_mine", [blockNumber]);
    };

    const claimRewardsInSingleBlock = async (signers) => {
      await ethers.provider.send("evm_setAutomine", [false]);
      await Promise.all(
        signers.map((signer) => PushFeePoolV1Proxy.connect(signer).harvestAll())
      );
      await network.provider.send("evm_mine");
      await ethers.provider.send("evm_setAutomine", [true]);
    };

    const getUserTokenWeight = async (user, amount, atBlock) => {
      const holderWeight = await PushToken.holderWeight(user);
      return amount.mul(atBlock - holderWeight);
    };

    const getRewardsClaimed = async (signers) => {
      return await Promise.all(
        signers.map((signer) => PushFeePoolV1Proxy.usersRewardsClaimed(signer))
      );
    };

    const getEachEpochDetails = async (user, totalEpochs) => {
      for (i = 0; i <= totalEpochs; i++) {
        var epochToTotalWeight =
          await PushFeePoolV1Proxy.epochToTotalStakedWeight(i);
        var epochRewardsStored = await PushFeePoolV1Proxy.epochRewards(i);
        const userEpochToStakedWeight =
          await PushFeePoolV1Proxy.getUserEpochToWeight(user, i);

        console.log("\n EACH EPOCH DETAILS ");
        console.log(`EPOCH Rewards for EPOCH ID ${i} is ${epochRewardsStored}`);
        console.log(
          `EPOCH to Total Weight for EPOCH ID ${i} is ${epochToTotalWeight}`
        );
        console.log(
          `userEpochToStakedWeight for EPOCH ID ${i} is ${userEpochToStakedWeight}`
        );
      }
    };

    const getCurrentEpochInOld = async () => {
      const genesisBlock = await EPNSCoreV1Proxy.genesisEpoch();
      const currentBlock = await getCurrentBlock();

      const currentEpochNumber = await EPNSCoreV1Proxy.lastEpochRelative(
        genesisBlock,
        currentBlock.number
      );

      return currentEpochNumber;
    };
    const getCurrentEpochInNew = async () => {
      const genesisBlock = await PushFeePoolV1Proxy.genesisEpoch();
      const currentBlock = await getCurrentBlock();

      const currentEpochNumber = await PushFeePoolV1Proxy.lastEpochRelative(
        genesisBlock,
        currentBlock.number
      );

      return currentEpochNumber;
    };

    const getAdminRewards = async () => {
      const rewards_admin = await PushFeePoolV1Proxy.usersRewardsClaimed(
        EPNSCoreV1Proxy.address
      );

      return rewards_admin;
    };
    describe("🟢 Migrating Tests ", function () {
      let bobreward;
      let alicereward;
      let charliereward;

      beforeEach(async function () {
        addPoolFees(ADMINSIGNER, 10000);
        await stakeToOldContract(BOBSIGNER, 100);
        await stakeToOldContract(ALICESIGNER, 100);
        await stakeToOldContract(CHARLIESIGNER, 100);
        passBlockNumers(1 * EPOCH_DURATION);
        addPoolFees(ADMINSIGNER, 20000);
        await stakeToOldContract(BOBSIGNER, 300);
        await stakeToOldContract(ALICESIGNER, 700);
        await stakeToOldContract(CHARLIESIGNER, 800);
        passBlockNumers(2 * EPOCH_DURATION);
        addPoolFees(ADMINSIGNER, 30000);
        await stakeToOldContract(BOBSIGNER, 100);
        await stakeToOldContract(ALICESIGNER, 300);
        await stakeToOldContract(CHARLIESIGNER, 800);

        let _epochToTotalStakedWeight = [];
        let _epochRewards = [];
        let _users = [BOB, CHARLIE, ALICE];
        let _stakedAmount = [];
        let _stakedWeight = [];
        let _lastStakedBlock = [];
        let _lastClaimedBlock = [];
        let _epochToUserStakedWeight1 = [];
        let _epochToUserStakedWeight2 = [];
        let _epochToUserStakedWeight3 = [];
        let _epochToUserStakedWeight4 = [];
        let _userRewardsClaimed = [];

        for (let i = 1; i <= 4; ++i) {
          _epochToTotalStakedWeight.push(
            BigInt(await EPNSCoreV1Proxy.epochToTotalStakedWeight(i))
          );
        }

        for (let i = 1; i < 5; ++i) {
          _epochRewards.push(
            BigInt(parseInt(await EPNSCoreV1Proxy.epochRewards(i)))
          );
        }

        for (let i = 0; i < 3; ++i) {
          let userFeeInfo = await EPNSCoreV1Proxy.userFeesInfo(_users[i]);
          _stakedAmount.push(BigInt(userFeeInfo.stakedAmount));
          _stakedWeight.push(BigInt(userFeeInfo.stakedWeight));
          _lastStakedBlock.push(BigInt(userFeeInfo.lastStakedBlock));
          _lastClaimedBlock.push(
            BigInt(parseInt(userFeeInfo.lastClaimedBlock))
          );
          _userRewardsClaimed.push(
            await EPNSCoreV1Proxy.usersRewardsClaimed(_users[i])
          );
        }

        for (let i = 0; i < _users.length; ++i) {
          _epochToUserStakedWeight1.push(
            EPNSCoreV1Proxy.getEpochToUserStakedWeight(_users[i], 1)
          );
        }
        for (let i = 0; i < _users.length; ++i) {
          _epochToUserStakedWeight2.push(
            EPNSCoreV1Proxy.getEpochToUserStakedWeight(_users[i], 2)
          );
        }
        for (let i = 0; i < _users.length; ++i) {
          _epochToUserStakedWeight3.push(
            EPNSCoreV1Proxy.getEpochToUserStakedWeight(_users[i], 3)
          );
        }
        for (let i = 0; i < _users.length; ++i) {
          _epochToUserStakedWeight4.push(
            EPNSCoreV1Proxy.getEpochToUserStakedWeight(_users[i], 4)
          );
        }

        await PushFeePoolV1Proxy.migrateEpochDetails(
          4,
          _epochRewards,
          _epochToTotalStakedWeight
        );
        await PushFeePoolV1Proxy.migrateUserData(
          _users,
          _stakedAmount,
          _stakedWeight,
          _lastStakedBlock,
          _lastClaimedBlock
        );

        await PushFeePoolV1Proxy.migrateUserMappings(
          1,
          _users,
          _epochToUserStakedWeight1,
          _userRewardsClaimed
        );
        await PushFeePoolV1Proxy.migrateUserMappings(
          2,
          _users,
          _epochToUserStakedWeight2,
          _userRewardsClaimed
        );
        await PushFeePoolV1Proxy.migrateUserMappings(
          3,
          _users,
          _epochToUserStakedWeight3,
          _userRewardsClaimed
        );
        await PushFeePoolV1Proxy.migrateUserMappings(
          4,
          _users,
          _epochToUserStakedWeight4,
          _userRewardsClaimed
        );

        console.log("Succesfully migrated");
      });

      it("user mappings should be set correctly", async () => {
        let _users = [BOB, CHARLIE, ALICE];

        for (let i = 0; i < 3; ++i) {
          expect(
            await EPNSCoreV1Proxy.getEpochToUserStakedWeight(_users[i], i + 1)
          ).to.be.equal(
            await PushFeePoolV1Proxy.getEpochToUserStakedWeight(
              _users[i],
              i + 1
            )
          );
        }
      });
      it("user fees info should be set correctly", async () => {
        let _users = [ALICE, CHARLIE, BOB];

        for (let i = 0; i < 3; ++i) {
          let info1 = await EPNSCoreV1Proxy.userFeesInfo(_users[i]);
          let info2 = await PushFeePoolV1Proxy.userFeesInfo(_users[i]);
          expect(info1.stakedAmount).to.be.equal(info2.stakedAmount);
          expect(info1.stakedWeight).to.be.equal(info2.stakedWeight);
          expect(info1.lastClaimedBlock).to.be.equal(info2.lastClaimedBlock);
          expect(info1.lastStakedBlock).to.be.equal(info2.lastStakedBlock);
        }
      });
      it("epoch details should be set correctly", async () => {
        for (let i = 1; i < 5; ++i) {
          expect(await EPNSCoreV1Proxy.epochRewards(i)).to.be.equal(
            await PushFeePoolV1Proxy.epochRewards(i)
          );
          expect(await EPNSCoreV1Proxy.epochToTotalStakedWeight(i)).to.be.equal(
            await PushFeePoolV1Proxy.epochToTotalStakedWeight(i)
          );
        }
      });
      it("Harvesting works in old contract", async () => {
        console.log(await PushToken.balanceOf(EPNSCoreV1Proxy.address));

        await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAll();

        await EPNSCoreV1Proxy.connect(CHARLIESIGNER).harvestAll();
        await EPNSCoreV1Proxy.connect(ALICESIGNER).harvestAll();
        bobreward = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
        alicereward = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
        charliereward = await EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE);
      });

      it(" users can harvest from new contract", async () => {
        for (let i = 1; i < 5; ++i) {
          expect(
            await EPNSCoreV1Proxy.calculateEpochRewards(BOB, i)
          ).to.be.equal(await PushFeePoolV1Proxy.calculateEpochRewards(BOB, i));

          expect(
            await EPNSCoreV1Proxy.calculateEpochRewards(ALICE, i)
          ).to.be.equal(
            await PushFeePoolV1Proxy.calculateEpochRewards(ALICE, i)
          );

          expect(
            await EPNSCoreV1Proxy.calculateEpochRewards(CHARLIE, i)
          ).to.be.equal(
            await PushFeePoolV1Proxy.calculateEpochRewards(CHARLIE, i)
          );
        }
        console.log(await PushToken.balanceOf(EPNSCoreV1Proxy.address));
        await PushFeePoolV1Proxy.connect(BOBSIGNER).harvestAll();

        await PushFeePoolV1Proxy.connect(ALICESIGNER).harvestAll();

        await PushFeePoolV1Proxy.connect(CHARLIESIGNER).harvestAll();

        rewardbob = await PushFeePoolV1Proxy.usersRewardsClaimed(BOB);
        rewardalice = await PushFeePoolV1Proxy.usersRewardsClaimed(ALICE);
        rewardcharlie = await PushFeePoolV1Proxy.usersRewardsClaimed(CHARLIE);
        console.log(bobreward, rewardbob);
        console.log(alicereward, rewardalice);
        console.log(charliereward, rewardcharlie);
        // expect(rewardbob).to.be.equal(bobreward);
        // expect(rewardalice).to.be.equal(alicereward);
        // expect(rewardcharlie).to.be.equal(charliereward);
      });

      it("users can unstake from new contract", async () => {
        passBlockNumers(1 * EPOCH_DURATION);

        await PushFeePoolV1Proxy.connect(BOBSIGNER).unstake();

        await PushFeePoolV1Proxy.connect(ALICESIGNER).unstake();

        await PushFeePoolV1Proxy.connect(CHARLIESIGNER).unstake();
      });
    });
  });
});
