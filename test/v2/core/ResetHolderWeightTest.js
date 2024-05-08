const { ethers, waffle } = require("hardhat");

const { tokensBN, bn } = require("../../../helpers/utils");

const { epnsContractFixture, tokenFixture } = require("../../common/fixturesV2");
const { expect } = require("../../common/expect");
const { parseEther } = require("ethers/lib/utils");
const { assert } = require("chai");
const createFixtureLoader = waffle.createFixtureLoader;

const weiToEth = (eth) => ethers.utils.formatEther(eth);

describe("EPNS CoreV2 Protocol", function () {
  const ADD_CHANNEL_MIN_POOL_CONTRIBUTION = tokensBN(50);
  const ADD_CHANNEL_MAX_POOL_CONTRIBUTION = tokensBN(250000 * 50);
  const ADJUST_FOR_FLOAT = 10 ** 7;

  let PushToken;
  let EPNSCoreV1Proxy;
  let EPNSCommV1Proxy;
  let ADMIN;
  let ALICE;
  let BOB;
  let CHARLIE;
  let CHANNEL_CREATOR;
  let NEW_USER_ONE;
  let NEW_USER_TWO;
  let NEW_USER_THREE;
  let ADMINSIGNER;
  let ALICESIGNER;
  let BOBSIGNER;
  let CHARLIESIGNER;
  let CHANNEL_CREATORSIGNER;
  let NEW_USER_ONE_SIGNER;
  let NEW_USER_TWO_SIGNER;
  let NEW_USER_THREE_SIGNER;

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
      newUserOneSigner,
        newUserTwoSigner,
        newUserThreeSigner,
    ] = await ethers.getSigners();

    ADMINSIGNER = adminSigner;
    ALICESIGNER = aliceSigner;
    BOBSIGNER = bobSigner;
    CHARLIESIGNER = charlieSigner;
    CHANNEL_CREATORSIGNER = channelCreatorSigner;
    NEW_USER_ONE_SIGNER = newUserOneSigner;
    NEW_USER_TWO_SIGNER = newUserTwoSigner;
    NEW_USER_THREE_SIGNER = newUserThreeSigner;

    ADMIN = await adminSigner.getAddress();
    ALICE = await aliceSigner.getAddress();
    BOB = await bobSigner.getAddress();
    CHARLIE = await charlieSigner.getAddress();
    CHANNEL_CREATOR = await channelCreatorSigner.getAddress();
    NEW_USER_ONE = await newUserOneSigner.getAddress();
    NEW_USER_TWO = await newUserTwoSigner.getAddress();
    NEW_USER_THREE = await newUserThreeSigner.getAddress();

    ({ PROXYADMIN, EPNSCoreV1Proxy, EPNSCommV1Proxy, ROUTER, PushToken } =
      await loadFixture(epnsContractFixture));
  });

  describe("EPNS CORE V2: Stake and Claim Tests", () => {
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
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(1000)
      );
      await PushToken.transfer(
        ALICE,
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(1000)
      );
      await PushToken.transfer(
        CHARLIE,
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(1000)
      );
      await PushToken.transfer(
        ADMIN,
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(1000)
      );
      await PushToken.transfer(
        CHANNEL_CREATOR,
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(1000)
      );
      await PushToken.transfer(
        NEW_USER_ONE,
        tokensBN(1000)
        );
        await PushToken.transfer(
        NEW_USER_TWO,
        tokensBN(1000)
        );
        await PushToken.transfer(
        NEW_USER_THREE,
        tokensBN(1000)
        );

      await PushToken.connect(BOBSIGNER).approve(
        EPNSCoreV1Proxy.address,
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(1000)
      );
      await PushToken.connect(ADMINSIGNER).approve(
        EPNSCoreV1Proxy.address,
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(1000)
      );
      await PushToken.connect(ALICESIGNER).approve(
        EPNSCoreV1Proxy.address,
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(1000)
      );
      await PushToken.connect(CHARLIESIGNER).approve(
        EPNSCoreV1Proxy.address,
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(1000)
      );
      await PushToken.connect(CHANNEL_CREATORSIGNER).approve(
        EPNSCoreV1Proxy.address,
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(1000)
      );
        await PushToken.connect(NEW_USER_ONE_SIGNER).approve(
        EPNSCoreV1Proxy.address,
        tokensBN(5000)
        );
        await PushToken.connect(NEW_USER_TWO_SIGNER).approve(
        EPNSCoreV1Proxy.address,
        tokensBN(5000)
        );
        await PushToken.connect(NEW_USER_THREE_SIGNER).approve(
        EPNSCoreV1Proxy.address,
        tokensBN(5000)
        );  

      await EPNSCoreV1Proxy.connect(ADMINSIGNER).initializeStake();

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
        await PushToken.connect(NEW_USER_ONE_SIGNER).setHolderDelegation(
            EPNSCoreV1Proxy.address,
            true
        );
        await PushToken.connect(NEW_USER_TWO_SIGNER).setHolderDelegation(
            EPNSCoreV1Proxy.address,
            true
        );
        await PushToken.connect(NEW_USER_THREE_SIGNER).setHolderDelegation(
            EPNSCoreV1Proxy.address,
            true
        );
    });
    //*** Helper Functions - Related to Channel, Tokens and Stakes ***//
    const addPoolFees = async (signer, amount) => {
      await createChannel(signer);
      await EPNSCoreV1Proxy.connect(signer).updateChannelMeta(
        signer.address,
        "0x00",
        amount.sub(10)
      );
    };

    const createChannel = async (signer) => {
      await EPNSCoreV1Proxy.connect(signer).createChannelWithPUSH(
        CHANNEL_TYPE,
        TEST_CHANNEL_CTX,
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION,
        0
      );
    };

    const stakePushTokens = async (signer, amount) => {
      await EPNSCoreV1Proxy.connect(signer).stake(amount);
    };

    const getLastStakedEpoch = async (user) => {
      const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
      var userDetails = await EPNSCoreV1Proxy.userFeesInfo(user);

      const lastStakedEpoch = await EPNSCoreV1Proxy.lastEpochRelative(
        genesisEpoch.toNumber(),
        userDetails.lastStakedBlock.toNumber()
      );
      return lastStakedEpoch;
    };

    const getLastRewardClaimedEpoch = async (user) => {
      const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
      var userDetails = await EPNSCoreV1Proxy.userFeesInfo(user);

      const lastClaimedEpoch = await EPNSCoreV1Proxy.lastEpochRelative(
        genesisEpoch.toNumber(),
        userDetails.lastClaimedBlock.toNumber()
      );
      return lastClaimedEpoch;
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
        signers.map((signer) => EPNSCoreV1Proxy.connect(signer).harvestAll())
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
        signers.map((signer) => EPNSCoreV1Proxy.usersRewardsClaimed(signer))
      );
    };

    const getEachEpochDetails = async (user, totalEpochs) => {
      for (i = 0; i <= totalEpochs; i++) {
        var epochToTotalWeight = await EPNSCoreV1Proxy.epochToTotalStakedWeight(
          i
        );
        var epochRewardsStored = await EPNSCoreV1Proxy.epochRewards(i);
        const userEpochToStakedWeight =
          await EPNSCoreV1Proxy.getUserEpochToStakeWeight(user, i);

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

    const getCurrentEpoch = async () => {
      const genesisBlock = await EPNSCoreV1Proxy.genesisEpoch()
      const currentBlock = await getCurrentBlock();

      const currentEpochNumber = await EPNSCoreV1Proxy.lastEpochRelative(
        genesisBlock,
        currentBlock.number
      );

      return currentEpochNumber;
    }

    const getAdminRewards = async () => {
      const rewards_admin = await EPNSCoreV1Proxy.usersRewardsClaimed(
        EPNSCoreV1Proxy.address
      );

      return rewards_admin;
    }

    /** Test Cases Starts Here **/
    describe("🟢 Stake Tests ", function () {


    describe("🟢 RESTAKE ISSUE TEST ", function () {

    describe("🟢 1. Current HarvestAll() function TEST ", function () {

        it("Option 1.1 : Current Harvest Function - ( with Non-ZERO Push in Wallet ) + Restake", async function () {
            await passBlockNumers(1 * EPOCH_DURATION);
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(3000));
            
            await stakePushTokens(BOBSIGNER, tokensBN(1000));
            await stakePushTokens(ALICESIGNER, tokensBN(1000));
            await stakePushTokens(CHARLIESIGNER, tokensBN(1000));

            // Get Staked Weight for all 3
            
            await passBlockNumers(10 * EPOCH_DURATION);

            await EPNSCoreV1Proxy.connect(ALICESIGNER).harvestAll();
            await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAll();
            await EPNSCoreV1Proxy.connect(CHARLIESIGNER).harvestAll();

            const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
            const rewards_alice = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
            const rewards_charlie = await EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE);

            // Check that rewards for all stakers are close to each other - ~986 PUSH
            expect(rewards_bob).to.be.closeTo(rewards_alice, 1000);
            expect(rewards_alice).to.be.closeTo(rewards_charlie, 1000);
            expect(rewards_bob).to.be.closeTo(rewards_charlie, 1000);

            console.log("\n######## STAKED Weight and Holder Weights after First Harvest ########\n");

            const coreContractHolderWeight = await PushToken.holderWeight(EPNSCoreV1Proxy.address);
            console.log("Core Contract Holder Weight: ", coreContractHolderWeight.toString());

            const bobStakedWeight = await EPNSCoreV1Proxy.getUserStakeWeight(BOB);
            const aliceStakedWeight = await EPNSCoreV1Proxy.getUserStakeWeight(ALICE);
            const charlieStakedWeight = await EPNSCoreV1Proxy.getUserStakeWeight(CHARLIE);

            const bobHolderWeigt = await PushToken.holderWeight(BOB);
            const aliceHolderWeigt = await PushToken.holderWeight(ALICE);
            const charlieHolderWeigt = await PushToken.holderWeight(CHARLIE);

            console.log("Bob Staked Weight: ", bobStakedWeight.toString());
            console.log("Alice Staked Weight: ", aliceStakedWeight.toString());
            console.log("Charlie Staked Weight: ", charlieStakedWeight.toString());

            console.log("Bob Holder Weight: ", bobHolderWeigt.toString());
            console.log("Alice Holder Weight: ", aliceHolderWeigt.toString());
            console.log("Charlie Holder Weight: ", charlieHolderWeigt.toString());

            console.log("\n######## REWARDS of Staker after First HAREVST ########");

            console.log("Rewards of all Stakers close to 986 PUSH\n");

            // Alice tries to restake using 1000 more tokens
            await passBlockNumers(100);
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(3000));

            await stakePushTokens(ALICESIGNER, tokensBN(1000));

            // 10 more epochs passes
            await passBlockNumers(10 * EPOCH_DURATION);

            await EPNSCoreV1Proxy.connect(ALICESIGNER).harvestAll();
            await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAll();
            await EPNSCoreV1Proxy.connect(CHARLIESIGNER).harvestAll();

            const rewards_alice_2ndHarvest = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
            const rewards_bob_2ndHarvest = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
            const rewards_charlie_2ndHarvest = await EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE);

            console.log("\n######## STAKED Weight and Holder Weights after 2nd Harvest + 1 RESTAKE ########\n");

            const coreContractHolderWeight2nd = await EPNSCoreV1Proxy.getUserStakeWeight(EPNSCoreV1Proxy.address);
            console.log("Core Contract Holder Weight: ", coreContractHolderWeight2nd.toString());

            const bobStakedWeight2nd = await EPNSCoreV1Proxy.getUserStakeWeight(BOB);
            const aliceStakedWeight2nd = await EPNSCoreV1Proxy.getUserStakeWeight(ALICE);
            const charlieStakedWeight2nd = await EPNSCoreV1Proxy.getUserStakeWeight(CHARLIE);

            const bobHolderWeight2nd = await PushToken.holderWeight(BOB);
            const aliceHolderWeight2nd = await PushToken.holderWeight(ALICE);
            const charlieHolderWeight2nd = await PushToken.holderWeight(CHARLIE);

            console.log("Bob Staked Weight: ", bobStakedWeight2nd.toString());
            console.log("Alice Staked Weight: ", aliceStakedWeight2nd.toString());
            console.log("Charlie Staked Weight: ", charlieStakedWeight2nd.toString());

            console.log("Bob Holder Weight: ", bobHolderWeight2nd.toString());
            console.log("Alice Holder Weight: ", aliceHolderWeight2nd.toString());
            console.log("Charlie Holder Weight: ", charlieHolderWeight2nd.toString());

            console.log("\n######## REWARDS of Staker after 2nd HAREVST + 1 Restake  ########\n");

            console.log("Alice Rewards after 2nd Harvest: ", rewards_alice_2ndHarvest.toString());
            console.log("Bob Rewards after 2nd Harvest: ", rewards_bob_2ndHarvest.toString());
            console.log("Charlie Rewards after 2nd Harvest: ", rewards_charlie_2ndHarvest.toString());
            // Console log total rewards in 2nd Harvest specifically
            console.log("Alice Rewards in 2nd Harvest: ", rewards_alice_2ndHarvest.sub(rewards_alice).toString());
            console.log("Bob Rewards in 2nd Harvest: ", rewards_bob_2ndHarvest.sub(rewards_bob).toString());
            console.log("Charlie Rewards in 2nd Harvest: ", rewards_charlie_2ndHarvest.sub(rewards_charlie).toString());

            // Basic Test Assertions
            // Alice's final reward should be more than BOB and Charlie
            expect(rewards_alice_2ndHarvest).to.be.gt(rewards_bob_2ndHarvest);
            expect(rewards_alice_2ndHarvest).to.be.gt(rewards_charlie_2ndHarvest);
            // Bob and Charlie should have similar or closeTo rewards 
            expect(rewards_bob_2ndHarvest).to.be.closeTo(rewards_charlie_2ndHarvest, 1000);
            

        })

        it("Option 1.2 : Current Harvest Function - ( with ZERO Push in Wallet ) + Restake", async function () {
            await passBlockNumers(1 * EPOCH_DURATION);
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(3000));

            await stakePushTokens(NEW_USER_ONE_SIGNER, tokensBN(1000));
            await stakePushTokens(NEW_USER_TWO_SIGNER, tokensBN(1000));
            await stakePushTokens(NEW_USER_THREE_SIGNER, tokensBN(1000));

            // Ensure that after staking balance of all user is ZERO
            expect(await PushToken.balanceOf(NEW_USER_ONE)).to.be.equal(tokensBN(0));
            expect(await PushToken.balanceOf(NEW_USER_TWO)).to.be.equal(tokensBN(0));
            expect(await PushToken.balanceOf(NEW_USER_THREE)).to.be.equal(tokensBN(0));

            // Get Staked Weight for all 3
            
            await passBlockNumers(10 * EPOCH_DURATION);

            await EPNSCoreV1Proxy.connect(NEW_USER_ONE_SIGNER).harvestAll();
            await EPNSCoreV1Proxy.connect(NEW_USER_TWO_SIGNER).harvestAll();
            await EPNSCoreV1Proxy.connect(NEW_USER_THREE_SIGNER).harvestAll();

            const rewards_new_user_one = await EPNSCoreV1Proxy.usersRewardsClaimed(NEW_USER_ONE);
            const rewards_new_user_two = await EPNSCoreV1Proxy.usersRewardsClaimed(NEW_USER_TWO);
            const rewards_new_user_three = await EPNSCoreV1Proxy.usersRewardsClaimed(NEW_USER_THREE);

            // Check that rewards for all stakers are close to each other - ~986 PUSH
            expect(rewards_new_user_one).to.be.closeTo(rewards_new_user_two, 1000);
            expect(rewards_new_user_two).to.be.closeTo(rewards_new_user_three, 1000);
            expect(rewards_new_user_one).to.be.closeTo(rewards_new_user_three, 1000);

            console.log("\n######## STAKED Weight and Holder Weights after First Harvest ########\n");

            const coreContractHolderWeight = await PushToken.holderWeight(EPNSCoreV1Proxy.address);
            console.log("Core Contract Holder Weight: ", coreContractHolderWeight.toString());

            const new_user_one_staked_weight = await EPNSCoreV1Proxy.getUserStakeWeight(NEW_USER_ONE);
            const new_user_two_staked_weight = await EPNSCoreV1Proxy.getUserStakeWeight(NEW_USER_TWO);
            const new_user_three_staked_weight = await EPNSCoreV1Proxy.getUserStakeWeight(NEW_USER_THREE);

            const new_user_one_holder_weight = await PushToken.holderWeight(NEW_USER_ONE);
            const new_user_two_holder_weight = await PushToken.holderWeight(NEW_USER_TWO);
            const new_user_three_holder_weight = await PushToken.holderWeight(NEW_USER_THREE);

            console.log("New User One Staked Weight: ", new_user_one_staked_weight.toString());
            console.log("New User Two Staked Weight: ", new_user_two_staked_weight.toString());
            console.log("New User Three Staked Weight: ", new_user_three_staked_weight.toString());

            console.log("New User One Holder Weight: ", new_user_one_holder_weight.toString());
            console.log("New User Two Holder Weight: ", new_user_two_holder_weight.toString());
            console.log("New User Three Holder Weight: ", new_user_three_holder_weight.toString());

            console.log("\n######## REWARDS of Staker after First HAREVST ########");

            console.log("Rewards of all Stakers close to 986 PUSH\n");

            // Alice tries to restake using 1000 more tokens
            await passBlockNumers(100);
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(3000));

            await stakePushTokens(NEW_USER_ONE_SIGNER, tokensBN(986));
            // 10 more epochs passes
            await passBlockNumers(10 * EPOCH_DURATION);
            
            await EPNSCoreV1Proxy.connect(NEW_USER_ONE_SIGNER).harvestAll();
            await EPNSCoreV1Proxy.connect(NEW_USER_TWO_SIGNER).harvestAll();
            await EPNSCoreV1Proxy.connect(NEW_USER_THREE_SIGNER).harvestAll();

            const rewards_new_user_one_2nd_harvest = await EPNSCoreV1Proxy.usersRewardsClaimed(NEW_USER_ONE);
            const rewards_new_user_two_2nd_harvest = await EPNSCoreV1Proxy.usersRewardsClaimed(NEW_USER_TWO);
            const rewards_new_user_three_2nd_harvest = await EPNSCoreV1Proxy.usersRewardsClaimed(NEW_USER_THREE);

            console.log("\n######## STAKED Weight and Holder Weights after 2nd Harvest + 1 RESTAKE ########\n");

            const coreContractHolderWeight2nd = await EPNSCoreV1Proxy.getUserStakeWeight(EPNSCoreV1Proxy.address);
            console.log("Core Contract Holder Weight: ", coreContractHolderWeight2nd.toString());

            const new_user_one_staked_weight_2nd = await EPNSCoreV1Proxy.getUserStakeWeight(NEW_USER_ONE);
            const new_user_two_staked_weight_2nd = await EPNSCoreV1Proxy.getUserStakeWeight(NEW_USER_TWO);
            const new_user_three_staked_weight_2nd = await EPNSCoreV1Proxy.getUserStakeWeight(NEW_USER_THREE);

            const new_user_one_holder_weight_2nd = await PushToken.holderWeight(NEW_USER_ONE);
            const new_user_two_holder_weight_2nd = await PushToken.holderWeight(NEW_USER_TWO);
            const new_user_three_holder_weight_2nd = await PushToken.holderWeight(NEW_USER_THREE);

            console.log("New User One Staked Weight: ", new_user_one_staked_weight_2nd.toString());
            console.log("New User Two Staked Weight: ", new_user_two_staked_weight_2nd.toString());
            console.log("New User Three Staked Weight: ", new_user_three_staked_weight_2nd.toString());

            console.log("New User One Holder Weight: ", new_user_one_holder_weight_2nd.toString());
            console.log("New User Two Holder Weight: ", new_user_two_holder_weight_2nd.toString());
            console.log("New User Three Holder Weight: ", new_user_three_holder_weight_2nd.toString());

            console.log("\n######## REWARDS of Staker after 2nd HAREVST + 1 Restake  ########\n");

            console.log("New User One Rewards after 2nd Harvest: ", rewards_new_user_one_2nd_harvest.toString());
            console.log("New User Two Rewards after 2nd Harvest: ", rewards_new_user_two_2nd_harvest.toString());
            console.log("New User Three Rewards after 2nd Harvest: ", rewards_new_user_three_2nd_harvest.toString());

            // Console log total rewards in 2nd Harvest specifically
            console.log("New User One Rewards in 2nd Harvest: ", rewards_new_user_one_2nd_harvest.sub(rewards_new_user_one).toString());
            console.log("New User Two Rewards in 2nd Harvest: ", rewards_new_user_two_2nd_harvest.sub(rewards_new_user_two).toString());
            console.log("New User Three Rewards in 2nd Harvest: ", rewards_new_user_three_2nd_harvest.sub(rewards_new_user_three).toString());

            // Basic Test Assertions
            expect(rewards_new_user_one_2nd_harvest).to.be.gt(rewards_new_user_two_2nd_harvest);
            expect(rewards_new_user_one_2nd_harvest).to.be.gt(rewards_new_user_three_2nd_harvest);
            expect(rewards_new_user_two_2nd_harvest).to.be.closeTo(rewards_new_user_three_2nd_harvest, 1000);
        })

    });

    describe("🟢 2. harvestCoreReset() function Test", function () {

        it("Option 2.1 : harvestAllNewCoreReset Function - ( with Non-ZERO Push in Wallet ) + Restake", async function () {
            await passBlockNumers(1 * EPOCH_DURATION);
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(3000));
            
            await stakePushTokens(BOBSIGNER, tokensBN(1000));
            await stakePushTokens(ALICESIGNER, tokensBN(1000));
            await stakePushTokens(CHARLIESIGNER, tokensBN(1000));

            // Get Staked Weight for all 3
            
            await passBlockNumers(10 * EPOCH_DURATION);

            await EPNSCoreV1Proxy.connect(ALICESIGNER).harvestAllNewCoreReset();
            await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAllNewCoreReset();
            await EPNSCoreV1Proxy.connect(CHARLIESIGNER).harvestAllNewCoreReset();

            const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
            const rewards_alice = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
            const rewards_charlie = await EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE);

            // Check that rewards for all stakers are close to each other - ~986 PUSH
            expect(rewards_bob).to.be.closeTo(rewards_alice, 1000);
            expect(rewards_alice).to.be.closeTo(rewards_charlie, 1000);
            expect(rewards_bob).to.be.closeTo(rewards_charlie, 1000);

            console.log("\n######## STAKED Weight and Holder Weights after First Harvest ########\n");

            const coreContractHolderWeight = await PushToken.holderWeight(EPNSCoreV1Proxy.address);
            console.log("Core Contract Holder Weight: ", coreContractHolderWeight.toString());

            const bobStakedWeight = await EPNSCoreV1Proxy.getUserStakeWeight(BOB);
            const aliceStakedWeight = await EPNSCoreV1Proxy.getUserStakeWeight(ALICE);
            const charlieStakedWeight = await EPNSCoreV1Proxy.getUserStakeWeight(CHARLIE);

            const bobHolderWeigt = await PushToken.holderWeight(BOB);
            const aliceHolderWeigt = await PushToken.holderWeight(ALICE);
            const charlieHolderWeigt = await PushToken.holderWeight(CHARLIE);

            console.log("Bob Staked Weight: ", bobStakedWeight.toString());
            console.log("Alice Staked Weight: ", aliceStakedWeight.toString());
            console.log("Charlie Staked Weight: ", charlieStakedWeight.toString());

            console.log("Bob Holder Weight: ", bobHolderWeigt.toString());
            console.log("Alice Holder Weight: ", aliceHolderWeigt.toString());
            console.log("Charlie Holder Weight: ", charlieHolderWeigt.toString());

            console.log("\n######## REWARDS of Staker after First HAREVST ########");

            console.log("Rewards of all Stakers close to 986 PUSH\n");

            // Alice tries to restake using 1000 more tokens
            await passBlockNumers(100);
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(3000));

            await stakePushTokens(ALICESIGNER, tokensBN(1000));

            // 10 more epochs passes
            await passBlockNumers(10 * EPOCH_DURATION);

            await EPNSCoreV1Proxy.connect(ALICESIGNER).harvestAllNewCoreReset();
            await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAllNewCoreReset();
            await EPNSCoreV1Proxy.connect(CHARLIESIGNER).harvestAllNewCoreReset();

            const rewards_alice_2ndHarvest = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
            const rewards_bob_2ndHarvest = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
            const rewards_charlie_2ndHarvest = await EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE);

            console.log("\n######## STAKED Weight and Holder Weights after 2nd Harvest + 1 RESTAKE ########\n");

            const coreContractHolderWeight2nd = await EPNSCoreV1Proxy.getUserStakeWeight(EPNSCoreV1Proxy.address);
            console.log("Core Contract Holder Weight: ", coreContractHolderWeight2nd.toString());

            const bobStakedWeight2nd = await EPNSCoreV1Proxy.getUserStakeWeight(BOB);
            const aliceStakedWeight2nd = await EPNSCoreV1Proxy.getUserStakeWeight(ALICE);
            const charlieStakedWeight2nd = await EPNSCoreV1Proxy.getUserStakeWeight(CHARLIE);

            const bobHolderWeight2nd = await PushToken.holderWeight(BOB);
            const aliceHolderWeight2nd = await PushToken.holderWeight(ALICE);
            const charlieHolderWeight2nd = await PushToken.holderWeight(CHARLIE);

            console.log("Bob Staked Weight: ", bobStakedWeight2nd.toString());
            console.log("Alice Staked Weight: ", aliceStakedWeight2nd.toString());
            console.log("Charlie Staked Weight: ", charlieStakedWeight2nd.toString());

            console.log("Bob Holder Weight: ", bobHolderWeight2nd.toString());
            console.log("Alice Holder Weight: ", aliceHolderWeight2nd.toString());
            console.log("Charlie Holder Weight: ", charlieHolderWeight2nd.toString());

            console.log("\n######## REWARDS of Staker after 2nd HAREVST + 1 Restake  ########\n");

            console.log("Alice Rewards after 2nd Harvest: ", rewards_alice_2ndHarvest.toString());
            console.log("Bob Rewards after 2nd Harvest: ", rewards_bob_2ndHarvest.toString());
            console.log("Charlie Rewards after 2nd Harvest: ", rewards_charlie_2ndHarvest.toString());
            // Console log total rewards in 2nd Harvest specifically
            console.log("Alice Rewards in 2nd Harvest: ", rewards_alice_2ndHarvest.sub(rewards_alice).toString());
            console.log("Bob Rewards in 2nd Harvest: ", rewards_bob_2ndHarvest.sub(rewards_bob).toString());
            console.log("Charlie Rewards in 2nd Harvest: ", rewards_charlie_2ndHarvest.sub(rewards_charlie).toString());

            // Basic Test Assertions
            // Alice's final reward should be more than BOB and Charlie
            expect(rewards_alice_2ndHarvest).to.be.gt(rewards_bob_2ndHarvest);
            expect(rewards_alice_2ndHarvest).to.be.gt(rewards_charlie_2ndHarvest);
            // Bob and Charlie should have similar or closeTo rewards 
            expect(rewards_bob_2ndHarvest).to.be.closeTo(rewards_charlie_2ndHarvest, 1000);
            

        })

        it("Option 1.2 : Current Harvest Function - ( with ZERO Push in Wallet ) + Restake", async function () {
            await passBlockNumers(1 * EPOCH_DURATION);
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(3000));

            await stakePushTokens(NEW_USER_ONE_SIGNER, tokensBN(1000));
            await stakePushTokens(NEW_USER_TWO_SIGNER, tokensBN(1000));
            await stakePushTokens(NEW_USER_THREE_SIGNER, tokensBN(1000));

            // Ensure that after staking balance of all user is ZERO
            expect(await PushToken.balanceOf(NEW_USER_ONE)).to.be.equal(tokensBN(0));
            expect(await PushToken.balanceOf(NEW_USER_TWO)).to.be.equal(tokensBN(0));
            expect(await PushToken.balanceOf(NEW_USER_THREE)).to.be.equal(tokensBN(0));

            // Get Staked Weight for all 3
            
            await passBlockNumers(10 * EPOCH_DURATION);

            await EPNSCoreV1Proxy.connect(NEW_USER_ONE_SIGNER).harvestAllNewCoreReset();
            await EPNSCoreV1Proxy.connect(NEW_USER_TWO_SIGNER).harvestAllNewCoreReset();
            await EPNSCoreV1Proxy.connect(NEW_USER_THREE_SIGNER).harvestAllNewCoreReset();

            const rewards_new_user_one = await EPNSCoreV1Proxy.usersRewardsClaimed(NEW_USER_ONE);
            const rewards_new_user_two = await EPNSCoreV1Proxy.usersRewardsClaimed(NEW_USER_TWO);
            const rewards_new_user_three = await EPNSCoreV1Proxy.usersRewardsClaimed(NEW_USER_THREE);

            // Check that rewards for all stakers are close to each other - ~986 PUSH
            expect(rewards_new_user_one).to.be.closeTo(rewards_new_user_two, 1000);
            expect(rewards_new_user_two).to.be.closeTo(rewards_new_user_three, 1000);
            expect(rewards_new_user_one).to.be.closeTo(rewards_new_user_three, 1000);

            console.log("\n######## STAKED Weight and Holder Weights after First Harvest ########\n");

            const coreContractHolderWeight = await PushToken.holderWeight(EPNSCoreV1Proxy.address);
            console.log("Core Contract Holder Weight: ", coreContractHolderWeight.toString());

            const new_user_one_staked_weight = await EPNSCoreV1Proxy.getUserStakeWeight(NEW_USER_ONE);
            const new_user_two_staked_weight = await EPNSCoreV1Proxy.getUserStakeWeight(NEW_USER_TWO);
            const new_user_three_staked_weight = await EPNSCoreV1Proxy.getUserStakeWeight(NEW_USER_THREE);

            const new_user_one_holder_weight = await PushToken.holderWeight(NEW_USER_ONE);
            const new_user_two_holder_weight = await PushToken.holderWeight(NEW_USER_TWO);
            const new_user_three_holder_weight = await PushToken.holderWeight(NEW_USER_THREE);

            console.log("New User One Staked Weight: ", new_user_one_staked_weight.toString());
            console.log("New User Two Staked Weight: ", new_user_two_staked_weight.toString());
            console.log("New User Three Staked Weight: ", new_user_three_staked_weight.toString());

            console.log("New User One Holder Weight: ", new_user_one_holder_weight.toString());
            console.log("New User Two Holder Weight: ", new_user_two_holder_weight.toString());
            console.log("New User Three Holder Weight: ", new_user_three_holder_weight.toString());

            console.log("\n######## REWARDS of Staker after First HAREVST ########");

            console.log("Rewards of all Stakers close to 986 PUSH\n");

            // Alice tries to restake using 1000 more tokens
            await passBlockNumers(100);
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(3000));

            await stakePushTokens(NEW_USER_ONE_SIGNER, tokensBN(986));
            // 10 more epochs passes
            await passBlockNumers(10 * EPOCH_DURATION);
            
            await EPNSCoreV1Proxy.connect(NEW_USER_ONE_SIGNER).harvestAllNewCoreReset();
            await EPNSCoreV1Proxy.connect(NEW_USER_TWO_SIGNER).harvestAllNewCoreReset();
            await EPNSCoreV1Proxy.connect(NEW_USER_THREE_SIGNER).harvestAllNewCoreReset();

            const rewards_new_user_one_2nd_harvest = await EPNSCoreV1Proxy.usersRewardsClaimed(NEW_USER_ONE);
            const rewards_new_user_two_2nd_harvest = await EPNSCoreV1Proxy.usersRewardsClaimed(NEW_USER_TWO);
            const rewards_new_user_three_2nd_harvest = await EPNSCoreV1Proxy.usersRewardsClaimed(NEW_USER_THREE);

            console.log("\n######## STAKED Weight and Holder Weights after 2nd Harvest + 1 RESTAKE ########\n");

            const coreContractHolderWeight2nd = await EPNSCoreV1Proxy.getUserStakeWeight(EPNSCoreV1Proxy.address);
            console.log("Core Contract Holder Weight: ", coreContractHolderWeight2nd.toString());

            const new_user_one_staked_weight_2nd = await EPNSCoreV1Proxy.getUserStakeWeight(NEW_USER_ONE);
            const new_user_two_staked_weight_2nd = await EPNSCoreV1Proxy.getUserStakeWeight(NEW_USER_TWO);
            const new_user_three_staked_weight_2nd = await EPNSCoreV1Proxy.getUserStakeWeight(NEW_USER_THREE);

            const new_user_one_holder_weight_2nd = await PushToken.holderWeight(NEW_USER_ONE);
            const new_user_two_holder_weight_2nd = await PushToken.holderWeight(NEW_USER_TWO);
            const new_user_three_holder_weight_2nd = await PushToken.holderWeight(NEW_USER_THREE);

            console.log("New User One Staked Weight: ", new_user_one_staked_weight_2nd.toString());
            console.log("New User Two Staked Weight: ", new_user_two_staked_weight_2nd.toString());
            console.log("New User Three Staked Weight: ", new_user_three_staked_weight_2nd.toString());

            console.log("New User One Holder Weight: ", new_user_one_holder_weight_2nd.toString());
            console.log("New User Two Holder Weight: ", new_user_two_holder_weight_2nd.toString());
            console.log("New User Three Holder Weight: ", new_user_three_holder_weight_2nd.toString());

            console.log("\n######## REWARDS of Staker after 2nd HAREVST + 1 Restake  ########\n");

            console.log("New User One Rewards after 2nd Harvest: ", rewards_new_user_one_2nd_harvest.toString());
            console.log("New User Two Rewards after 2nd Harvest: ", rewards_new_user_two_2nd_harvest.toString());
            console.log("New User Three Rewards after 2nd Harvest: ", rewards_new_user_three_2nd_harvest.toString());

            // Console log total rewards in 2nd Harvest specifically
            console.log("New User One Rewards in 2nd Harvest: ", rewards_new_user_one_2nd_harvest.sub(rewards_new_user_one).toString());
            console.log("New User Two Rewards in 2nd Harvest: ", rewards_new_user_two_2nd_harvest.sub(rewards_new_user_two).toString());
            console.log("New User Three Rewards in 2nd Harvest: ", rewards_new_user_three_2nd_harvest.sub(rewards_new_user_three).toString());

            // Basic Test Assertions
            expect(rewards_new_user_one_2nd_harvest).to.be.gt(rewards_new_user_two_2nd_harvest);
            expect(rewards_new_user_one_2nd_harvest).to.be.gt(rewards_new_user_three_2nd_harvest);
            expect(rewards_new_user_two_2nd_harvest).to.be.closeTo(rewards_new_user_three_2nd_harvest, 1000);
        })

    });
    
    describe("🟢 RESTAKE ISSUE TEST-NEW STAKE LOGIC", function () {

        /** 
         * CASE 3: Test New Stake-Harvest Logic - WHEN Staker has Non-Zero PUSH in Account before HARVESTING
         * 1. Consider 3 users Alice, Bob, Charlie
         * 2. They all stake 1000 tokens each
         * 3. 10 epoch passes
         * 4. Alice harvests rewards using harvestAllNewStake()
         * 5. Bob harvests rewards using harvestAllNewStake()
         * 6. Charlie harvests rewards using harvestAllNewStake()
         * 5. ALICE ReStakes after 10 epochs after harvest
         * 6. 10 epoch passes
         * 7. All 3 harvests again
         * 8. Compare their rewards
         */

        it("NEW STAKE LOGIC TEST() - When STAKER Has NON-ZERO PUSH IN Account", async function () {
            await passBlockNumers(1 * EPOCH_DURATION);

            console.log("\n######## STAKED Weight and Holder Weights BEFORE STAKE #######\n");
            const coreContractHolderWeightBegin = await PushToken.holderWeight(EPNSCoreV1Proxy.address);
            console.log("Core Contract Holder Weight: ", coreContractHolderWeightBegin.toString());

            await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(3000));
            
            await EPNSCoreV1Proxy.connect(BOBSIGNER).stakeNew(tokensBN(1000));
            await EPNSCoreV1Proxy.connect(ALICESIGNER).stakeNew(tokensBN(1000));
            await EPNSCoreV1Proxy.connect(CHARLIESIGNER).stakeNew(tokensBN(1000));

            // Get Staked Weight for all 3
            console.log("\n######## STAKED Weight and Holder Weights BEFORE First Harvest ########\n");


            // Get balance of Core Contract before harvest
            const coreContractBalanceBefore = await PushToken.balanceOf(EPNSCoreV1Proxy.address);
            console.log("Core Contract Balance Before Harvest: ", coreContractBalanceBefore.toString());

            const bobStakedWeightFirst = await EPNSCoreV1Proxy.getUserStakeWeight(BOB);
            const aliceStakedWeightFirst = await EPNSCoreV1Proxy.getUserStakeWeight(ALICE);
            const charlieStakedWeightFirst = await EPNSCoreV1Proxy.getUserStakeWeight(CHARLIE);

            const bobHolderWeigtFirst = await PushToken.holderWeight(BOB);
            const aliceHolderWeigtFirst =await PushToken.holderWeight(ALICE);
            const charlieHolderWeigtFirst = await PushToken.holderWeight(CHARLIE);

            console.log("Bob Staked Weight: ", bobStakedWeightFirst.toString());
            console.log("Alice Staked Weight: ", aliceStakedWeightFirst.toString());
            console.log("Charlie Staked Weight: ", charlieStakedWeightFirst.toString());

            console.log("Bob Holder Weight: ", bobHolderWeigtFirst.toString());
            console.log("Alice Holder Weight: ", aliceHolderWeigtFirst.toString());
            console.log("Charlie Holder Weight: ", charlieHolderWeigtFirst.toString());
            
            await passBlockNumers(10 * EPOCH_DURATION);

            await EPNSCoreV1Proxy.connect(ALICESIGNER).harvestAllNewStake();
            await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAllNewStake();
            await EPNSCoreV1Proxy.connect(CHARLIESIGNER).harvestAllNewStake();

            const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
            const rewards_alice = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
            const rewards_charlie = await EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE);

            // Check that rewards for all stakers are close to each other - ~986 PUSH
            expect(rewards_bob).to.be.closeTo(rewards_alice, 1000);
            expect(rewards_alice).to.be.closeTo(rewards_charlie, 1000);
            expect(rewards_bob).to.be.closeTo(rewards_charlie, 1000);

            console.log("\n######## STAKED Weight and Holder Weights after First Harvest ########\n");

            const coreContractHolderWeight = await PushToken.holderWeight(EPNSCoreV1Proxy.address);
            console.log("Core Contract Holder Weight: ", coreContractHolderWeight.toString());

            const bobStakedWeight = await EPNSCoreV1Proxy.getUserStakeWeight(BOB);
            const aliceStakedWeight = await EPNSCoreV1Proxy.getUserStakeWeight(ALICE);
            const charlieStakedWeight = await EPNSCoreV1Proxy.getUserStakeWeight(CHARLIE);

            const bobHolderWeigt = await PushToken.holderWeight(BOB);
            const aliceHolderWeigt = await PushToken.holderWeight(ALICE);
            const charlieHolderWeigt = await PushToken.holderWeight(CHARLIE);

            console.log("Bob Staked Weight: ", bobStakedWeight.toString());
            console.log("Alice Staked Weight: ", aliceStakedWeight.toString());
            console.log("Charlie Staked Weight: ", charlieStakedWeight.toString());

            console.log("Bob Holder Weight: ", bobHolderWeigt.toString());
            console.log("Alice Holder Weight: ", aliceHolderWeigt.toString());
            console.log("Charlie Holder Weight: ", charlieHolderWeigt.toString());

            console.log("\n######## REWARDS of Staker after First HAREVST ########\n");
            console.log("Rewards of all Stakers close to 986 PUSH\n");

            // Alice tries to restake using 1000 more tokens
            await passBlockNumers(100);
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(3000));

            await EPNSCoreV1Proxy.connect(ALICESIGNER).stakeNew(tokensBN(1000));
            console.log("\n######## STAKED Weight and Holder Weights RIGHT AFTER Alice's SECOND STAKE ########\n");

            // CHECK HolderWeights right after STAKE
            const aliceHolderWeigtAfterStake = await PushToken.holderWeight(ALICE);
            const bobHolderWeigtAfterStake = await PushToken.holderWeight(BOB);
            const charlieHolderWeigtAfterStake = await PushToken.holderWeight(CHARLIE);

            console.log("Alice Holder Weight: ", aliceHolderWeigtAfterStake.toString());
            console.log("Bob Holder Weight: ", bobHolderWeigtAfterStake.toString());
            console.log("Charlie Holder Weight: ", charlieHolderWeigtAfterStake.toString());

            // 10 more epochs passes
            await passBlockNumers(10 * EPOCH_DURATION);

            await EPNSCoreV1Proxy.connect(ALICESIGNER).harvestAllNewStake();
            await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAllNewStake();
            await EPNSCoreV1Proxy.connect(CHARLIESIGNER).harvestAllNewStake();

            const rewards_alice_2ndHarvest = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
            const rewards_bob_2ndHarvest = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
            const rewards_charlie_2ndHarvest = await EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE);

            console.log("\n######## STAKED Weight and Holder Weights after 2nd Harvest + 1 RESTAKE ########\n");

            const coreContractHolderWeight2nd = await PushToken.holderWeight(EPNSCoreV1Proxy.address);
            console.log("Core Contract Holder Weight: ", coreContractHolderWeight2nd.toString());

            const bobStakedWeight2nd = await EPNSCoreV1Proxy.getUserStakeWeight(BOB);
            const aliceStakedWeight2nd = await EPNSCoreV1Proxy.getUserStakeWeight(ALICE);
            const charlieStakedWeight2nd = await EPNSCoreV1Proxy.getUserStakeWeight(CHARLIE);

            const bobHolderWeight2nd = await PushToken.holderWeight(BOB);
            const aliceHolderWeight2nd = await PushToken.holderWeight(ALICE);
            const charlieHolderWeight2nd = await PushToken.holderWeight(CHARLIE);

            console.log("Bob Staked Weight: ", bobStakedWeight2nd.toString());
            console.log("Alice Staked Weight: ", aliceStakedWeight2nd.toString());
            console.log("Charlie Staked Weight: ", charlieStakedWeight2nd.toString());

            console.log("Bob Holder Weight: ", bobHolderWeight2nd.toString());
            console.log("Alice Holder Weight: ", aliceHolderWeight2nd.toString());
            console.log("Charlie Holder Weight: ", charlieHolderWeight2nd.toString());

            console.log("\n######## REWARDS of Staker after 2nd HAREVST + 1 Restake  ########\n");

            console.log("Alice Rewards after 2nd Harvest: ", rewards_alice_2ndHarvest.toString());
            console.log("Bob Rewards after 2nd Harvest: ", rewards_bob_2ndHarvest.toString());
            console.log("Charlie Rewards after 2nd Harvest: ", rewards_charlie_2ndHarvest.toString());
            // Console log total rewards in 2nd Harvest specifically
            console.log("Alice Rewards in 2nd Harvest: ", rewards_alice_2ndHarvest.sub(rewards_alice).toString());
            console.log("Bob Rewards in 2nd Harvest: ", rewards_bob_2ndHarvest.sub(rewards_bob).toString());
            console.log("Charlie Rewards in 2nd Harvest: ", rewards_charlie_2ndHarvest.sub(rewards_charlie).toString());

            // Basic Test Assertions

            // Alice's final reward should be more than BOB and Charlie
            expect(rewards_alice_2ndHarvest).to.be.gt(rewards_bob_2ndHarvest);
            expect(rewards_alice_2ndHarvest).to.be.gt(rewards_charlie_2ndHarvest);
            // Bob and Charlie should have similar or closeTo rewards 
            expect(rewards_bob_2ndHarvest).to.be.closeTo(rewards_charlie_2ndHarvest, 1000);
        })

        /**
         * CASE 4: Test New Stake-Harvest Logic - WHEN Staker has ZERO PUSH in Account before HARVESTING
         * 1. Consider 3 users NEW_USER_ONE, NEW_USER_TWO, NEW_USER_THREE
         * 2. They all stake 1000 tokens each
         * 3. 10 epoch passes
         * 4. NEW_USER_ONE harvests rewards using harvestAllNewStake()
         * 5. NEW_USER_TWO harvests rewards using harvestAllNewStake()
         * 6. NEW_USER_THREE harvests rewards using harvestAllNewStake()
         * 5. NEW_USER_ONE ReStakes after 10 epochs after harvest
         * 6. 10 epoch passes
         * 7. All 3 harvests again
         * 8. Compare their rewards
         *  
         */

        it("Harvest Option 3.2 : NEW STAKE LOGIC TEST() - When STAKER Has ZERO PUSH IN Account", async function () {
            await passBlockNumers(1 * EPOCH_DURATION);
            console.log("\n######## STAKED Weight and Holder Weights BEFORE STAKE #######\n");

            const coreContractHolderWeightBegin = await PushToken.holderWeight(EPNSCoreV1Proxy.address);
            console.log("Core Contract Holder Weight: ", coreContractHolderWeightBegin.toString());

            await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(3000));
            
            await EPNSCoreV1Proxy.connect(NEW_USER_ONE_SIGNER).stakeNew(tokensBN(1000));
            await EPNSCoreV1Proxy.connect(NEW_USER_TWO_SIGNER).stakeNew(tokensBN(1000));
            await EPNSCoreV1Proxy.connect(NEW_USER_THREE_SIGNER).stakeNew(tokensBN(1000));

            // Ensure that after staking balance of all user is ZERO
            expect(await PushToken.balanceOf(NEW_USER_ONE)).to.be.equal(tokensBN(0));
            expect(await PushToken.balanceOf(NEW_USER_TWO)).to.be.equal(tokensBN(0));
            expect(await PushToken.balanceOf(NEW_USER_THREE)).to.be.equal(tokensBN(0));

            // Get Staked Weight for all 3
            console.log("\n######## STAKED Weight and Holder Weights BEFORE First Harvest ########\n");

            const coreContractHolderWeightFirst = await PushToken.holderWeight(EPNSCoreV1Proxy.address);
            console.log("Core Contract Holder Weight: ", coreContractHolderWeightFirst.toString());

            // Get balance of BOB before harvest
            const newUserOne = await PushToken.balanceOf(NEW_USER_ONE);
            // Ensure that NEW_USER_ONE has 0 PUSH Tokens after STAKING
            expect(newUserOne).to.equal(tokensBN(0));
            
            const newUserOneStakedWeightFirst = await EPNSCoreV1Proxy.getUserStakeWeight(NEW_USER_ONE);
            const newUserTwoStakedWeightFirst = await EPNSCoreV1Proxy.getUserStakeWeight(NEW_USER_TWO);
            const newUserThreeStakedWeightFirst = await EPNSCoreV1Proxy.getUserStakeWeight(NEW_USER_THREE);

            const newUserOneHolderWeigtFirst = await PushToken.holderWeight(NEW_USER_ONE);
            const newUserTwoHolderWeigtFirst =await PushToken.holderWeight(NEW_USER_TWO);
            const newUserThreeHolderWeigtFirst = await PushToken.holderWeight(NEW_USER_THREE);

            console.log("newUserOne Staked Weight: ", newUserOneStakedWeightFirst.toString());
            console.log("newUserTwo Staked Weight: ", newUserTwoStakedWeightFirst.toString());
            console.log("newUserThree Staked Weight: ", newUserThreeStakedWeightFirst.toString());

            console.log("newUserOne Holder Weight: ", newUserOneHolderWeigtFirst.toString());
            console.log("newUserTwo Holder Weight: ", newUserTwoHolderWeigtFirst.toString());
            console.log("newUserThree Holder Weight: ", newUserThreeHolderWeigtFirst.toString());

            await passBlockNumers(10 * EPOCH_DURATION);

            await EPNSCoreV1Proxy.connect(NEW_USER_ONE_SIGNER).harvestAllNewStake();
            await EPNSCoreV1Proxy.connect(NEW_USER_TWO_SIGNER).harvestAllNewStake();
            await EPNSCoreV1Proxy.connect(NEW_USER_THREE_SIGNER).harvestAllNewStake();

            const rewards_new_user_one = await EPNSCoreV1Proxy.usersRewardsClaimed(NEW_USER_ONE);
            const rewards_new_user_two = await EPNSCoreV1Proxy.usersRewardsClaimed(NEW_USER_TWO);
            const rewards_new_user_three = await EPNSCoreV1Proxy.usersRewardsClaimed(NEW_USER_THREE);

            // Check that rewards for all stakers are close to each other - ~986 PUSH
            expect(rewards_new_user_one).to.be.closeTo(rewards_new_user_two, 1000);
            expect(rewards_new_user_two).to.be.closeTo(rewards_new_user_three, 1000);
            expect(rewards_new_user_one).to.be.closeTo(rewards_new_user_three, 1000);
            

            console.log("\n######## STAKED Weight and Holder Weights after First Harvest ########\n");
            
            const coreContractHolderWeight = await PushToken.holderWeight(EPNSCoreV1Proxy.address);
            console.log("Core Contract Holder Weight: ", coreContractHolderWeight.toString());

            const newUserOneStakedWeight = await EPNSCoreV1Proxy.getUserStakeWeight(NEW_USER_ONE);
            const newUserTwoStakedWeight = await EPNSCoreV1Proxy.getUserStakeWeight(NEW_USER_TWO);
            const newUserThreeStakedWeight = await EPNSCoreV1Proxy.getUserStakeWeight(NEW_USER_THREE);

            const newUserOneHolderWeigt = await PushToken.holderWeight(NEW_USER_ONE);
            const newUserTwoHolderWeigt = await PushToken.holderWeight(NEW_USER_TWO);
            const newUserThreeHolderWeigt = await PushToken.holderWeight(NEW_USER_THREE);

            console.log("newUserOne Staked Weight: ", newUserOneStakedWeight.toString());
            console.log("newUserTwo Staked Weight: ", newUserTwoStakedWeight.toString());
            console.log("newUserThree Staked Weight: ", newUserThreeStakedWeight.toString());

            console.log("newUserOne Holder Weight: ", newUserOneHolderWeigt.toString());
            console.log("newUserTwo Holder Weight: ", newUserTwoHolderWeigt.toString());
            console.log("newUserThree Holder Weight: ", newUserThreeHolderWeigt.toString());

            console.log("\n######## REWARDS of Staker after First HAREVST ########\n");
            console.log("Rewards of all Stakers close to 986 PUSH\n");

            // newUserOne tries to restake using 1000 more tokens
            await passBlockNumers(100);
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(3000));

            await EPNSCoreV1Proxy.connect(NEW_USER_ONE_SIGNER).stakeNew(tokensBN(986));

            console.log("\n######## STAKED Weight and Holder Weights RIGHT AFTER Alice's SECOND STAKE ########\n");

            // CHECK HolderWeights right after STAKE
            const newUserOneHolderWeigtAfterStake = await PushToken.holderWeight(NEW_USER_ONE);
            const newUserTwoHolderWeigtAfterStake = await PushToken.holderWeight(NEW_USER_TWO);
            const newUserThreeHolderWeigtAfterStake = await PushToken.holderWeight(NEW_USER_THREE);

            console.log("newUserOne Holder Weight: ", newUserOneHolderWeigtAfterStake.toString());
            console.log("newUserTwo Holder Weight: ", newUserTwoHolderWeigtAfterStake.toString());
            console.log("newUserThree Holder Weight: ", newUserThreeHolderWeigtAfterStake.toString());

            // 10 more epochs passes
            await passBlockNumers(10 * EPOCH_DURATION);

            await EPNSCoreV1Proxy.connect(NEW_USER_ONE_SIGNER).harvestAllNewStake();
            await EPNSCoreV1Proxy.connect(NEW_USER_TWO_SIGNER).harvestAllNewStake();
            await EPNSCoreV1Proxy.connect(NEW_USER_THREE_SIGNER).harvestAllNewStake();

            const rewards_newUserOne_2ndHarvest = await EPNSCoreV1Proxy.usersRewardsClaimed(NEW_USER_ONE);
            const rewards_newUserTwo_2ndHarvest = await EPNSCoreV1Proxy.usersRewardsClaimed(NEW_USER_TWO);
            const rewards_newUserThree_2ndHarvest = await EPNSCoreV1Proxy.usersRewardsClaimed(NEW_USER_THREE);

            console.log("\n######## STAKED Weight and Holder Weights after 2nd Harvest + 1 RESTAKE ########\n");

            const coreContractHolderWeight2nd = await PushToken.holderWeight(EPNSCoreV1Proxy.address);
            console.log("Core Contract Holder Weight: ", coreContractHolderWeight2nd.toString());

            const newUserOneStakedWeight2nd = await EPNSCoreV1Proxy.getUserStakeWeight(NEW_USER_ONE);
            const newUserTwoStakedWeight2nd = await EPNSCoreV1Proxy.getUserStakeWeight(NEW_USER_TWO);
            const newUserThreeStakedWeight2nd = await EPNSCoreV1Proxy.getUserStakeWeight(NEW_USER_THREE);

            const newUserOneHolderWeight2nd = await PushToken.holderWeight(NEW_USER_ONE);
            const newUserTwoHolderWeight2nd = await PushToken.holderWeight(NEW_USER_TWO);
            const newUserThreeHolderWeight2nd = await PushToken.holderWeight(NEW_USER_THREE);

            console.log("newUserOne Staked Weight: ", newUserOneStakedWeight2nd.toString());
            console.log("newUserTwo Staked Weight: ", newUserTwoStakedWeight2nd.toString());
            console.log("newUserThree Staked Weight: ", newUserThreeStakedWeight2nd.toString());

            console.log("newUserOne Holder Weight: ", newUserOneHolderWeight2nd.toString());
            console.log("newUserTwo Holder Weight: ", newUserTwoHolderWeight2nd.toString());
            console.log("newUserThree Holder Weight: ", newUserThreeHolderWeight2nd.toString());

            console.log("\n######## REWARDS of Staker after 2nd HAREVST + 1 Restake  ########\n");

            console.log("newUserOne Rewards after 2nd Harvest: ", rewards_newUserOne_2ndHarvest.toString());
            console.log("newUserTwo Rewards after 2nd Harvest: ", rewards_newUserTwo_2ndHarvest.toString());
            console.log("newUserThree Rewards after 2nd Harvest: ", rewards_newUserThree_2ndHarvest.toString());

            // Console log total rewards in 2nd Harvest specifically
            console.log("newUserOne Rewards in 2nd Harvest: ", rewards_newUserOne_2ndHarvest.sub(rewards_new_user_one).toString());
            console.log("newUserTwo Rewards in 2nd Harvest: ", rewards_newUserTwo_2ndHarvest.sub(rewards_new_user_two).toString());
            console.log("newUserThree Rewards in 2nd Harvest: ", rewards_newUserThree_2ndHarvest.sub(rewards_new_user_three).toString());
            
            // Basic Test Assertions

            // Alice's final reward should be more than BOB and Charlie
            expect(rewards_newUserOne_2ndHarvest).to.be.gt(rewards_newUserTwo_2ndHarvest);
            expect(rewards_newUserOne_2ndHarvest).to.be.gt(rewards_newUserThree_2ndHarvest);
            // Bob and Charlie should have similar or closeTo rewards 
            expect(rewards_newUserTwo_2ndHarvest).to.be.closeTo(rewards_newUserThree_2ndHarvest, 1000);
        })

    })
        /**Test Cases Ends Here **/
    });

    })
  
});
});
