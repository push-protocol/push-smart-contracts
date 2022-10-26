const { ethers,waffle } = require("hardhat");
const {epnsContractFixture,tokenFixture} = require("../common/fixtures")
const {expect} = require("../common/expect")
const createFixtureLoader = waffle.createFixtureLoader;

const {
  tokensBN,
} = require("../../helpers/utils");

describe("EPNS Core Protocol", function () {
  const ADD_CHANNEL_MIN_POOL_CONTRIBUTION = tokensBN(50)

  let EPNSCoreV1Proxy;
  let EPNSCommV1Proxy;
  let MOCKDAI;
  let CHANNEL_CREATOR;
  let ADMINSIGNER;
  let CHANNEL_CREATORSIGNER;
  let USER_1;
  let USER_2;
  let USER_3;
  let PushToken;
 

  let loadFixture;
  before(async() => {
    [wallet, other] = await ethers.getSigners()
    loadFixture = createFixtureLoader([wallet, other])
  });

  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    const [
      adminSigner,
      aliceSigner,
      bobSigner,
      charlieSigner,
      channelCreatorSigner,
      user1_signer,
      user2_signer,
      user3_signer
    ] = await ethers.getSigners();

    ADMINSIGNER = adminSigner;
    ALICESIGNER = aliceSigner;
    BOBSIGNER = bobSigner;
    CHARLIESIGNER = charlieSigner;
    CHANNEL_CREATORSIGNER = channelCreatorSigner;
    USER_1_SIGNER = user1_signer;
    USER_2_SIGNER = user2_signer;
    USER_3_SIGNER = user3_signer;

    ADMIN = await adminSigner.getAddress();
    ALICE = await aliceSigner.getAddress();
    BOB = await bobSigner.getAddress();
    CHARLIE = await charlieSigner.getAddress();
    CHANNEL_CREATOR = await channelCreatorSigner.getAddress();
    USER_1 = await user1_signer.getAddress();
    USER_2 = await user2_signer.getAddress();
    USER_3 = await user3_signer.getAddress();
    
    ({
      PROXYADMIN,
      EPNSCoreV1Proxy,
      EPNSCommV1Proxy, 
      ROUTER,
      PushToken,
      EPNS_TOKEN_ADDRS,
    } = await loadFixture(epnsContractFixture)); 

    ({MOCKDAI, ADAI} = await loadFixture(tokenFixture));

  });

    /***
   * CHECKPOINTS TO CONSIDER WHILE TESTING -> Overall Stake-N-Claim Tests
   * ------------------------------------------
   * 1. Stake and Unstake
   *  - Staking function should execute as expected ✅
   *  - Staking functions shouldn't be executed when PAUSED.✅
   *  - Withdrawal should be executed as expected
   * 
   * 2. Reward Calculation and Claiming Reward Tests
   *  - First Claim of stakers should execute as expected ✅
   *  - First Claim: Stakers who hold longer should get more rewards ✅
   *  - Verify that total reward actually gets distrubuted between stakers in given duration ✅
   *  - Rewards should adjust automatically if new Staker comes into picture ✅
   *  - Users shouldn't be able to claim any rewards after withdrawal 
   * 
   * 3. Initiating New Stakes
   *  - Should only be called by the governance/admin ✅
   *  - Reward value passed should never be more than available Protocol_Pool_Fees in the protocol.
   *  - Rewards should be accurate if new stake is initiated within an existing stakeDuration
   *  - Rewards should be accurate if new stake is initiated After an existing stakeDuration
   *  - lastUpdateTime and endPeriod should be updated accurately and stakeDuration should be increased.
   * 
   */

   
