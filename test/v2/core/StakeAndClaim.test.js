const { ethers, waffle } = require("hardhat");

const { tokensBN, bn } = require("../../../helpers/utils");

const { epnsContractFixture, tokenFixture } = require("../../common/fixturesV2");
const { expect } = require("../../common/expect");
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

    ({ PROXYADMIN, EPNSCoreV1Proxy, EPNSCommV1Proxy, ROUTER, PushToken } =
      await loadFixture(epnsContractFixture));
  });

  describe("EPNS CORE V2: Stake and Claim Tests", () => {
    const CHANNEL_TYPE = 2;
    const EPOCH_DURATION =  21 * 7156;
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
          await EPNSCoreV1Proxy.getUserEpochToWeight(user, i);

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

    const getAdminRewards = async()=>{
      const rewards_admin = await EPNSCoreV1Proxy.usersRewardsClaimed(
        EPNSCoreV1Proxy.address
      );

      return rewards_admin;
    }

    /** Test Cases Starts Here **/

    /* CHECKPOINTS: lastEpochRelative() function
     * Should Reverts on overflow
     * Should calculate relative epoch numbers accurately
     * Shouldn't change epoch value if epoch "to" block number lies in same epoch boundry
     * User BOB stakes: Ensure epochIDs of lastStakedEpoch and lastClaimedEpoch are recorded accurately
     * User BOB stakes & then Harvests: Ensure epochIDs of lastStakedEpoch and lastClaimedEpoch are updated accurately
     * **/
    describe("🟢 lastEpochRelative Tests ", function () {
      it("Should revert on Block number overflow", async function () {
        const genesisBlock = await getCurrentBlock();
        await passBlockNumers(2 * EPOCH_DURATION);
        const futureBlock = await getCurrentBlock();

        const tx = EPNSCoreV1Proxy.lastEpochRelative(
          futureBlock.number,
          genesisBlock.number
        );
        await expect(tx).to.be.revertedWith(
          "PushCoreV2:lastEpochRelative:: Relative Block Number Overflow"
        );
      });

      it("Should calculate relative epoch numbers accurately", async function () {
        const genesisBlock = await getCurrentBlock();
        await passBlockNumers(5 * EPOCH_DURATION);
        const futureBlock = await getCurrentBlock();

        const epochID = await EPNSCoreV1Proxy.lastEpochRelative(
          genesisBlock.number,
          futureBlock.number
        );
        await expect(epochID).to.be.equal(6);
      });

      it("Shouldn't change epoch value if '_to' block lies in same epoch boundary", async function () {
        const genesisBlock = await getCurrentBlock();
        await passBlockNumers(EPOCH_DURATION / 2);
        const futureBlock = await getCurrentBlock();

        const epochID = await EPNSCoreV1Proxy.lastEpochRelative(
          genesisBlock.number,
          futureBlock.number
        );
        await expect(epochID).to.be.equal(1);
      });

      it("Should count staked EPOCH of user correctly", async function () {
        await addPoolFees(ADMINSIGNER, tokensBN(200));
        const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
        const passBlocks = 5;

        await passBlockNumers(passBlocks * EPOCH_DURATION);
        await stakePushTokens(BOBSIGNER, tokensBN(10));

        const bobDetails_2nd = await EPNSCoreV1Proxy.userFeesInfo(BOB);
        const userLastStakedEpochId = await EPNSCoreV1Proxy.lastEpochRelative(
          genesisEpoch.toNumber(),
          bobDetails_2nd.lastStakedBlock.toNumber()
        );
        const userLastClaimedEpochId = await EPNSCoreV1Proxy.lastEpochRelative(
          genesisEpoch.toNumber(),
          bobDetails_2nd.lastClaimedBlock.toNumber()
        );

        await expect(userLastClaimedEpochId).to.be.equal(1); // Epoch 1 - since no claim done yet
        await expect(userLastStakedEpochId).to.be.equal(passBlocks + 1);
      });

      it("Should track User's Staked and Harvest block accurately", async function () {
        const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
        const fiveBlocks = 5;
        const tenBlocks = 10;

        await passBlockNumers(fiveBlocks * EPOCH_DURATION);
        // Stakes Push Tokens after 5 blocks, at 6th EPOCH
        await stakePushTokens(BOBSIGNER, tokensBN(10));
        const bobDetails_afterStake = await EPNSCoreV1Proxy.userFeesInfo(BOB);
        const userLastStakedEpochId = await EPNSCoreV1Proxy.lastEpochRelative(
          genesisEpoch.toNumber(),
          bobDetails_afterStake.lastStakedBlock.toNumber()
        );

        await passBlockNumers(tenBlocks * EPOCH_DURATION);
        // Harvests Push Tokens after 15 blocks, at 16th EPOCH
        await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAll();
        const bobDetails_afterClaim = await EPNSCoreV1Proxy.userFeesInfo(BOB);
        const userLastClaimedEpochId = await EPNSCoreV1Proxy.lastEpochRelative(
          genesisEpoch.toNumber(),
          bobDetails_afterClaim.lastClaimedBlock.toNumber()
        );

        await expect(userLastStakedEpochId).to.be.equal(fiveBlocks + 1);
        await expect(userLastClaimedEpochId).to.be.equal(
          fiveBlocks + tenBlocks + 1
        );
      });
    });
    /**
     * Stake & Unstake Checkpoints
     *
     * STAKE
     * Updates userFeesInfo details accurately
     * Push token transfer works as expected
     * User stakes more than once - user and total weights should update accuratley
     * User stakes more than once in different epochs - weights are updated accurately
     *
     * UNSTAKE
     * Unstaking allows users to Claim their rewards as well
     * Unstake function is  accessible for actual stakers
     * Unstaked users cannot claim any further rewards
     * Staking and Unstaking in same epoch doesn't lead to any rewards
     * User Fees Info is accurately updated after unstake
     *
     *
     */

    describe("🟢 Stake Tests ", function () {
      describe("Staking tests", async () => {
        it("BOB & Alice Stakes(Same Amount) and Harvests together- Should get equal rewards ✅", async function () {
          const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
          const oneEpochs = 1;
          const fiveEpochs = 5;
          const totalPoolFee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
          const perStakerShare = totalPoolFee.div(2);

          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));

          await stakePushTokens(BOBSIGNER, tokensBN(100));
          await passBlockNumers(10000);
          await stakePushTokens(ALICESIGNER, tokensBN(100));
          // Fast Forward 5 more epochs
          await passBlockNumers(fiveEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(ALICESIGNER).harvestAll();

          const bobLastStakedEpoch = await getLastStakedEpoch(BOB);
          const bobLastClaimedEpochId = await getLastRewardClaimedEpoch(BOB);
          const aliceLastStakedEpoch = await getLastStakedEpoch(ALICE);
          const aliceLastClaimedEpochId = await getLastRewardClaimedEpoch(
            ALICE
          );
          const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
          const rewards_alice = await EPNSCoreV1Proxy.usersRewardsClaimed(
            ALICE
          );

          await expect(bobLastStakedEpoch).to.be.equal(oneEpochs + 1);
          await expect(bobLastClaimedEpochId).to.be.equal(
            oneEpochs + fiveEpochs + 1
          );
          await expect(aliceLastStakedEpoch).to.be.equal(oneEpochs + 1);
          await expect(aliceLastClaimedEpochId).to.be.equal(
            oneEpochs + fiveEpochs + 1
          );

          expect(rewards_alice).to.equal(rewards_bob);
        });

        it("BOB stakes abit later than ALice. BOB & Alice Stakes(Same Amount) and Harvests together - they get equal rewards ✅", async function () {
          const oneEpochs = 1;
          const totalPoolFee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();

          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));

          // alice stakes
          await stakePushTokens(ALICESIGNER, tokensBN(100));

          // bob stakes a bit later
          await passBlockNumers(100_000);
          // 20 * 7160
          await stakePushTokens(BOBSIGNER, tokensBN(100));
          await passBlockNumers(oneEpochs * EPOCH_DURATION);

          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(ALICESIGNER).harvestAll();

          const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
          const rewards_alice = await EPNSCoreV1Proxy.usersRewardsClaimed(
            ALICE
          );

          expect(rewards_alice).to.equal(rewards_bob);
        });

        it("BOB stakes at the half of the EPOCH time. Bob gets half the alice rewards ✅", async function () {
          const oneEpochs = 1;
          const totalPoolFee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
          await passBlockNumers(100 * EPOCH_DURATION);

          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));

          // alice stakes
          await stakePushTokens(ALICESIGNER, tokensBN(100));

          // bob stakes a bit later
          await passBlockNumers(10 * 7160);
          await stakePushTokens(BOBSIGNER, tokensBN(100));
          await passBlockNumers(oneEpochs * EPOCH_DURATION);

          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(ALICESIGNER).harvestAll();

          const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
          const rewards_alice = await EPNSCoreV1Proxy.usersRewardsClaimed(
            ALICE
          );

          expect(rewards_alice).to.equal(rewards_bob);
        });
      });

      describe("🟢 unStake Tests ", function () {
        it("Unstaking allows users to Claim their pending rewards ✅", async function () {
          const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
          const oneEpochs = 1;
          const fiveEpochs = 5;
          const totalPoolFee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();

          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await stakePushTokens(BOBSIGNER, tokensBN(100));
          await stakePushTokens(ALICESIGNER, tokensBN(100));
          // Fast Forward 5 epoch - Bob Unstakes
          await passBlockNumers(fiveEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).unstake();
          const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);

          expect(ethers.BigNumber.from(rewards_bob)).to.be.closeTo(
            ethers.BigNumber.from(totalPoolFee.div(2)),
            ethers.utils.parseEther(".000001")
          );
        });

        it("Unstaking function should update User's Detail accurately after unstake ✅", async function () {
          const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
          const oneEpochs = 1;
          const fiveEpochs = 5;
          const totalPoolFee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();

          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await stakePushTokens(BOBSIGNER, tokensBN(100));
          await stakePushTokens(ALICESIGNER, tokensBN(100));
          // Fast Forward 5 epoch - Bob Unstakes
          await passBlockNumers(fiveEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).unstake();

          const bobDetails = await EPNSCoreV1Proxy.userFeesInfo(BOB);
          const currentBlock = await getCurrentBlock();
          await expect(bobDetails.stakedAmount).to.be.equal(0);
          await expect(bobDetails.stakedWeight).to.be.equal(0);
          await expect(bobDetails.lastClaimedBlock).to.be.equal(
            currentBlock.number
          );
        });

        it("Users cannot claim rewards after unstaking ✅", async function () {
          const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
          const oneEpochs = 1;
          const fiveEpochs = 5;
          const totalPoolFee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();

          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await stakePushTokens(BOBSIGNER, tokensBN(100));
          await stakePushTokens(ALICESIGNER, tokensBN(100));
          // Fast Forward 5 epoch - Bob Unstakes
          await passBlockNumers(fiveEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).unstake();

          // Fast Forward 15 epoch - Bob tries to Unstake again
          await passBlockNumers(fiveEpochs * EPOCH_DURATION);
          const tx = EPNSCoreV1Proxy.connect(BOBSIGNER).unstake();

          await expect(tx).to.be.revertedWith(
            "PushCoreV2::unstake: Invalid Caller"
          );
        });

        it("BOB Stakes and Unstakes in same Epoch- Should get ZERO rewards ✅", async function () {
          const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
          const oneEpochs = 1;
          const twoEpochs = 2;
          const totalPoolFee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();

          await passBlockNumers(twoEpochs * EPOCH_DURATION);
          await stakePushTokens(BOBSIGNER, tokensBN(100));
          // Fast Forward 1/2 epoch, lands in same EPOCH more epochs
          await passBlockNumers(EPOCH_DURATION / 2);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).unstake();          

          const bobLastStakedEpoch = await getLastStakedEpoch(BOB);
          const bobLastClaimedEpochId = await getLastRewardClaimedEpoch(BOB);
          const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);

          await expect(rewards_bob).to.be.equal(0);
          await expect(bobLastStakedEpoch).to.be.equal(oneEpochs + twoEpochs);
          await expect(bobLastClaimedEpochId).to.be.equal(oneEpochs + twoEpochs);
        });

        it("Unstaking function should transfer accurate amount of PUSH tokens to User ✅", async function () {
          const oneEpochs = 1;
          const fiveEpochs = 5;

          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await stakePushTokens(BOBSIGNER, tokensBN(100));
          await stakePushTokens(ALICESIGNER, tokensBN(100));
          // Fast Forward 5 epoch - Bob Unstakes
          await passBlockNumers(fiveEpochs * EPOCH_DURATION);
          const bobDetails = await EPNSCoreV1Proxy.userFeesInfo(BOB);

          const bob_balance_before = await PushToken.balanceOf(BOB);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).unstake();
          const bob_balance_after = await PushToken.balanceOf(BOB);

          const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
          const totalClaimableAmount = bobDetails.stakedAmount.add(rewards_bob);
          const bobBalanceIncrease = bob_balance_after.sub(bob_balance_before);

          await expect(bobBalanceIncrease).to.be.equal(totalClaimableAmount);
        });
      });

      describe("🟢 calcEpochRewards Tests: Calculating the accuracy of claimable rewards", function () {
        it("BOB Stakes at EPOCH 1 and Harvests alone- Should get all rewards ✅", async function () {
          const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
          const oneEpochs = 1;
          const fiveEpochs = 5;
          const totalPoolFee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();

          // await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await stakePushTokens(BOBSIGNER, tokensBN(100));
          // Fast Forward 5 more epochs
          await passBlockNumers(fiveEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAll();

          const bobLastStakedEpoch = await getLastStakedEpoch(BOB);
          const bobLastClaimedEpochId = await getLastRewardClaimedEpoch(BOB);
          const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);

          await expect(bobLastStakedEpoch).to.be.equal(oneEpochs);
          await expect(bobLastClaimedEpochId).to.be.equal(fiveEpochs + 1);
          expect(ethers.BigNumber.from(rewards_bob)).to.be.closeTo(
            ethers.BigNumber.from(totalPoolFee),
            ethers.utils.parseEther("0.000001")
          );
        });

        it("BOB Stakes after EPOCH 1 and Harvests alone- Should get all rewards ✅", async function () {
          const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
          const oneEpochs = 1;
          const fiveEpochs = 5;
          const totalPoolFee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();

          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));

          await stakePushTokens(BOBSIGNER, tokensBN(100));
          // Fast Forward 5 more epochs
          await passBlockNumers(fiveEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).daoHarvestPaginated(6);
          const reward_admin = await getAdminRewards();

          const bobLastStakedEpoch = await getLastStakedEpoch(BOB);
          const bobLastClaimedEpochId = await getLastRewardClaimedEpoch(BOB);
          const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);

          await expect(bobLastStakedEpoch).to.be.equal(oneEpochs + 1);
          await expect(bobLastClaimedEpochId).to.be.equal(
            oneEpochs + fiveEpochs + 1
          );

          const expected_reward = parseEther("200").sub(reward_admin);
          expect(ethers.BigNumber.from(rewards_bob)).to.be.closeTo(
            expected_reward,
            ethers.utils.parseEther("0.000001")
          );
        });

        it("BOB & Alice Stakes(Same Amount) and Harvests together- Should get equal rewards ✅", async function () {
          const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
          const oneEpochs = 1;
          const fiveEpochs = 5;

          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));

          await stakePushTokens(BOBSIGNER, tokensBN(100));
          await stakePushTokens(ALICESIGNER, tokensBN(100));
          // Fast Forward 5 more epochs
          await passBlockNumers(fiveEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(ALICESIGNER).harvestAll();

          const bobLastStakedEpoch = await getLastStakedEpoch(BOB);
          const bobLastClaimedEpochId = await getLastRewardClaimedEpoch(BOB);
          const aliceLastStakedEpoch = await getLastStakedEpoch(ALICE);
          const aliceLastClaimedEpochId = await getLastRewardClaimedEpoch(
            ALICE
          );
          const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
          const rewards_alice = await EPNSCoreV1Proxy.usersRewardsClaimed(
            ALICE
          );
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).daoHarvestPaginated(6);
          const adinRew = await getAdminRewards();

          await expect(bobLastStakedEpoch).to.be.equal(oneEpochs + 1);
          await expect(bobLastClaimedEpochId).to.be.equal(
            oneEpochs + fiveEpochs + 1
          );
          await expect(aliceLastStakedEpoch).to.be.equal(oneEpochs + 1);
          await expect(aliceLastClaimedEpochId).to.be.equal(
            oneEpochs + fiveEpochs + 1
          );

          const expectedReward = parseEther("200").sub(adinRew).div(2);

          expect(ethers.BigNumber.from(rewards_bob)).to.be.closeTo(
            expectedReward,
            ethers.utils.parseEther("0.000001")
          );
          expect(ethers.BigNumber.from(rewards_alice)).to.be.closeTo(
            expectedReward,
            ethers.utils.parseEther("0.000001")
          );
        });

        it("4 Users Stakes(Same Amount) and Harvests together- Should get equal rewards ✅", async function () {
          const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
          const oneEpochs = 1;
          const fiveEpochs = 5;

          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));

          await stakePushTokens(BOBSIGNER, tokensBN(100));
          await stakePushTokens(ALICESIGNER, tokensBN(100));
          await stakePushTokens(CHARLIESIGNER, tokensBN(100));
          await stakePushTokens(CHANNEL_CREATORSIGNER, tokensBN(100));

          await passBlockNumers(fiveEpochs * EPOCH_DURATION);
          // // Harvests Push Tokens after 15 blocks, at 16th EPOCH
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(ALICESIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(CHARLIESIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).harvestAll();

          await EPNSCoreV1Proxy.connect(ADMINSIGNER).daoHarvestPaginated(6);
          const adinRew = await getAdminRewards();

          const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
          const rewards_alice = await EPNSCoreV1Proxy.usersRewardsClaimed(
            ALICE
          );
          const rewards_charlie = await EPNSCoreV1Proxy.usersRewardsClaimed(
            CHARLIE
          );
          const rewards_channelCreator =
            await EPNSCoreV1Proxy.usersRewardsClaimed(CHANNEL_CREATOR);
          

          const expectedReward = parseEther("200").sub(adinRew).div(4);

          expect(ethers.BigNumber.from(rewards_bob)).to.be.closeTo(
            expectedReward,
            ethers.utils.parseEther("0.000001")
          );

          expect(ethers.BigNumber.from(rewards_alice)).to.be.closeTo(
            expectedReward,
            ethers.utils.parseEther("0.000001")
          );
          expect(ethers.BigNumber.from(rewards_charlie)).to.be.closeTo(
            expectedReward,
            ethers.utils.parseEther("0.000001")
          );

          expect(ethers.BigNumber.from(rewards_channelCreator)).to.be.closeTo(
            expectedReward,
            ethers.utils.parseEther("0.000001")
          );
        });

        it("4 Users Stakes(Same Amount) and Harvests together- all get same reward✅", async function () {
          const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
          const oneEpochs = 1;
          const fiveEpochs = 5;
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));

          await stakePushTokens(BOBSIGNER, tokensBN(100));
          await stakePushTokens(ALICESIGNER, tokensBN(100));
          await stakePushTokens(CHARLIESIGNER, tokensBN(100));
          await stakePushTokens(CHANNEL_CREATORSIGNER, tokensBN(100));

          await passBlockNumers(fiveEpochs * EPOCH_DURATION);
          // // Harvests Push Tokens after 15 blocks, at 16th EPOCH
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(ALICESIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(CHARLIESIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).harvestAll();

          const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
          const rewards_alice = await EPNSCoreV1Proxy.usersRewardsClaimed(
            ALICE
          );
          const rewards_charlie = await EPNSCoreV1Proxy.usersRewardsClaimed(
            CHARLIE
          );
          const rewards_channelCreator =
            await EPNSCoreV1Proxy.usersRewardsClaimed(CHANNEL_CREATOR);

          await expect(rewards_alice).to.be.equal(rewards_bob);
          await expect(rewards_charlie).to.be.equal(rewards_alice);
          await expect(rewards_channelCreator).to.be.equal(rewards_charlie);
        });

        it("4 Users Stakes different amount and Harvests together- Last Claimer & Major Staker Gets More ✅", async function () {
          const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
          const oneEpochs = 2;
          const fiveEpochs = 10;
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));

          await stakePushTokens(BOBSIGNER, tokensBN(100));
          await stakePushTokens(ALICESIGNER, tokensBN(200));
          await stakePushTokens(CHARLIESIGNER, tokensBN(300));
          await stakePushTokens(CHANNEL_CREATORSIGNER, tokensBN(400));

          await passBlockNumers(fiveEpochs * EPOCH_DURATION);
          // // Harvests Push Tokens after 15 blocks, at 16th EPOCH
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(ALICESIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(CHARLIESIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).harvestAll();

          const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
          const rewards_alice = await EPNSCoreV1Proxy.usersRewardsClaimed(
            ALICE
          );
          const rewards_charlie = await EPNSCoreV1Proxy.usersRewardsClaimed(
            CHARLIE
          );
          const rewards_channelCreator =
            await EPNSCoreV1Proxy.usersRewardsClaimed(CHANNEL_CREATOR);

          await expect(rewards_alice).to.be.gt(rewards_bob);
          await expect(rewards_charlie).to.be.gt(rewards_alice);
          await expect(rewards_channelCreator).to.be.gt(rewards_charlie);
        });
        // Expected Result = BOB_REWARDS > Alice > Charlie > Channel_CREATOR
        it("TEST CHECKS-5.1: 4 Users Stakes different amount and Harvests together- Last Claimer & Major Staker Gets More(First Staker stakes the MOST) ✅", async function () {
          const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
          const oneEpochs = 2;
          const fiveEpochs = 10;
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));

          await stakePushTokens(BOBSIGNER, tokensBN(400));
          await stakePushTokens(ALICESIGNER, tokensBN(300));
          await stakePushTokens(CHARLIESIGNER, tokensBN(200));
          await stakePushTokens(CHANNEL_CREATORSIGNER, tokensBN(100));

          await passBlockNumers(fiveEpochs * EPOCH_DURATION);
          // // Harvests Push Tokens after 15 blocks, at 16th EPOCH
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(ALICESIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(CHARLIESIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).harvestAll();

          const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
          const rewards_alice = await EPNSCoreV1Proxy.usersRewardsClaimed(
            ALICE
          );
          const rewards_charlie = await EPNSCoreV1Proxy.usersRewardsClaimed(
            CHARLIE
          );
          const rewards_channelCreator =
            await EPNSCoreV1Proxy.usersRewardsClaimed(CHANNEL_CREATOR);

          await expect(rewards_charlie).to.be.gt(rewards_channelCreator);
          await expect(rewards_alice).to.be.gt(rewards_charlie);
          await expect(rewards_bob).to.be.gt(rewards_alice);
        });

        it("4 Users Stakes(Same Amount) & Harvests after a gap of 2 epochs each - All get same rewards Rewards ✅", async function () {
          const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
          const twoEpochs = 2;
          const fiveEpochs = 5;
          await passBlockNumers(twoEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));

          await stakePushTokens(BOBSIGNER, tokensBN(100));
          await stakePushTokens(ALICESIGNER, tokensBN(100));
          await stakePushTokens(CHARLIESIGNER, tokensBN(100));
          await stakePushTokens(CHANNEL_CREATORSIGNER, tokensBN(100));

          // Bob Harvests after EPOCH 5+2+1 = 8
          await passBlockNumers(fiveEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAll();
          // Alice Harvests after EPOCH 11
          await passBlockNumers(twoEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ALICESIGNER).harvestAll();
          // Charlie Harvests after EPOCH 13
          await passBlockNumers(twoEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(CHARLIESIGNER).harvestAll();
          // ChannelCreator Harvests after EPOCH 15
          await passBlockNumers(twoEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).harvestAll();

          const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
          const rewards_alice = await EPNSCoreV1Proxy.usersRewardsClaimed(
            ALICE
          );
          const rewards_charlie = await EPNSCoreV1Proxy.usersRewardsClaimed(
            CHARLIE
          );
          const rewards_channelCreator =
            await EPNSCoreV1Proxy.usersRewardsClaimed(CHANNEL_CREATOR);

          await expect(rewards_alice).to.equal(rewards_bob);
          await expect(rewards_charlie).to.equal(rewards_alice);
          await expect(rewards_channelCreator).to.equal(rewards_charlie);
        });

        it("BOB Stakes and Harvests alone in same Epoch- Should get ZERO rewards ✅", async function () {
          const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
          const twoEpochs = 2;
          const totalPoolFee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();

          await passBlockNumers(twoEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));

          await stakePushTokens(BOBSIGNER, tokensBN(100));
          // Fast Forward 1/2 epoch, lands in same EPOCH more epochs
          await passBlockNumers(EPOCH_DURATION / 2);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAll();

          const bobLastStakedEpoch = await getLastStakedEpoch(BOB);
          const bobLastClaimedEpochId = await getLastRewardClaimedEpoch(BOB);
          const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);

          await expect(rewards_bob).to.be.equal(0);
          await expect(bobLastStakedEpoch).to.be.equal(twoEpochs + 1);
          await expect(bobLastClaimedEpochId).to.be.equal(twoEpochs + 1);
        });
      });

      describe("🟢 Harvesting Rewards Tests ", function () {
        it("Bob stakes at epoch 2 and claims at epoch 9 using harvestAll()", async function () {
          const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
          const oneEpochs = 1;

          //pass 1 epoch add pool fees
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));

          //pass one epoch bob stakes
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await stakePushTokens(BOBSIGNER, tokensBN(100));

          //pass 3epoch bob harvests
          await passBlockNumers(3 * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAll();
          
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).daoHarvestPaginated(5);
          const rewards_admin = await getAdminRewards();
          

          //console rewards of bob
          const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);

          const expectedReward = parseEther("200").sub(rewards_admin)
          expect(ethers.BigNumber.from(rewards_bob)).to.be.closeTo(
            expectedReward,
            ethers.utils.parseEther("0.000001")
          );

        });

        it("Bob stakes at epoch 2 and harvests at epoch 9 i) epoch 1 to 2 and again at epoch 15 ii) epoch 3 to 9", async function () {
          const oneEpochs = 1;
          //pass 1 epoch add pool fees
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));

          //pass one epoch bob stakes
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await stakePushTokens(BOBSIGNER, tokensBN(100));

          //pass 3epoch bob harvests
          await passBlockNumers(3 * EPOCH_DURATION);
          await passBlockNumers(6 * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).daoHarvestPaginated(11);

          //console rewards of bob
          const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
          const rewards_admin = await getAdminRewards();
          const expectedReward = parseEther("200").sub(rewards_admin);
          expect(ethers.BigNumber.from(rewards_bob)).to.be.closeTo(
            expectedReward,
            ethers.utils.parseEther("0.000001")
          );
        });
      });

      describe("🟢 Pagination test ", function () {
        const oneEpochs = 1;
        it("allows staker to harvest with harvestInPeriod() method", async function () {
          //pass 1 epoch add pool fees
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(100));

          //pass one epoch bob stakes
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await stakePushTokens(BOBSIGNER, tokensBN(100));

          await passBlockNumers(3 * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestPaginated(5);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).daoHarvestPaginated(5);
          const rewards_admin = await getAdminRewards();

          const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);

          expect(ethers.BigNumber.from(rewards_bob)).to.be.closeTo(
            ethers.utils.parseEther("100").sub(rewards_admin),
            ethers.utils.parseEther("0.0000001")
          );
        });

        it("avoids harvesting the future epochs", async function () {
          //pass 1 epoch add pool fees
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(100));

          //pass one epoch bob stakes
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await stakePushTokens(BOBSIGNER, tokensBN(100));

          await passBlockNumers(3 * EPOCH_DURATION);
          const tx = EPNSCoreV1Proxy.connect(BOBSIGNER).harvestPaginated(10);

          await expect(tx).to.be.revertedWith(
            "PushCoreV2::harvestPaginated::Invalid _tillEpoch w.r.t currentEpoch"
          );
        });

        it("avoids harvesting same epochs multiple time", async function () {
          //pass 1 epoch add pool fees
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(100));

          //pass one epoch bob stakes
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await stakePushTokens(BOBSIGNER, tokensBN(100));

          await passBlockNumers(3 * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestPaginated(3);
          const tx = EPNSCoreV1Proxy.connect(BOBSIGNER).harvestPaginated(3);
          await expect(tx).to.be.revertedWith(
            "PushCoreV2::harvestPaginated::Invalid _tillEpoch w.r.t nextFromEpoch"
          );
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestPaginated(5);
        });

        it("allows harvesting with for epoch ranges", async function () {
          // Epoch passes
          await passBlockNumers(oneEpochs * EPOCH_DURATION);

          // Fees gets added & BOB stakes
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(100));
          await stakePushTokens(BOBSIGNER, tokensBN(100));
          await passBlockNumers(oneEpochs * EPOCH_DURATION);

          // More fees added
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(100));
          await passBlockNumers(oneEpochs * EPOCH_DURATION);

          // More fees added
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(100));
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await passBlockNumers(oneEpochs * EPOCH_DURATION);

          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestPaginated(5);

          // harvesting time
          const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);

          await EPNSCoreV1Proxy.connect(ADMINSIGNER).daoHarvestPaginated(5);
          const rewards_admin = await getAdminRewards();


          expect(ethers.BigNumber.from(rewards_bob)).to.be.closeTo(
            ethers.utils.parseEther("300").sub(rewards_admin),
            ethers.utils.parseEther("0.0000001")
          );
        });

        it("allows cummulative harvesting with epoch ranges", async function () {
          // Epoch passes
          await passBlockNumers(oneEpochs * EPOCH_DURATION);

          // Fees gets added & BOB stakes
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(100));
          await stakePushTokens(BOBSIGNER, tokensBN(100));
          await passBlockNumers(oneEpochs * EPOCH_DURATION);

          // More fees added
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(100));
          await passBlockNumers(oneEpochs * EPOCH_DURATION);

          // More fees added
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(100));
          await passBlockNumers(oneEpochs * EPOCH_DURATION);

          // More fees added
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(100));
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestPaginated(3);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestPaginated(5);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestPaginated(7);

          // harvesting time
          const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).daoHarvestPaginated(7);
          const rewards_admin = await getAdminRewards();


          expect(ethers.BigNumber.from(rewards_bob)).to.be.closeTo(
            ethers.utils.parseEther("400").sub(rewards_admin),
            ethers.utils.parseEther("0.0000001")
          );
        });

        it("yields same reward with `harvestInPeriod` & `harvestAll`", async function () {
          // Epoch passes
          await passBlockNumers(oneEpochs * EPOCH_DURATION);

          // Fees gets added & BOB stakes
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(100));
          await stakePushTokens(ALICESIGNER, tokensBN(100));
          await stakePushTokens(BOBSIGNER, tokensBN(100));
          await passBlockNumers(oneEpochs * EPOCH_DURATION);

          // More fees added
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(100));
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await passBlockNumers(oneEpochs * EPOCH_DURATION);

          // More fees added
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(100));
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await passBlockNumers(oneEpochs * EPOCH_DURATION);

          // More fees added
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(100));
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await passBlockNumers(oneEpochs * EPOCH_DURATION);

          // harvesting time
          await EPNSCoreV1Proxy.connect(ALICESIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestPaginated(3);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestPaginated(5);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestPaginated(8);

          const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
          const rewards_alice = await EPNSCoreV1Proxy.usersRewardsClaimed(
            ALICE
          );

          await EPNSCoreV1Proxy.connect(ADMINSIGNER).daoHarvestPaginated(8);
          const rewards_admin = await getAdminRewards();

          // TODO: fix with the constant block number
          expect(ethers.BigNumber.from(rewards_bob)).to.be.closeTo(
            ethers.utils.parseEther("400").sub(rewards_admin).div(2),
            ethers.utils.parseEther("1")
          );

          // TODO: fix with the constant block number
          expect(ethers.BigNumber.from(rewards_alice)).to.be.closeTo(
            ethers.utils.parseEther("400").sub(rewards_admin).div(2),
            ethers.utils.parseEther("1")
          );
        });

        it("should not yield rewards if rewardpool is void", async function () {
          //pass 1 epoch add pool fees
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(100));

          //pass one epoch bob stakes
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await stakePushTokens(BOBSIGNER, tokensBN(100));

          await passBlockNumers(3 * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestPaginated(5);

          const rewards_bob_1 = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
          await passBlockNumers(3 * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestPaginated(8);
          const rewards_bob_2 = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);

          expect(rewards_bob_2).to.equal(rewards_bob_1);
        });
      });

      describe("🟢 DAO harvest tests", function () {
        const oneEpochs = 1;
        it("allows admin to harvest", async function () {
          //pass 1 epoch add pool fees
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(100));
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).daoHarvestPaginated(4);

          const rewards_admin = await EPNSCoreV1Proxy.usersRewardsClaimed(
            EPNSCoreV1Proxy.address
          );

          expect(ethers.BigNumber.from(rewards_admin)).to.equal(
            ethers.utils.parseEther("100")
          );
        });

        it("yields `0` if no pool funds added", async function () {
          //pass 1 epoch add pool fees
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).daoHarvestPaginated(2);
          const rewards_admin = await EPNSCoreV1Proxy.usersRewardsClaimed(
            EPNSCoreV1Proxy.address
          );

          expect(ethers.BigNumber.from(rewards_admin)).to.equal(
            ethers.utils.parseEther("0")
          );
        });

        it("allows only admin to harvest", async function () {
          //pass 1 epoch add pool fees
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(100));

          const tx = EPNSCoreV1Proxy.connect(ALICESIGNER).daoHarvestPaginated(2);
          
          await expect(tx).to.be.revertedWith(
            "PushCoreV2::onlyGovernance: Invalid Caller"
          );

          await EPNSCoreV1Proxy.connect(ADMINSIGNER).daoHarvestPaginated(2);
          const rewards_admin = await EPNSCoreV1Proxy.usersRewardsClaimed(
            EPNSCoreV1Proxy.address
          );
          expect(ethers.BigNumber.from(rewards_admin)).to.equal(
            ethers.utils.parseEther("100")
          );
        });

        it("admin rewards and user rewards match the pool fees", async function () {
          //pass 1 epoch add pool fees
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(100));

          //pass one epoch bob stakes
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await stakePushTokens(BOBSIGNER, tokensBN(100));

          await passBlockNumers(3 * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestPaginated(5);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).daoHarvestPaginated(5);

          const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
          const rewards_admin = await EPNSCoreV1Proxy.usersRewardsClaimed(
            EPNSCoreV1Proxy.address
          );

          expect(
            ethers.BigNumber.from(rewards_bob.add(rewards_admin))
          ).to.be.closeTo(
            ethers.utils.parseEther("100"),
            ethers.utils.parseEther("0.00000000001")
          );
        });

        it("dao gets all rewards if no one stakes", async function () {
          //pass 1 epoch add pool fees
          // Admin stakes ---> intializeStake ---> Admin stakes 1 PSUH
          // 300 PUSH is added to the pool funds
          // 4 epoch passess --- funds collected 300 PUSH
          // Not admin dao harvest ---> 1 to 4 epoch
          // Admin/DAO should get 300 PUSH
          // But getting `0`
          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(100));

          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(100));

          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(100));

          await passBlockNumers(oneEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).daoHarvestPaginated(4);

          const rewards_admin = await EPNSCoreV1Proxy.usersRewardsClaimed(
            EPNSCoreV1Proxy.address
          );

          expect(ethers.BigNumber.from(rewards_admin)).to.equal(
            ethers.utils.parseEther("300")
          );
        });
      });

      /**
       * Harvest And Reward Temp Tests - To be Categorized in specific test Case boxes later
       * -- LEVEL 1 Basic Tests --
       * TEST CHECK-1: BOB Stakes and Harvests alone- Should get all rewards in Pool ✅
       * TEST CHECK-2: BOB & Alice Stakes(Same Amount) and Harvests together- Should get equal rewards ✅
       * TEST CHECK-3: 4 Users Stakes(Same Amount) and Harvests together- Should get equal rewards ✅
       * TEST CHECK-4: 4 Users Stakes(Same Amount) and Harvests together(Same Epoch, Diff blocks)- Last Claimer Gets More Rewards✅
       * TEST CHECKS-5: 4 Users Stakes different amount and Harvests together- Last Claimer & Major Staker Gets More Rewards ✅
       *
       * -- LEVEL 2 Tests --
       * TEST CHECKS-6: 4 Users Stakes(Same Amount) & Harvests after a gap of 2 epochs each - Last Claimer should get More Rewards ✅
       * TEST CHECKS-7: 4 Users Stakes(Same Amount) after a GAP of 2 epochs each & Harvests together - Last Claimer should get More Rewards ✅
       * TEST CHECKS-8: Stakers Stakes again in same EPOCH - Claimable Reward Calculation should be accurate ✅
       * TEST CHECKS-8.1: Stakers Stakes again in Same EPOCH with other pre-existing stakers - Claimable Reward Calculation should be accurate for all ✅
       * TEST CHECKS-9: Stakers Stakes again in Different EPOCH - Claimable Reward Calculation should be accurate ✅
       * TEST CHECKS-9.1: Stakers Stakes again in Different EPOCH with pre-existing stakers - Claimable Reward Calculation should be accurate for all ✅
       */
      describe("🟢 LEVEL-2: Tests on Stake N Rewards", function () {
        it("TEST CHECKS-7: 4 Users Stakes(Same Amount) after a GAP of 2 epochs each & Harvests together - Last Claimer should get More Rewards ✅", async function () {
          const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
          const twoEpochs = 2;
          const fiveEpochs = 5;

          await passBlockNumers(twoEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));

          await stakePushTokens(BOBSIGNER, tokensBN(100));

          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));
          await passBlockNumers(twoEpochs * EPOCH_DURATION);
          await stakePushTokens(ALICESIGNER, tokensBN(100));

          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));
          await passBlockNumers(twoEpochs * EPOCH_DURATION);
          await stakePushTokens(CHARLIESIGNER, tokensBN(100));

          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));
          await passBlockNumers(twoEpochs * EPOCH_DURATION);
          await stakePushTokens(CHANNEL_CREATORSIGNER, tokensBN(100));

          await passBlockNumers(fiveEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(ALICESIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(CHARLIESIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).harvestAll();

          const bob_ClaimedBlock = await getLastStakedEpoch(BOB);
          const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);

          const alice_ClaimedBlock = await getLastStakedEpoch(ALICE);
          const rewards_alice = await EPNSCoreV1Proxy.usersRewardsClaimed(
            ALICE
          );

          const charlie_ClaimedBlock = await getLastStakedEpoch(CHARLIE);
          const rewards_charlie = await EPNSCoreV1Proxy.usersRewardsClaimed(
            CHARLIE
          );

          const channeCreator_ClaimedBlock = await getLastStakedEpoch(
            CHANNEL_CREATOR
          );
          const rewards_channelCreator =
            await EPNSCoreV1Proxy.usersRewardsClaimed(CHANNEL_CREATOR);

          await expect(rewards_bob).to.be.gt(rewards_alice);
          await expect(rewards_alice).to.be.gt(rewards_charlie);
          await expect(rewards_charlie).to.be.gt(rewards_channelCreator);

          console.log(
            `BOB Staked at EPOCH-${bob_ClaimedBlock.toNumber()} and got ${rewards_bob.toString()} Rewards`
          );
          console.log(
            `ALICE Staked at EPOCH-${alice_ClaimedBlock.toNumber()} and got ${rewards_alice.toString()} Rewards`
          );
          console.log(
            `CHARLIE Staked at EPOCH-${charlie_ClaimedBlock.toNumber()} and got ${rewards_charlie.toString()} Rewards`
          );
          console.log(
            `CHANNEL_CREATOR Staked at EPOCH-${channeCreator_ClaimedBlock.toNumber()} and got ${rewards_channelCreator.toString()} Rewards`
          );
        });

        it("TEST CHECKS-8: Stakers Stakes again in same EPOCH - Claimable Reward Calculation should be accurate ✅", async function () {
          const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
          const twoEpochs = 2;
          const fiveEpochs = 5;

          await passBlockNumers(twoEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));
          await stakePushTokens(BOBSIGNER, tokensBN(100));
          await stakePushTokens(BOBSIGNER, tokensBN(100));

          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));
          await passBlockNumers(twoEpochs * EPOCH_DURATION);
          await stakePushTokens(ALICESIGNER, tokensBN(100));
          await stakePushTokens(ALICESIGNER, tokensBN(100));

          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));
          await passBlockNumers(twoEpochs * EPOCH_DURATION);
          await stakePushTokens(CHARLIESIGNER, tokensBN(100));
          await stakePushTokens(CHARLIESIGNER, tokensBN(100));

          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));
          await passBlockNumers(twoEpochs * EPOCH_DURATION);
          await stakePushTokens(CHANNEL_CREATORSIGNER, tokensBN(100));
          await stakePushTokens(CHANNEL_CREATORSIGNER, tokensBN(100));

          await passBlockNumers(fiveEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(ALICESIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(CHARLIESIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).harvestAll();

          const bob_ClaimedBlock = await getLastStakedEpoch(BOB);
          const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);

          const alice_ClaimedBlock = await getLastStakedEpoch(ALICE);
          const rewards_alice = await EPNSCoreV1Proxy.usersRewardsClaimed(
            ALICE
          );

          const charlie_ClaimedBlock = await getLastStakedEpoch(CHARLIE);
          const rewards_charlie = await EPNSCoreV1Proxy.usersRewardsClaimed(
            CHARLIE
          );

          const channeCreator_ClaimedBlock = await getLastStakedEpoch(
            CHANNEL_CREATOR
          );
          const rewards_channelCreator =
            await EPNSCoreV1Proxy.usersRewardsClaimed(CHANNEL_CREATOR);

          await expect(rewards_bob).to.be.gt(rewards_alice);
          await expect(rewards_alice).to.be.gt(rewards_charlie);
          await expect(rewards_charlie).to.be.gt(rewards_channelCreator);

          console.log(
            `BOB Staked at EPOCH-${bob_ClaimedBlock.toNumber()} and got ${rewards_bob.toString()} Rewards`
          );
          console.log(
            `ALICE Staked at EPOCH-${alice_ClaimedBlock.toNumber()} and got ${rewards_alice.toString()} Rewards`
          );
          console.log(
            `CHARLIE Staked at EPOCH-${charlie_ClaimedBlock.toNumber()} and got ${rewards_charlie.toString()} Rewards`
          );
          console.log(
            `CHANNEL_CREATOR Staked at EPOCH-${channeCreator_ClaimedBlock.toNumber()} and got ${rewards_channelCreator.toString()} Rewards`
          );
        });

        it("TEST CHECKS-8.1: Stakers Stakes again in Same EPOCH with other pre-existing stakers - Claimable Reward Calculation should be accurate for all", async function () {
          const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
          const twoEpochs = 2;
          const fiveEpochs = 5;

          await passBlockNumers(twoEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));

          await stakePushTokens(BOBSIGNER, tokensBN(100));

          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));
          await passBlockNumers(twoEpochs * EPOCH_DURATION);
          await stakePushTokens(ALICESIGNER, tokensBN(100));
          await stakePushTokens(BOBSIGNER, tokensBN(100));

          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));
          await passBlockNumers(twoEpochs * EPOCH_DURATION);
          await stakePushTokens(CHARLIESIGNER, tokensBN(100));
          await stakePushTokens(ALICESIGNER, tokensBN(100));

          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));
          await passBlockNumers(twoEpochs * EPOCH_DURATION);
          await stakePushTokens(CHANNEL_CREATORSIGNER, tokensBN(100));
          await stakePushTokens(CHARLIESIGNER, tokensBN(100));

          await passBlockNumers(fiveEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(ALICESIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(CHARLIESIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).harvestAll();

          const bob_ClaimedBlock = await getLastStakedEpoch(BOB);
          const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);

          const alice_ClaimedBlock = await getLastStakedEpoch(ALICE);
          const rewards_alice = await EPNSCoreV1Proxy.usersRewardsClaimed(
            ALICE
          );

          const charlie_ClaimedBlock = await getLastStakedEpoch(CHARLIE);
          const rewards_charlie = await EPNSCoreV1Proxy.usersRewardsClaimed(
            CHARLIE
          );

          const channeCreator_ClaimedBlock = await getLastStakedEpoch(
            CHANNEL_CREATOR
          );
          const rewards_channelCreator =
            await EPNSCoreV1Proxy.usersRewardsClaimed(CHANNEL_CREATOR);

          await expect(rewards_bob).to.be.gt(rewards_alice);
          await expect(rewards_alice).to.be.gt(rewards_charlie);
          await expect(rewards_charlie).to.be.gt(rewards_channelCreator);

          console.log(
            `BOB Staked at EPOCH-${bob_ClaimedBlock.toNumber()} and got ${rewards_bob.toString()} Rewards`
          );
          console.log(
            `ALICE Staked at EPOCH-${alice_ClaimedBlock.toNumber()} and got ${rewards_alice.toString()} Rewards`
          );
          console.log(
            `CHARLIE Staked at EPOCH-${charlie_ClaimedBlock.toNumber()} and got ${rewards_charlie.toString()} Rewards`
          );
          console.log(
            `CHANNEL_CREATOR Staked at EPOCH-${channeCreator_ClaimedBlock.toNumber()} and got ${rewards_channelCreator.toString()} Rewards`
          );
        });

        it("TEST CHECKS-9: Stakers Stakes again in Different EPOCH - Claimable Reward Calculation should be accurate", async function () {
          const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
          const twoEpochs = 2;
          const fiveEpochs = 5;

          await passBlockNumers(twoEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));

          await stakePushTokens(BOBSIGNER, tokensBN(100));

          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));
          await passBlockNumers(twoEpochs * EPOCH_DURATION);
          await stakePushTokens(BOBSIGNER, tokensBN(100));

          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));
          await passBlockNumers(twoEpochs * EPOCH_DURATION);
          await stakePushTokens(BOBSIGNER, tokensBN(100));

          await passBlockNumers(fiveEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAll();

          const bob_ClaimedBlock = await getLastStakedEpoch(BOB);
          const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);

          // await expect(rewards_bob).to.be.gt(rewards_alice);
          // await expect(rewards_alice).to.be.gt(rewards_charlie);
          // await expect(rewards_charlie).to.be.gt(rewards_channelCreator);

          console.log(
            `BOB Staked at EPOCH-${bob_ClaimedBlock.toNumber()} and got ${rewards_bob.toString()} Rewards`
          );
        });

        it("TEST CHECKS-9.1: Stakers Stakes again in Different EPOCH with pre-existing stakers - Claimable Reward Calculation should be accurate for all ✅", async function () {
          const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
          const twoEpochs = 2;
          const fiveEpochs = 5;

          await passBlockNumers(twoEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));

          await stakePushTokens(BOBSIGNER, tokensBN(100));

          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));
          await passBlockNumers(twoEpochs * EPOCH_DURATION);
          await stakePushTokens(BOBSIGNER, tokensBN(100));
          await stakePushTokens(ALICESIGNER, tokensBN(100));
          await stakePushTokens(CHARLIESIGNER, tokensBN(100));

          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));
          await passBlockNumers(twoEpochs * EPOCH_DURATION);
          await stakePushTokens(BOBSIGNER, tokensBN(100));
          await stakePushTokens(CHANNEL_CREATORSIGNER, tokensBN(100));

          await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));
          await passBlockNumers(twoEpochs * EPOCH_DURATION);
          await stakePushTokens(BOBSIGNER, tokensBN(100));

          await passBlockNumers(fiveEpochs * EPOCH_DURATION);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(ALICESIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(CHARLIESIGNER).harvestAll();
          await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).harvestAll();

          const bob_ClaimedBlock = await getLastStakedEpoch(BOB);
          const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);

          const alice_ClaimedBlock = await getLastStakedEpoch(ALICE);
          const rewards_alice = await EPNSCoreV1Proxy.usersRewardsClaimed(
            ALICE
          );

          const charlie_ClaimedBlock = await getLastStakedEpoch(CHARLIE);
          const rewards_charlie = await EPNSCoreV1Proxy.usersRewardsClaimed(
            CHARLIE
          );

          const channeCreator_ClaimedBlock = await getLastStakedEpoch(
            CHANNEL_CREATOR
          );
          const rewards_channelCreator =
            await EPNSCoreV1Proxy.usersRewardsClaimed(CHANNEL_CREATOR);

          // await expect(rewards_bob).to.be.gt(rewards_alice);
          // await expect(rewards_alice).to.be.gt(rewards_charlie);
          // await expect(rewards_charlie).to.be.gt(rewards_channelCreator);

          console.log(
            `BOB Staked at EPOCH-${bob_ClaimedBlock.toNumber()} and got ${rewards_bob.toString()} Rewards`
          );
          console.log(
            `ALICE Staked at EPOCH-${alice_ClaimedBlock.toNumber()} and got ${rewards_alice.toString()} Rewards`
          );
          console.log(
            `CHARLIE Staked at EPOCH-${charlie_ClaimedBlock.toNumber()} and got ${rewards_charlie.toString()} Rewards`
          );
          console.log(
            `CHANNEL_CREATOR Staked at EPOCH-${channeCreator_ClaimedBlock.toNumber()} and got ${rewards_channelCreator.toString()} Rewards`
          );
        });

        it("TEST CHECKS-10: Staking and Unstaking at Same Epoch should not lead to increase in rewards-(for previously staked users)✅", async function () {
          // const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
          const stakeAmount = tokensBN(100);
          const bobDetails = await EPNSCoreV1Proxy.userFeesInfo(BOB);
          const userWeight = await bobDetails.stakedWeight;
          expect(userWeight).to.be.equal(0);
          const fourEpochs = 4;
          // Bob Stakes at EPOCH 1 first
          await stakePushTokens(BOBSIGNER, stakeAmount);
          // At epoch 5, BOB stakes again and tries to unstake all his stake.
          await passBlockNumers(fourEpochs * EPOCH_DURATION);
          await stakePushTokens(BOBSIGNER, stakeAmount);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).unstake();

          const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
          console.log("Rewards Bob", rewards_bob.toString());
        });
      });
      /**Test Cases Ends Here **/
    });
  });
});