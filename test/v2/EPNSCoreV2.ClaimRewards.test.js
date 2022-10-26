const { ethers, waffle } = require("hardhat");
const { epnsContractFixture, tokenFixture } = require("../common/fixtures");
const { expect } = require("../common/expect");
const createFixtureLoader = waffle.createFixtureLoader;

const { tokensBN, bn } = require("../../helpers/utils");

describe("EPNS Core Protocol", function () {
  const ADD_CHANNEL_MIN_POOL_CONTRIBUTION = tokensBN(50);

  let EPNSCoreV1Proxy;
  let EPNSCommV1Proxy;
  let MOCKDAI;
  let CHANNEL_CREATOR;
  let ADMINSIGNER;
  let CHANNEL_CREATORSIGNER;
  let PushToken;

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
      ROUTER,
      PushToken,
      EPNS_TOKEN_ADDRS,
    } = await loadFixture(epnsContractFixture));

    ({ MOCKDAI, ADAI } = await loadFixture(tokenFixture));
  });

  /***
   * CHECKPOINTS TO CONSIDER WHILE TESTING -> Overall Stake-N-Claim Tests
   * ------------------------------------------
   * 1. Staking function should execute as expected ✅
   * 2. Staking functions shouldn't be executed when PAUSED.✅
   * 3. First Claim of stakers should execute as expected ✅
   * 4. First Claim: Stakers who hold longer should get more rewards ✅
   * 5. Verify that total reward actually gets distrubuted between stakers in given duration ✅
   * 6. Automated adjustment of rewardRate should be done as per expectations.
   * 7. Rewards should adjust automatically if new Staker comes into picture
   * 8. Withdrawal should be executed as expected
   * 9. Users shouldn't be able to claim any rewards after withdrawal
   * 10. initiateNewStake() related tests:
   *     - Should only be called by the governance
   *     - Reward value passed should never be more than available Protocol_Pool_Fees in the protocol.
   *     - Rewards should be accurate if new stake is initiated within an existing stakeDuration
   *     - Rewards should be accurate if new stake is initiated After an existing stakeDuration
   *     - lastUpdateTime and endPeriod should be updated accurately and stakeDuration should be increased
   */

  describe("EPNS CORE: CLAIM REWARD TEST-ReardRate Procedure", function () {
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
      //blockNumber = blockNumber.toNumber();
      const currentBlock = await ethers.provider.getBlock("latest");
      const numBlockToIncrease = blockNumber - currentBlock.number;
      const blockIncreaseHex = `0x${numBlockToIncrease.toString(16)}`;
      await ethers.provider.send("hardhat_mine", [blockIncreaseHex]);
    };

    /**
     * "createChannelWithFees" Function CheckPoints
     * REVERT CHECKS
     * Should revert IF EPNSCoreV1::onlyInactiveChannels: Channel already Activated
     * Should revert if Channel Type is NOT THE Allowed One
     * Should revert if AMOUNT Passed if Not greater than or equal to the 'ADD_CHANNEL_MIN_POOL_CONTRIBUTION'
     *
     * FUNCTION Execution CHECKS
     * The Channel Creation Fees should be Transferred to the EPNS Core Proxy
     * Should deposit funds to the POOL and Recieve aDAI
     * Should Update the State Variables Correctly and Activate the Channel
     * Readjustment of the FS Ratio should be checked
     * Should Interact successfully with EPNS Communicator and Subscribe Channel Owner to his own Channel
     * Should subscribe Channel owner to 0x000 channel
     * Should subscribe ADMIN to the Channel Creator's Channel
     **/

    it("Ensure STAKE function executes as expected", async function () {
      const rewardVal_before = await EPNSCoreV1Proxy.rewardRate();
      const totalStakedAmount_before =
        await EPNSCoreV1Proxy.totalStakedAmount();
      // Initial Set-Up
      await createChannel(ALICESIGNER);
      await createChannel(BOBSIGNER);
      await EPNSCoreV1Proxy.connect(ADMINSIGNER).setStakeEpochDuration(604800);
      await EPNSCoreV1Proxy.connect(ADMINSIGNER).initiateNewStake(tokensBN(20));

      const txAlice = await EPNSCoreV1Proxy.connect(ALICESIGNER).stake(
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(2)
      );
      const txBob = await EPNSCoreV1Proxy.connect(BOBSIGNER).stake(
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(2)
      );

      // Protocol Set-Up Checks
      const protocolPoolFunds = await EPNSCoreV1Proxy.POOL_FUNDS();
      const protocolPoolFee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
      const rewardVal_after = await EPNSCoreV1Proxy.rewardRate();
      const totalStakedAmount_after = await EPNSCoreV1Proxy.totalStakedAmount();
      // User set-up checks
      const bobStakeAmount = await EPNSCoreV1Proxy.userStakedAmount(BOB);
      const aliceStakeAmount = await EPNSCoreV1Proxy.userStakedAmount(ALICE);

      expect(rewardVal_before).to.be.equal(0);
      expect(totalStakedAmount_before).to.be.equal(0);
      expect(rewardVal_after).to.be.equal(protocolPoolFee.div(604800));
      expect(protocolPoolFunds).to.be.equal(ethers.utils.parseEther("280"));
      expect(totalStakedAmount_after).to.be.equal(
        ethers.utils.parseEther("200")
      );

      expect(bobStakeAmount).to.be.equal(ethers.utils.parseEther("100"));
      expect(aliceStakeAmount).to.be.equal(ethers.utils.parseEther("100"));
    });

    it("Stake function shouldn't be executed when PAUSED", async function () {
      // Initial Set-Up
      await createChannel(ALICESIGNER);
      await createChannel(BOBSIGNER);

      await EPNSCoreV1Proxy.connect(ADMINSIGNER).setStakeEpochDuration(604800);
      await EPNSCoreV1Proxy.connect(ADMINSIGNER).initiateNewStake(tokensBN(20));

      await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
      const tx = stakePushTokens(CHANNEL_CREATORSIGNER, tokensBN(100));

      expect(tx).to.be.revertedWith("Pausable: paused");
    });

    /***
     * Case:
     * 4 Stakers stake 100 Tokens and each of them try to claim after 100 blocks
     * Expecatations: Rewards of -> ChannelCreator > Charlie > Alice > BOB
     */
    it("First Claim: Stakers who hold more should get more Reward", async function () {
      // Initial Set-Up
      await createChannel(ALICESIGNER);
      await createChannel(BOBSIGNER);
      await createChannel(CHARLIESIGNER);
      await createChannel(CHANNEL_CREATORSIGNER);

      await EPNSCoreV1Proxy.connect(ADMINSIGNER).setStakeEpochDuration(604800);
      const tx_StakeStart = await EPNSCoreV1Proxy.connect(
        ADMINSIGNER
      ).initiateNewStake(tokensBN(20));
      const stakeStartBlock = await EPNSCoreV1Proxy.stakeStartTime();

      await stakePushTokens(BOBSIGNER, tokensBN(100));
      await stakePushTokens(ALICESIGNER, tokensBN(100));
      await stakePushTokens(CHARLIESIGNER, tokensBN(100));
      await stakePushTokens(CHANNEL_CREATORSIGNER, tokensBN(100));

      console.log("Stake Start", stakeStartBlock.toString());
      console.log("Stake Start TX", tx_StakeStart.blockNumber);

      // TODO: need blockNumber at the block the staking was started
      const txStakeStartBlock = bn(tx_StakeStart.blockNumber);
      const [BOB_BLOCK, ALICE_BLOCK, CHARLIE_BLOCK, CHANNEL_CREATOR_BLOCK] = [
        txStakeStartBlock.add(86400),
        txStakeStartBlock.add(86405),
        txStakeStartBlock.add(86400),
        txStakeStartBlock.add(86400),
      ];
      await jumpToBlockNumber(BOB_BLOCK.sub(1));
      const tx_bob = await EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards();
      await jumpToBlockNumber(ALICE_BLOCK.sub(1));
      const tx_alice = await EPNSCoreV1Proxy.connect(
        ALICESIGNER
      ).claimRewards();
      // await jumpToBlockNumber(CHARLIE_BLOCK.sub(1));
      // const tx_charlie = await EPNSCoreV1Proxy.connect(CHARLIESIGNER).claimRewards();
      // await jumpToBlockNumber(CHANNEL_CREATOR_BLOCK.sub(1));
      // const tx_channelCreator = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).claimRewards();

      const bobClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
      const aliceClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
      // const charlieClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE);
      // const channelCreatorClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(CHANNEL_CREATOR);

      // Logs if needed
      console.log("First Claim");
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
      // console.log(`Charlie Claimed ${charlieClaim_after.toString()} tokens at Block number ${tx_charlie.blockNumber}`);
      // console.log(`ChannelCreator Claimed ${channelCreatorClaim_after.toString()} tokens at Block number ${tx_channelCreator.blockNumber}`);

      // Verify rewards of ChannelCreator > Charlie > Alice > BOB
      expect(aliceClaim_after).to.be.gt(bobClaim_after);
      // expect(charlieClaim_after).to.be.gt(aliceClaim_after);
      // expect(channelCreatorClaim_after).to.be.gt(charlieClaim_after);
    });
  });
});
