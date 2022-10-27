const { ethers, waffle } = require("hardhat");

const { tokensBN } = require("../../helpers/utils");

const { epnsContractFixture, tokenFixture } = require("../common/fixtures");
const { expect } = require("../common/expect");
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

    ({ MOCKDAI, ADAI } = await loadFixture(tokenFixture));
  });

  /***
   * CHECKPOINTS TO CONSIDER WHILE TESTING -> Specific CLAIM Simulations
   * ------------------------------------------
   * Consider total 5 different Stakers -> A, B, C, D, E -> All Staked 100 Tokens
   * 1. Case: Multiple Users claiming reward at different Blocks.
   *    Expectations: One who holds more, gets more rewards
   *
   * 2. Case: User A, B and C claims for a week and then User D and E enters the Staking Pool.
   *    Expectations: Rewards should still be distributed fairly among all users
   *
   * 3. Case: User A and B claims after every 500 blocks for 2 days but C and D claims only once after 2 days.
   *    Expectations: All should receiev equal rewards after 2 days.
   *
   * 4. Case: User A and B starts with 100 staked tokens at a specific block. After 3 days, A increases Stake to 200. Both withdraws after 1 week.
   *    Expectations:  Rewards should be adequate and mathematically correct
   *
   * 5. Multiple users trying to Claim in Same Transaction
   */
  describe("EPNS CORE: CLAIM REWARD TEST-ReardRate Procedure", () => {
    const CHANNEL_TYPE = 2;
    const TEST_CHANNEL_CTX = ethers.utils.toUtf8Bytes(
      "test-channel-hello-world"
    );

    beforeEach(async function () {
      await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(
        EPNSCommV1Proxy.address
      );
      await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(
        EPNSCoreV1Proxy.address
      );

      await PushToken.transfer(
        EPNSCoreV1Proxy.address,
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10)
      );
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

      await PushToken.connect(ALICESIGNER).setHolderDelegation(
        EPNSCoreV1Proxy.address,
        true
      );
    });

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

    const jumpToBlockNumber = async (blockNumber) => {
      blockNumber = blockNumber.toNumber();
      const currentBlock = await ethers.provider.getBlock("latest");
      const numBlockToIncrease = blockNumber - currentBlock.number;
      const blockIncreaseHex = `0x${numBlockToIncrease.toString(16)}`;
      await ethers.provider.send("hardhat_mine", [blockIncreaseHex]);
    };

    it.skip("Total Pool_Fee should be distrubuted adequately after a DAILY Iteration of CLAIM rewards", async function () {
      const bobClaim_before = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
      const aliceClaim_before = await EPNSCoreV1Proxy.usersRewardsClaimed(
        ALICE
      );

      const rewardValue = tokensBN(40);
      await EPNSCoreV1Proxy.setRewardRate(rewardValue);

      await createChannel(ALICESIGNER);
      await createChannel(BOBSIGNER);
      await createChannel(CHARLIESIGNER);
      await createChannel(CHANNEL_CREATORSIGNER);
      await stakePushTokens(BOBSIGNER, tokensBN(100));
      await stakePushTokens(ALICESIGNER, tokensBN(100));
      await stakePushTokens(CHARLIESIGNER, tokensBN(100));
      await stakePushTokens(CHANNEL_CREATORSIGNER, tokensBN(100));

      const totalPool_Fee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
      const stakeStartBlock = await EPNSCoreV1Proxy.stakeStartTime();
      // All Stakers Claiming after First Day

      const [BOB_BLOCK, ALICE_BLOCK, CHARLIE_BLOCK, CHANNEL_CREATOR_BLOCK] = [
        stakeStartBlock.add(86400),
        stakeStartBlock.add(86405),
        stakeStartBlock.add(86410),
        stakeStartBlock.add(86415),
      ];
      await jumpToBlockNumber(BOB_BLOCK.sub(1));
      const tx_bob = await EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards();
      await jumpToBlockNumber(ALICE_BLOCK.sub(1));
      const tx_alice = await EPNSCoreV1Proxy.connect(
        ALICESIGNER
      ).claimRewards();
      await jumpToBlockNumber(CHARLIE_BLOCK.sub(1));
      const tx_charlie = await EPNSCoreV1Proxy.connect(
        CHARLIESIGNER
      ).claimRewards();
      await jumpToBlockNumber(CHANNEL_CREATOR_BLOCK.sub(1));
      const tx_channelCreator = await EPNSCoreV1Proxy.connect(
        CHANNEL_CREATORSIGNER
      ).claimRewards();

      const bobClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
      const aliceClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
      const charlieClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(
        CHARLIE
      );
      const channelCreatorClaim_after =
        await EPNSCoreV1Proxy.usersRewardsClaimed(CHANNEL_CREATOR);

      const totalPool_Fee_after = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
      console.log(
        "\n---------------Starting First Claim with 4 total Stakers----------------------------"
      );
      console.log("Total Pool Fee", totalPool_Fee.toString());
      console.log(
        "Total Pool Fee After First Claim",
        totalPool_Fee_after.toString()
      );
      console.log("\n");
      console.log(
        `Bob Claimed ${bobClaim_after.toString()} tokens at Block number ${
          tx_bob.blockNumber
        }`
      );
      console.log(
        `Alice Claimed ${aliceClaim_after.toString()} tokens at Block number ${
          tx_alice.blockNumber
        }`
      );
      console.log(
        `Charlie Claimed ${charlieClaim_after.toString()} tokens at Block number ${
          tx_charlie.blockNumber
        }`
      );
      console.log(
        `ChannelCreator Claimed ${channelCreatorClaim_after.toString()} tokens at Block number ${
          tx_channelCreator.blockNumber
        }`
      );

      // STARTING 2nd CLAIM
      const [
        BOB_BLOCK_2nd,
        ALICE_BLOCK_2nd,
        CHARLIE_BLOCK_2nd,
        CHANNEL_CREATOR_BLOCK_2nd,
      ] = [
        stakeStartBlock.add(172800),
        stakeStartBlock.add(172805),
        stakeStartBlock.add(172810),
        stakeStartBlock.add(172815),
      ];
      await jumpToBlockNumber(BOB_BLOCK_2nd.sub(1));
      const tx_bob_2nd = await EPNSCoreV1Proxy.connect(
        BOBSIGNER
      ).claimRewards();
      await jumpToBlockNumber(ALICE_BLOCK_2nd.sub(1));
      const tx_alice_2nd = await EPNSCoreV1Proxy.connect(
        ALICESIGNER
      ).claimRewards();
      await jumpToBlockNumber(CHARLIE_BLOCK_2nd.sub(1));
      const tx_charlie_2nd = await EPNSCoreV1Proxy.connect(
        CHARLIESIGNER
      ).claimRewards();
      await jumpToBlockNumber(CHANNEL_CREATOR_BLOCK_2nd.sub(1));
      const tx_channelCreator_2nd = await EPNSCoreV1Proxy.connect(
        CHANNEL_CREATORSIGNER
      ).claimRewards();

      const bobClaim_after_2nd = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
      const aliceClaim_after_2nd = await EPNSCoreV1Proxy.usersRewardsClaimed(
        ALICE
      );
      const charlieClaim_after_2nd = await EPNSCoreV1Proxy.usersRewardsClaimed(
        CHARLIE
      );
      const channelCreatorClaim_after_2nd =
        await EPNSCoreV1Proxy.usersRewardsClaimed(CHANNEL_CREATOR);

      const totalPool_Fee_after_2nd =
        await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
      console.log(
        "\n---------------Starting 2nd Claim with 4 total Stakers----------------------------"
      );
      console.log("Total Pool Fee", totalPool_Fee.toString());
      console.log(
        "Total Pool Fee After First Claim",
        totalPool_Fee_after.toString()
      );
      console.log(
        "Total Pool Fee After 2nd Claim",
        totalPool_Fee_after_2nd.toString()
      );
      console.log("\n");
      console.log(
        `Bob Claimed ${bobClaim_after_2nd.toString()} tokens at Block number ${
          tx_bob_2nd.blockNumber
        }`
      );
      console.log(
        `Alice Claimed ${aliceClaim_after_2nd.toString()} tokens at Block number ${
          tx_alice_2nd.blockNumber
        }`
      );
      console.log(
        `Charlie Claimed ${charlieClaim_after_2nd.toString()} tokens at Block number ${
          tx_charlie_2nd.blockNumber
        }`
      );
      console.log(
        `ChannelCreator Claimed ${channelCreatorClaim_after_2nd.toString()} tokens at Block number ${
          tx_channelCreator_2nd.blockNumber
        }`
      );

      // STARTING 3rd CLAIM
      await stakePushTokens(ADMINSIGNER, tokensBN(100));
      const [
        ADMIN_1st,
        BOB_BLOCK_3rd,
        ALICE_BLOCK_3rd,
        CHARLIE_BLOCK_3rd,
        CHANNEL_CREATOR_BLOCK_3rd,
      ] = [
        stakeStartBlock.add(259200),
        stakeStartBlock.add(259205),
        stakeStartBlock.add(259210),
        stakeStartBlock.add(259215),
        stakeStartBlock.add(259220),
      ];

      await jumpToBlockNumber(ADMIN_1st.sub(1));
      const tx_admin_1st = await EPNSCoreV1Proxy.connect(
        ADMINSIGNER
      ).claimRewards();
      await jumpToBlockNumber(BOB_BLOCK_3rd.sub(1));
      const tx_bob_3rd = await EPNSCoreV1Proxy.connect(
        BOBSIGNER
      ).claimRewards();
      await jumpToBlockNumber(ALICE_BLOCK_3rd.sub(1));
      const tx_alice_3rd = await EPNSCoreV1Proxy.connect(
        ALICESIGNER
      ).claimRewards();
      await jumpToBlockNumber(CHARLIE_BLOCK_3rd.sub(1));
      const tx_charlie_3rd = await EPNSCoreV1Proxy.connect(
        CHARLIESIGNER
      ).claimRewards();
      await jumpToBlockNumber(CHANNEL_CREATOR_BLOCK_3rd.sub(1));
      const tx_channelCreator_3rd = await EPNSCoreV1Proxy.connect(
        CHANNEL_CREATORSIGNER
      ).claimRewards();

      const adminClaim_after_1st = await EPNSCoreV1Proxy.usersRewardsClaimed(
        ADMIN
      );
      const bobClaim_after_3rd = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
      const aliceClaim_after_3rd = await EPNSCoreV1Proxy.usersRewardsClaimed(
        ALICE
      );
      const charlieClaim_after_3rd = await EPNSCoreV1Proxy.usersRewardsClaimed(
        CHARLIE
      );
      const channelCreatorClaim_after_3rd =
        await EPNSCoreV1Proxy.usersRewardsClaimed(CHANNEL_CREATOR);

      const totalPool_Fee_after_3rd =
        await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
      console.log(
        "\n---------------Starting 3rd Claim with 5 total Stakers----------------------------"
      );
      console.log("Total Pool Fee", totalPool_Fee.toString());
      console.log(
        "Total Pool Fee After First Claim",
        totalPool_Fee_after.toString()
      );
      console.log(
        "Total Pool Fee After 2nd Claim",
        totalPool_Fee_after_2nd.toString()
      );
      console.log("\n");
      console.log(
        `ADMIN Claimed ${adminClaim_after_1st.toString()} tokens at Block number ${
          tx_admin_1st.blockNumber
        }`
      );
      console.log(
        `Bob Claimed ${bobClaim_after_3rd.toString()} tokens at Block number ${
          tx_bob_3rd.blockNumber
        }`
      );
      console.log(
        `Alice Claimed ${aliceClaim_after_3rd.toString()} tokens at Block number ${
          tx_alice_3rd.blockNumber
        }`
      );
      console.log(
        `Charlie Claimed ${charlieClaim_after_3rd.toString()} tokens at Block number ${
          tx_charlie_3rd.blockNumber
        }`
      );
      console.log(
        `ChannelCreator Claimed ${channelCreatorClaim_after_3rd.toString()} tokens at Block number ${
          tx_channelCreator_3rd.blockNumber
        }`
      );
    });

    it.skip("shold work propertly after 7 days", async () => {
      const rewardValue = tokensBN(40);
      await EPNSCoreV1Proxy.setRewardRate(rewardValue);

      // Making pool funds 20
      await createChannel(ALICESIGNER);
      await createChannel(BOBSIGNER);

      // alice and bod stakes
      await stakePushTokens(ALICESIGNER, tokensBN(100));
      await stakePushTokens(BOBSIGNER, tokensBN(100));
      console.log("Alice & Bob stakes 100 PUSH each...");

      // wait for 6days
      await network.provider.send("evm_increaseTime", [3600 * 24 * 6]);
      await network.provider.send("evm_mine");
      console.log("6 days passes...");

      // claim rewards
      await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();
      await EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards();

      console.log("They both claim");
      const aliceRewardsClaimed_first =
        await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
      const bobRewardsClaimed_second =
        await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
      console.log(
        "alice reward",
        ethers.utils.formatEther(aliceRewardsClaimed_first)
      );
      console.log(
        "bob reward",
        ethers.utils.formatEther(bobRewardsClaimed_second)
      );
      console.log();

      // new channel is created
      console.log("Two more channels added....increasing pool fees");
      await createChannel(CHARLIESIGNER);
      await createChannel(CHANNEL_CREATORSIGNER);

      // wait for 6days
      await network.provider.send("evm_increaseTime", [3600 * 24 * 6]);
      await network.provider.send("evm_mine");
      console.log("6 days passes...");

      // claim rewards
      await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();
      await EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards();

      const aliceRewardsClaimed_first_2 =
        await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
      const bobRewardsClaimed_second_2 =
        await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
      console.log("They both claim");
      console.log(
        "alice reward",
        ethers.utils.formatEther(
          aliceRewardsClaimed_first_2.sub(aliceRewardsClaimed_first)
        )
      );
      console.log(
        "bob reward",
        ethers.utils.formatEther(
          bobRewardsClaimed_second_2.sub(bobRewardsClaimed_second)
        )
      );
    });

    it.skip("has some issue", async () => {
      const rewardValue = tokensBN(40);
      await EPNSCoreV1Proxy.setRewardRate(rewardValue);

      // Making pool funds 20
      await createChannel(ALICESIGNER);
      await createChannel(BOBSIGNER);

      // alice and bod stakes
      console.log("Alice stakes 100 PUSH ...");
      await stakePushTokens(ALICESIGNER, tokensBN(100));

      // wait for  7 days
      await network.provider.send("evm_increaseTime", [3600 * 24 * 7]);
      await network.provider.send("evm_mine");
      console.log("7 days passes...");

      // claim rewards
      console.log("Alice claims");
      await expect(
        EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards()
      ).to.be.revertedWith(
        "EPNSCoreV2::claimRewards: No Claimable Rewards at the moment"
      );
      const aliceRewardsClaimed_first =
        await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
      console.log(
        "alice reward calimed",
        ethers.utils.formatEther(aliceRewardsClaimed_first)
      );
      console.log();

      // new channel is created
      console.log("Two more channels added....increasing pool fees");
      await createChannel(CHARLIESIGNER);
      await createChannel(CHANNEL_CREATORSIGNER);

      // claim rewards
      await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();
      const aliceRewardsClaimed_first_2 =
        await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
      console.log("Alice claims again");
      console.log(
        "alice reward",
        ethers.utils.formatEther(
          aliceRewardsClaimed_first_2.sub(aliceRewardsClaimed_first)
        )
      );
    });

    const getCurrentPoolFees = async () => {
      const poolFees = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES().then((e) =>
        weiToEth(e)
      );
      return poolFees;
    };

    it("reward fix", async () => {
      // Making pool funds 30 with 3 channels
      await createChannel(ALICESIGNER);
      await createChannel(BOBSIGNER);

      await stakePushTokens(ALICESIGNER, tokensBN(100));
      await stakePushTokens(BOBSIGNER, tokensBN(100));
      //   await createChannel(CHANNEL_CREATORSIGNER);

      var rewardValue = tokensBN(20);
      await EPNSCoreV1Proxy.setStakeEpochDuration(7 * 24 * 3600);
      await EPNSCoreV1Proxy.initiateNewStake(rewardValue);

      console.log("Alice rewards");
      for (let i = 0; i < 7; i++) {
        await network.provider.send("evm_increaseTime", [3600 * 24 * 1]);
        await network.provider.send("evm_mine");
        await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();

        var aliceR1 = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
        console.log("ALICE cumulative reward claimed", weiToEth(aliceR1), " at day ", i+1);
      }

      console.log("BOB claims");
      await EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards();

    //   var aliceR1 = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
    //   console.log("ALICE reward claimed", weiToEth(aliceR1));
      var bobR1 = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
      console.log("BOB reward claimed", weiToEth(bobR1));

      return;

      console.log("Now all users try to claim a reward");
      var poolFees = await getCurrentPoolFees();
      console.log("before claim POOL_FEES: ", poolFees);

      // claim rewards
      var aliceR1 = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
      console.log("ALICE reward claimed", weiToEth(aliceR1));

      // add two more channels
      await createChannel(BOBSIGNER);
      await createChannel(CHARLIESIGNER);

      // admin resets
      await EPNSCoreV1Proxy.initiateNewStake(tokensBN(20));

      console.log("\n30 days pass ...");
      await network.provider.send("evm_increaseTime", [3600 * 24 * 30]);
      await network.provider.send("evm_mine");

      await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();
      var aliceR2 = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
      console.log("ALICE reward claimed", weiToEth(aliceR2.sub(aliceR1)));

      console.log("\n30 days pass ...");
      await network.provider.send("evm_increaseTime", [3600 * 24 * 30]);
      await network.provider.send("evm_mine");

      await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();
      var aliceR3 = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
      console.log("ALICE reward claimed", weiToEth(aliceR3.sub(aliceR2)));

      //   await EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards();
      //   var aliceR1 = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
      //   console.log("BOB reward claimed", weiToEth(aliceR1));

      return;

      var poolFees = await getCurrentPoolFees();
      console.log("bbb before claim POOL_FEES", poolFees);

      await createChannel(BOBSIGNER);
      await createChannel(CHARLIESIGNER);

      console.log("7 days pass...");
      await network.provider.send("evm_increaseTime", [3600 * 24 * 30]);
      await network.provider.send("evm_mine");

      console.log("Now all users tries to claim reward");
      var poolFees = await getCurrentPoolFees();
      console.log("aaaa before claim POOL_FEES", poolFees);

      // claim rewards
      await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();
      const wasDone = EPNSCommV1Proxy.lastGame();
      console.log("Was done", wasDone);
      var aliceR1 = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
      console.log("alice reward calimed", weiToEth(aliceR1));

      console.log("7 days pass...");
      await network.provider.send("evm_increaseTime", [3600 * 24 * 30]);
      await network.provider.send("evm_mine");

      console.log("Now all users tries to claim reward");
      var poolFees = await getCurrentPoolFees();
      console.log("before claim POOL_FEES", poolFees);

      // claim rewards
      await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();
      var aliceR1 = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
      console.log("alice reward calimed", weiToEth(aliceR1));

      await EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards();
      var bodR1 = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
      console.log("bob reward calimed", weiToEth(bodR1));
      await EPNSCoreV1Proxy.connect(CHARLIESIGNER).claimRewards();
      var charlieR1 = await EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE);
      console.log("charlie reward calimed", weiToEth(charlieR1));
      await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).claimRewards();
      var creatorR1 = await EPNSCoreV1Proxy.usersRewardsClaimed(
        CHANNEL_CREATOR
      );
      console.log("charlie reward calimed", weiToEth(creatorR1));

      // console.log("Bob claims");
      // await EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards()
      // console.log("Charlie claims");
      // await EPNSCoreV1Proxy.connect(CHARLIESIGNER).claimRewards()
      // const aliceRewardsClaimed_first =
      //   await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
      // console.log(
      //   "alice reward calimed",
      //   ethers.utils.formatEther(aliceRewardsClaimed_first)
      // );
      // console.log();

      return;

      // // new channel is created
      console.log("Two more channels added....increasing pool fees");
      await createChannel(CHARLIESIGNER);
      await createChannel(CHANNEL_CREATORSIGNER);

      await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();
      var aliceRewardsClaimed_first = await EPNSCoreV1Proxy.usersRewardsClaimed(
        ALICE
      );
      console.log(
        "alice reward calimed",
        ethers.utils.formatEther(aliceRewardsClaimed_first)
      );

      // wait for  8 days
      await network.provider.send("evm_increaseTime", [3600 * 24 * 20]);
      await network.provider.send("evm_mine");
      console.log("8 days passes...");

      // // claim rewards
      // await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();
      // const aliceRewardsClaimed_first_2 =
      //   await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
      // console.log("Alice claims again");
      // console.log(
      //   "alice reward",
      //   ethers.utils.formatEther(
      //     aliceRewardsClaimed_first_2.sub(aliceRewardsClaimed_first)
      //   )
      // );
    });
  });
});