describe("EPNS CORE: CLAIM REWARD TEST-ReardRate Procedure", function()
{
    const CHANNEL_TYPE = 2;
    const TEST_CHANNEL_CTX = ethers.utils.toUtf8Bytes("test-channel-hello-world");

    beforeEach(async function(){
    await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
    await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);

    await PushToken.transfer(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10));
    await PushToken.transfer(BOB, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000));
    await PushToken.transfer(USER_1, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000));
    await PushToken.transfer(USER_2, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000));
    await PushToken.transfer(USER_3, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000));
    await PushToken.transfer(ALICE, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000));
    await PushToken.transfer(CHARLIE, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000));
    await PushToken.transfer(ADMIN, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000));
    await PushToken.transfer(CHANNEL_CREATOR, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000));


    await PushToken.connect(BOBSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000));
    await PushToken.connect(USER_1_SIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000));
    await PushToken.connect(USER_2_SIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000));
    await PushToken.connect(USER_3_SIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000));
    await PushToken.connect(ADMINSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000));
    await PushToken.connect(ALICESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000));
    await PushToken.connect(CHARLIESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000));
    await PushToken.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10000));
    });

    const createChannel = async(signer)=>{
        await EPNSCoreV1Proxy.connect(signer)
        .createChannelWithPUSH(CHANNEL_TYPE, TEST_CHANNEL_CTX, ADD_CHANNEL_MIN_POOL_CONTRIBUTION,0);
    }

    const stakePushTokens = async(signer, amount)=>{
        await EPNSCoreV1Proxy.connect(signer).stake(amount);
    }

    const jumpToBlockNumber = async(blockNumber) =>{
        //blockNumber = blockNumber.toNumber();
        const currentBlock = await ethers.provider.getBlock("latest");
        const numBlockToIncrease = blockNumber - currentBlock.number;
        const blockIncreaseHex = `0x${numBlockToIncrease.toString(16)}`;
        await ethers.provider.send("hardhat_mine", [blockIncreaseHex]);
      }

  describe("🟢 Staking and Unstake Tests ", function()
    {
      it("Ensure STAKE function executes as expected", async function(){
          const rewardVal_before = await EPNSCoreV1Proxy.rewardRate();
          const totalStakedAmount_before = await EPNSCoreV1Proxy.totalStakedAmount();
          // Initial Set-Up
          await createChannel(ALICESIGNER);
          await createChannel(BOBSIGNER);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).setStakeEpochDuration(604800);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).initiateNewStake(tokensBN(20));
          
          const txAlice = await EPNSCoreV1Proxy.connect(ALICESIGNER).stake(ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(2));
          const txBob = await EPNSCoreV1Proxy.connect(BOBSIGNER).stake(ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(2));

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
          expect(totalStakedAmount_after).to.be.equal(ethers.utils.parseEther("200"));
          
          expect(bobStakeAmount).to.be.equal(ethers.utils.parseEther("100"));
          expect(aliceStakeAmount).to.be.equal(ethers.utils.parseEther("100"));
            
    })
    
    it("Stake function shouldn't be executed when PAUSED", async function(){
      // Initial Set-Up
      await createChannel(ALICESIGNER);
      await createChannel(BOBSIGNER);
      
      await EPNSCoreV1Proxy.connect(ADMINSIGNER).setStakeEpochDuration(604800);
      await EPNSCoreV1Proxy.connect(ADMINSIGNER).initiateNewStake(tokensBN(20));

      await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
      const tx = stakePushTokens(CHANNEL_CREATORSIGNER, tokensBN(100));
      
      expect(tx).to.be.revertedWith('Pausable: paused');
    }) 

  });

  describe("🟢 Reward Calculation and Claiming Reward Tests ", function()
  {
  /***
   * Case:
   * 4 Stakers stake 100 Tokens and each of them try to claim after 100 blocks 
   * Expecatations: Rewards of -> ChannelCreator > Charlie > Alice > BOB
   */
  it.skip("First Claim: Stakers who hold more should get more Reward after 1 day", async function(){
    // Initial Set-Up
      await createChannel(ALICESIGNER);
      await createChannel(BOBSIGNER);
      await createChannel(CHARLIESIGNER);
      await createChannel(CHANNEL_CREATORSIGNER);

      await EPNSCoreV1Proxy.connect(ADMINSIGNER).setStakeEpochDuration(604800);
      const tx_StakeStart = await EPNSCoreV1Proxy.connect(ADMINSIGNER).initiateNewStake(tokensBN(20));
      const stakeStartBlock = await EPNSCoreV1Proxy.stakeStartTime();

      await stakePushTokens(BOBSIGNER, tokensBN(100));
      await stakePushTokens(ALICESIGNER, tokensBN(100));
      await stakePushTokens(CHARLIESIGNER, tokensBN(100));
      await stakePushTokens(CHANNEL_CREATORSIGNER, tokensBN(100));

      const start = tx_StakeStart.blockNumber;
       
      const [BOB_BLOCK, ALICE_BLOCK, CHARLIE_BLOCK, CHANNEL_CREATOR_BLOCK] = [
        start + 86400, 
        start + 86405, 
        start + 86410, 
        start + 86415
      ]		
      await jumpToBlockNumber(BOB_BLOCK - 1);
      const tx_bob = await EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards();
      await jumpToBlockNumber(ALICE_BLOCK - 1);
      const tx_alice = await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();
      await jumpToBlockNumber(CHARLIE_BLOCK - 1);
      const tx_charlie = await EPNSCoreV1Proxy.connect(CHARLIESIGNER).claimRewards();
      await jumpToBlockNumber(CHANNEL_CREATOR_BLOCK - 1);
      const tx_channelCreator = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).claimRewards();
      
      const bobClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
      const aliceClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
      const charlieClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE);
      const channelCreatorClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(CHANNEL_CREATOR);

      // Logs if needed
      // console.log("First Claim")
      // console.log(`Bob Claimed ${bobClaim_after.toString()} tokens at Block number ${tx_bob.blockNumber}`);
      // console.log(`Alice Claimed ${aliceClaim_after.toString()} tokens at Block number ${tx_alice.blockNumber}`);
      // console.log(`Charlie Claimed ${charlieClaim_after.toString()} tokens at Block number ${tx_charlie.blockNumber}`);
      // console.log(`ChannelCreator Claimed ${channelCreatorClaim_after.toString()} tokens at Block number ${tx_channelCreator.blockNumber}`);
      
      // Verify rewards of ChannelCreator > Charlie > Alice > BOB
      expect(aliceClaim_after).to.be.gt(bobClaim_after);
      expect(charlieClaim_after).to.be.gt(aliceClaim_after);
      expect(channelCreatorClaim_after).to.be.gt(charlieClaim_after);
  })

  /***
   * Case:
   * 4 Stakers stake 100 Tokens and each of them try to claim after Complete Duration -> 1 week 
   * Expecatations: Rewards of all stakers after 1 complete week should be corect
   */
  it.skip("Equal rewards should be distributed to Users after Stake Epoch End", async function(){
    // Initial Set-Up
      await createChannel(ALICESIGNER);
      await createChannel(BOBSIGNER);
      await createChannel(CHARLIESIGNER);
      await createChannel(CHANNEL_CREATORSIGNER);

      await EPNSCoreV1Proxy.connect(ADMINSIGNER).setStakeEpochDuration(604800);
      const tx_StakeStart = await EPNSCoreV1Proxy.connect(ADMINSIGNER).initiateNewStake(tokensBN(20));
      const stakeStartBlock = await EPNSCoreV1Proxy.stakeStartTime();

      await stakePushTokens(BOBSIGNER, tokensBN(100));
      await stakePushTokens(ALICESIGNER, tokensBN(100));
      await stakePushTokens(CHARLIESIGNER, tokensBN(100));
      await stakePushTokens(CHANNEL_CREATORSIGNER, tokensBN(100));

      const start = tx_StakeStart.blockNumber;
      const perPersonShare = tokensBN(10);

      const [BOB_BLOCK, ALICE_BLOCK, CHARLIE_BLOCK, CHANNEL_CREATOR_BLOCK] = [
        start + 604800, 
        start + 604805, 
        start + 604810, 
        start + 604815
      ]		
      await jumpToBlockNumber(BOB_BLOCK - 1);
      const tx_bob = await EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards();
      await jumpToBlockNumber(ALICE_BLOCK - 1);
      const tx_alice = await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();
      await jumpToBlockNumber(CHARLIE_BLOCK - 1);
      const tx_charlie = await EPNSCoreV1Proxy.connect(CHARLIESIGNER).claimRewards();
      await jumpToBlockNumber(CHANNEL_CREATOR_BLOCK - 1);
      const tx_channelCreator = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).claimRewards();

      const bobClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
      const aliceClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
      const charlieClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE);
      //const channelCreatorClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(CHANNEL_CREATOR);

      // Logs if needed
    // console.log("First Claim")
    // console.log(`Bob Claimed ${bobClaim_after.toString()} tokens at Block number ${tx_bob.blockNumber}`);
    // console.log(`Alice Claimed ${aliceClaim_after.toString()} tokens at Block number ${tx_alice.blockNumber}`);
    // console.log(`Charlie Claimed ${charlieClaim_after.toString()} tokens at Block number ${tx_charlie.blockNumber}`);
    // console.log(`ChannelCreator Claimed ${channelCreatorClaim_after.toString()} tokens at Block number ${tx_channelCreator.blockNumber}`);
    
    expect(ethers.BigNumber.from(bobClaim_after)).to.be.closeTo(ethers.BigNumber.from(perPersonShare), ethers.utils.parseEther("10"));
    expect(ethers.BigNumber.from(aliceClaim_after)).to.be.closeTo(ethers.BigNumber.from(perPersonShare), ethers.utils.parseEther("10"));
    expect(ethers.BigNumber.from(charlieClaim_after)).to.be.closeTo(ethers.BigNumber.from(perPersonShare), ethers.utils.parseEther("10"));
  })

  it("Rewards should adjust automatically if new Staker enters the Pool", async function(){
    // Initial Set-Up
      await createChannel(ALICESIGNER);
      await createChannel(BOBSIGNER);
      await createChannel(CHARLIESIGNER);
      await createChannel(CHANNEL_CREATORSIGNER);

      await EPNSCoreV1Proxy.connect(ADMINSIGNER).setStakeEpochDuration(604800);
      const tx_StakeStart = await EPNSCoreV1Proxy.connect(ADMINSIGNER).initiateNewStake(tokensBN(20));
      const stakeStartBlock = await EPNSCoreV1Proxy.stakeStartTime();

      await stakePushTokens(BOBSIGNER, tokensBN(100));
      await stakePushTokens(ALICESIGNER, tokensBN(100));
      await stakePushTokens(CHARLIESIGNER, tokensBN(100));
      await stakePushTokens(CHANNEL_CREATORSIGNER, tokensBN(100));

      const start = tx_StakeStart.blockNumber;
      const BOB_BLOCK = start + 86400;		
      await jumpToBlockNumber(BOB_BLOCK - 1);
      // To calculate change in PerPerson Share later
      await EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards();
      const bobClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
      
      // After Day 1, a User Enters and Stakes Same 100 tokens 
      await createChannel(USER_1_SIGNER);
      await stakePushTokens(USER_1_SIGNER, tokensBN(100));

      const [USER_1_BLOCK, BOB_BLOCK_2, ALICE_BLOCK_2, CHARLIE_BLOCK_2, CHANNEL_CREATOR_BLOCK_2] = [
        start + 172800, 
        start + 172805, 
        start + 172812, 
        start + 172815,
        start + 172820
      ]

      await jumpToBlockNumber(USER_1_BLOCK - 1);
      const tx_user1 = await EPNSCoreV1Proxy.connect(USER_1_SIGNER).claimRewards();
      await jumpToBlockNumber(BOB_BLOCK_2 - 1);
      const tx_bob_2 = await EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards();
      await jumpToBlockNumber(ALICE_BLOCK_2 - 1);
      const tx_alice_2 = await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();
      await jumpToBlockNumber(CHARLIE_BLOCK_2 - 1);
      const tx_charlie_2 = await EPNSCoreV1Proxy.connect(CHARLIESIGNER).claimRewards();
      await jumpToBlockNumber(CHANNEL_CREATOR_BLOCK_2 - 1);
      const tx_channelCreator_2 = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).claimRewards();
      
      const user1Claim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(USER_1);
      const bobClaim_after_2 = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
      const aliceClaim_after_2 = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
      const charlieClaim_after_2 = await EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE);
      const channelCreatorClaim_after_2 = await EPNSCoreV1Proxy.usersRewardsClaimed(CHANNEL_CREATOR);

      // Logs if need be
      // console.log("\n2nd Claim")
      // console.log(`User1 Claimed ${user1Claim_after.toString()} tokens at Block number ${tx_user1.blockNumber}`);
      // console.log(`Bob Claimed ${bobClaim_after_2.toString()} tokens at Block number ${tx_bob_2.blockNumber}`);
      // console.log(`Alice Claimed ${aliceClaim_after_2.toString()} tokens at Block number ${tx_alice_2.blockNumber}`);
      // console.log(`Charlie Claimed ${charlieClaim_after_2.toString()} tokens at Block number ${tx_charlie_2.blockNumber}`);
      // console.log(`ChannelCreator Claimed ${channelCreatorClaim_after_2.toString()} tokens at Block number ${tx_channelCreator_2.blockNumber}`);
      
      /*
       * VERIFY:
       * Rewards of User1 < Rewards of BOB/ALICE/CHARLIE after 1st Day -> This ensures Stakers who staked late get less rewards than old stakers
       * Rewards of ChannelCreator > Charlie > Alice > BOB > User1
       * Per person reward Decreases after entry of new Staker
      */

      expect(bobClaim_after_2).to.be.gt(user1Claim_after);
      expect(aliceClaim_after_2).to.be.gt(bobClaim_after_2);
      expect(charlieClaim_after_2).to.be.gt(aliceClaim_after_2);
      expect(channelCreatorClaim_after_2).to.be.gt(charlieClaim_after_2);

      // Calculate and Compare the Per Person shares of 1 day (for any Old Staker)
      const perPersonShare_old = bobClaim_after;
      const perPersonShare_new = bobClaim_after_2.sub(bobClaim_after);

      expect(perPersonShare_new).to.be.lt(perPersonShare_old); // Entry of new Staker adjusts rewards for all Stakers
      
  })

  });
 
});

});

/* Notes
* Actual RewardRate 33068783068783
* Actual Stake EPOCH End 1670630732
*/