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

  describe("EPNS CORE: CLAIM REWARD TEST-ReardRate Procedure", () => {
    const CHANNEL_TYPE = 2;
    const TEST_CHANNEL_CTX = ethers.utils.toUtf8Bytes(
      "test-channel-hello-world"
    );

    const SEVEN_DAYS = 7 * 24 * 3600;
    const EPOCH_DURATION = SEVEN_DAYS;

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

    const claimRewardsInSingleBlock = async (signers) => {
      await ethers.provider.send("evm_setAutomine", [false]);
      await Promise.all(
        signers.map((signer) => EPNSCoreV1Proxy.connect(signer).claimRewards())
      );
      await network.provider.send("evm_mine");
      await ethers.provider.send("evm_setAutomine", [true]);
    };

    const getRewardsClaimed = async (signers) => {
      return await Promise.all(
        signers.map((signer) => EPNSCoreV1Proxy.usersRewardsClaimed(signer))
      );
    };

    it("should distrubute reward evenly for different users staking same ammount", async function () {
      await createChannel(ALICESIGNER);
      await createChannel(BOBSIGNER);
      await createChannel(CHARLIESIGNER);
      await createChannel(CHANNEL_CREATORSIGNER);

      // 4 users stakes push
      await ethers.provider.send("evm_setAutomine", [false]);
      await Promise.all([
        await stakePushTokens(BOBSIGNER, tokensBN(100)),
        await stakePushTokens(ALICESIGNER, tokensBN(100)),
        await stakePushTokens(CHARLIESIGNER, tokensBN(100)),
        await stakePushTokens(CHANNEL_CREATORSIGNER, tokensBN(100)),
      ]);
      await network.provider.send("evm_mine");
      await ethers.provider.send("evm_setAutomine", [true]);

      // Admin sets epoch
      const totalPool_Fee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
      await EPNSCoreV1Proxy.setStakeEpochDuration(EPOCH_DURATION);
      await EPNSCoreV1Proxy.initiateNewStake(totalPool_Fee);

      // 1 day passes
      await network.provider.send("evm_increaseTime", [3600 * 24 * 1]);
      await network.provider.send("evm_mine");

      // all users claims
      await claimRewardsInSingleBlock([
        ALICESIGNER,
        BOBSIGNER,
        CHANNEL_CREATORSIGNER,
        CHARLIESIGNER,
      ]);

      var [
        aliceClaimed1,
        bobClaimed1,
        charlieClaimed1,
        channelCreatorClaimed1,
      ] = await getRewardsClaimed([ALICE, BOB, CHARLIE, CHANNEL_CREATOR]);

      expect(aliceClaimed1).to.equal(bobClaimed1);
      expect(aliceClaimed1).to.equal(charlieClaimed1);
      expect(aliceClaimed1).to.equal(channelCreatorClaimed1);

      // 10 days passes
      await network.provider.send("evm_increaseTime", [3600 * 24 * 1]);
      await network.provider.send("evm_mine");

      // all users claims
      await claimRewardsInSingleBlock([
        ALICESIGNER,
        BOBSIGNER,
        CHANNEL_CREATORSIGNER,
        CHARLIESIGNER,
      ]);

      var [
        aliceClaimed1,
        bobClaimed1,
        charlieClaimed1,
        channelCreatorClaimed1,
      ] = await getRewardsClaimed([ALICE, BOB, CHARLIE, CHANNEL_CREATOR]);

      expect(aliceClaimed1).to.equal(bobClaimed1);
      expect(aliceClaimed1).to.equal(charlieClaimed1);
      expect(aliceClaimed1).to.equal(channelCreatorClaimed1);
    });

    it("should yield reward proportional to staked capital", async () => {
      await createChannel(ALICESIGNER);
      await createChannel(BOBSIGNER);
      await createChannel(CHARLIESIGNER);
      await createChannel(CHANNEL_CREATORSIGNER);

      // 2 users stakes push
      // Alice stakes twices as BOB
      await ethers.provider.send("evm_setAutomine", [false]);
      await Promise.all([
        await stakePushTokens(BOBSIGNER, tokensBN(100)),
        await stakePushTokens(ALICESIGNER, tokensBN(200)),
      ]);
      await network.provider.send("evm_mine");
      await ethers.provider.send("evm_setAutomine", [true]);

      // Admin sets epoch
      const totalPool_Fee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
      await EPNSCoreV1Proxy.setStakeEpochDuration(EPOCH_DURATION);
      await EPNSCoreV1Proxy.initiateNewStake(totalPool_Fee);

      // 3 day passes
      await network.provider.send("evm_increaseTime", [3600 * 24 * 7]);
      await network.provider.send("evm_mine");

      // all users claims
      await claimRewardsInSingleBlock([ALICESIGNER, BOBSIGNER]);

      var [aliceClaimed1, bobClaimed1] = await getRewardsClaimed([
        ALICE,
        BOB,
        CHARLIE,
        CHANNEL_CREATOR,
      ]);

      expect(bobClaimed1).to.be.above(bn(0));
      expect(aliceClaimed1).to.equal(bobClaimed1.mul(2));
    });

    it("should yield reward proportional to time staked", async () => {
      await createChannel(ALICESIGNER);
      await createChannel(BOBSIGNER);
      await createChannel(CHARLIESIGNER);
      await createChannel(CHANNEL_CREATORSIGNER);

      // 2 users stakes push evenly
      await ethers.provider.send("evm_setAutomine", [false]);
      await Promise.all([
        await stakePushTokens(BOBSIGNER, tokensBN(100)),
        await stakePushTokens(ALICESIGNER, tokensBN(200)),
      ]);
      await network.provider.send("evm_mine");
      await ethers.provider.send("evm_setAutomine", [true]);

      // Admin sets epoch
      const totalPool_Fee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
      await EPNSCoreV1Proxy.setStakeEpochDuration(EPOCH_DURATION);
      await EPNSCoreV1Proxy.initiateNewStake(totalPool_Fee);

      // BOB claims after 1 day
      await network.provider.send("evm_increaseTime", [3600 * 24 * 1]);
      await network.provider.send("evm_mine");
      await claimRewardsInSingleBlock([BOBSIGNER]);

      // ALICE claims after 7 days
      await network.provider.send("evm_increaseTime", [3600 * 24 * 6]);
      await network.provider.send("evm_mine");
      await claimRewardsInSingleBlock([ALICESIGNER]);

      var [aliceClaimed1, bobClaimed1] = await getRewardsClaimed([
        ALICE,
        BOB,
        CHARLIE,
        CHANNEL_CREATOR,
      ]);

      expect(bobClaimed1).to.be.above(bn(0));
      expect(aliceClaimed1).to.be.above(bobClaimed1);
    });

    it("should not yield reward after epoch ends and yields after admin reset", async () => {
      await createChannel(ALICESIGNER);
      await createChannel(BOBSIGNER);
      await createChannel(CHARLIESIGNER);

      // 4 users stakes push
      await ethers.provider.send("evm_setAutomine", [false]);
      await Promise.all([
        await stakePushTokens(BOBSIGNER, tokensBN(100)),
        await stakePushTokens(ALICESIGNER, tokensBN(100)),
        await stakePushTokens(CHARLIESIGNER, tokensBN(100)),
        await stakePushTokens(CHANNEL_CREATORSIGNER, tokensBN(100)),
      ]);
      await network.provider.send("evm_mine");
      await ethers.provider.send("evm_setAutomine", [true]);

      // Admin sets epoch
      var totalPool_Fee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
      await EPNSCoreV1Proxy.setStakeEpochDuration(EPOCH_DURATION);
      await EPNSCoreV1Proxy.initiateNewStake(totalPool_Fee);

      // 7 day passes
      await network.provider.send("evm_increaseTime", [3600 * 24 * 7]);
      await network.provider.send("evm_mine");

      // all users claims
      await claimRewardsInSingleBlock([
        ALICESIGNER,
        BOBSIGNER,
        CHANNEL_CREATORSIGNER,
        CHARLIESIGNER,
      ]);

      var [
        aliceClaimed1,
        bobClaimed1,
        charlieClaimed1,
        channelCreatorClaimed1,
      ] = await getRewardsClaimed([ALICE, BOB, CHARLIE, CHANNEL_CREATOR]);

      // all users again claims
      await claimRewardsInSingleBlock([
        ALICESIGNER,
        BOBSIGNER,
        CHANNEL_CREATORSIGNER,
        CHARLIESIGNER,
      ]);

      // all user claims
      var [
        aliceClaimed2,
        bobClaimed2,
        charlieClaimed2,
        channelCreatorClaimed2,
      ] = await getRewardsClaimed([ALICE, BOB, CHARLIE, CHANNEL_CREATOR]);

      // All users should get zero rewards
      expect(aliceClaimed1).to.equal(aliceClaimed2);
      expect(bobClaimed1).to.equal(bobClaimed2);
      expect(channelCreatorClaimed1).to.equal(channelCreatorClaimed2);
      expect(charlieClaimed1).to.equal(charlieClaimed2);

      // new channels created
      await createChannel(CHANNEL_CREATORSIGNER);

      // Admin sets epoch
      var totalPool_Fee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
      await EPNSCoreV1Proxy.setStakeEpochDuration(EPOCH_DURATION);
      await EPNSCoreV1Proxy.initiateNewStake(totalPool_Fee);

      // 7 day passes
      await network.provider.send("evm_increaseTime", [3600 * 24 * 7]);
      await network.provider.send("evm_mine");

      // all user claims
      await claimRewardsInSingleBlock([
        ALICESIGNER,
        BOBSIGNER,
        CHANNEL_CREATORSIGNER,
        CHARLIESIGNER,
      ]);

      var [
        aliceClaimed3,
        bobClaimed3,
        charlieClaimed3,
        channelCreatorClaimed3,
      ] = await getRewardsClaimed([ALICE, BOB, CHARLIE, CHANNEL_CREATOR]);

      // All users should get rewards
      expect(aliceClaimed3).to.above(aliceClaimed2);
      expect(bobClaimed3).to.above(bobClaimed2);
      expect(channelCreatorClaimed3).to.above(channelCreatorClaimed2);
      expect(charlieClaimed3).to.above(charlieClaimed2);

    });

    it("should not favour user claiming every 1 day vs claiming 7day", async () => {
      // Making pool funds 20 with 2 channels
      await createChannel(ALICESIGNER);
      await createChannel(BOBSIGNER);

      // Alice & Bob stakes
      await stakePushTokens(ALICESIGNER, tokensBN(100));
      await stakePushTokens(BOBSIGNER, tokensBN(100));

      // admin sets rewards
      var rewardValue = tokensBN(20);
      await EPNSCoreV1Proxy.setStakeEpochDuration(7 * 24 * 3600);
      await EPNSCoreV1Proxy.initiateNewStake(rewardValue);

      // Alice claims every day
      for (let i = 0; i < 7; i++) {
        await network.provider.send("evm_increaseTime", [3600 * 24 * 1]);
        await network.provider.send("evm_mine");
        await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();
      }

      // bod claims at the end of 7 days
      await EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards();

      var [aliceClaimed1, bobClaimed1] = await getRewardsClaimed([ALICE, BOB]);

      // reward claimed should be same
      expect(aliceClaimed1).to.equal(bobClaimed1);
    });
  });
});
