const { ethers,waffle } = require("hardhat");
const {epnsContractFixture,tokenFixture} = require("../common/fixtures")
const {expect} = require("../common/expect")
const createFixtureLoader = waffle.createFixtureLoader;

const {
  tokensBN, bn
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
   * 1. Stake
   *  - Staking function should execute as expected ✅
   *  - Staking functions shouldn't be executed when PAUSED.✅
   *  - Staking functions shouldn't be executed when No Stake Epoch is Active.✅
   * 
   * 2. UnStake
   *  - UnStake function should execute as expected ✅
   *  - UnStake functions shouldn't be executed when Caller is Not a Staker.✅
   *  - UnStaking right after staking should lead to any rewards.
   *  - UnStaking should also transfer claimable rewards for the Caller ✅
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
   *  - Reward value passed should never be more than available Protocol_Pool_Fees in the protocol. ✅
   *  - lastUpdateTime and endPeriod should be updated accurately and stakeDuration should be increased.
   *  - If new Stake is initiated after END of running stake epoch:
   *    - Rewards should be accurate if new stake is initiated After an existing stakeDuration.
   * 
   *    - Rewards should be accurate if new stake is initiated within an existing stakeDuration.
   *    - 
   *  - 
   *  - 
   *  - 
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
        blockNumber = blockNumber.toNumber();
        const currentBlock = await ethers.provider.getBlock("latest");
        const numBlockToIncrease = blockNumber - currentBlock.number;
        const blockIncreaseHex = `0x${numBlockToIncrease.toString(16)}`;
        await ethers.provider.send("hardhat_mine", [blockIncreaseHex]);
      }

  describe("🟢 Staking Tests ", function()
    {
      it("Ensure STAKE function executes as expected", async function(){
          const rewardVal_before = await EPNSCoreV1Proxy.rewardRate();
          const totalStakedAmount_before = await EPNSCoreV1Proxy.totalStakedAmount();
          // Initial Set-Up
          await createChannel(ALICESIGNER);
          await createChannel(BOBSIGNER);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).setStakeEpochDuration(604800);
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).initiateNewStake();
          
          const txAlice = await EPNSCoreV1Proxy.connect(ALICESIGNER).stake(ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(2));
          const txBob = await EPNSCoreV1Proxy.connect(BOBSIGNER).stake(ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(2));

          // Protocol Set-Up Checks
          const protocolPoolFunds = await EPNSCoreV1Proxy.POOL_FUNDS();
          const protocolPoolFee = await EPNSCoreV1Proxy.REWARD_POOL();
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
    
    it("Stake function should NOT be executed when PAUSED", async function(){
      // Initial Set-Up
      await createChannel(ALICESIGNER);
      await createChannel(BOBSIGNER);
      
      await EPNSCoreV1Proxy.connect(ADMINSIGNER).setStakeEpochDuration(604800);
      const tx_StakeStart = await EPNSCoreV1Proxy.connect(ADMINSIGNER).initiateNewStake();

      await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
      const tx = stakePushTokens(CHANNEL_CREATORSIGNER, tokensBN(100));
      
      expect(tx).to.be.revertedWith('Pausable: paused');
    }) 

    it("Stake function should NOT be executed If No Active Stake EPOCH is present", async function(){
      // Initial Set-Up
      await createChannel(ALICESIGNER);
      await createChannel(BOBSIGNER);
      
      await EPNSCoreV1Proxy.connect(ADMINSIGNER).setStakeEpochDuration(604800);
      const tx_StakeStart = await EPNSCoreV1Proxy.connect(ADMINSIGNER).initiateNewStake();

      const stakeStartBlock = bn(tx_StakeStart.blockNumber);

      const after7days = stakeStartBlock.add(604802);
      await jumpToBlockNumber(after7days.sub(1));

      const tx = stakePushTokens(ALICESIGNER, tokensBN(100));

      expect(tx).to.be.revertedWith('EPNSCoreV2::stake: No active Stake Epoch currently');
    }) 

    it("Stake amount should be greater than the Minimum Threshold", async function(){
      // Initial Set-Up
      await createChannel(ALICESIGNER);
      await createChannel(BOBSIGNER);
      
      await EPNSCoreV1Proxy.connect(ADMINSIGNER).setStakeEpochDuration(604800);
      await EPNSCoreV1Proxy.connect(ADMINSIGNER).initiateNewStake();

      const tx = stakePushTokens(ALICESIGNER, tokensBN(10));

      expect(tx).to.be.revertedWith('EPNSCoreV2::stake: Invalid Stake Amount');
    }) 


  });

  describe("🟢 UnStaking Tests ", function()
  {
    it("Ensure UnStake function executes as expected", async function(){
      // Initial Set-Up
      await createChannel(ALICESIGNER);
      await createChannel(BOBSIGNER);
      
      await EPNSCoreV1Proxy.connect(ADMINSIGNER).setStakeEpochDuration(604800);
      const tx_StakeStart = await EPNSCoreV1Proxy.connect(ADMINSIGNER).initiateNewStake();
  
      await EPNSCoreV1Proxy.connect(ALICESIGNER).stake(ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(2));
      await EPNSCoreV1Proxy.connect(BOBSIGNER).stake(ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(2));

      // User Unstakes after 1 day
      const stakeStartBlock = bn(tx_StakeStart.blockNumber);
      const afterOneDay = stakeStartBlock.add(86400);

      // Before Unstake execution
      const poolFunds_before = await EPNSCoreV1Proxy.POOL_FUNDS();
      const stakerBalance_before = await PushToken.balanceOf(BOB);
      const totalStakedAmount_before = await EPNSCoreV1Proxy.totalStakedAmount();

      await EPNSCoreV1Proxy.connect(BOBSIGNER).unStake();

      // After Unstake execution
      const poolFunds_after = await EPNSCoreV1Proxy.POOL_FUNDS();
      const totalStakedAmount_after = await EPNSCoreV1Proxy.totalStakedAmount();
      const bobStakeAmount = await EPNSCoreV1Proxy.userStakedAmount(BOB);
      const stakerBalance_after = await PushToken.balanceOf(BOB);
      
      const totalAmountTransferred = stakerBalance_after.sub(stakerBalance_before);
      console.log(totalAmountTransferred.toString())
      expect(bobStakeAmount).to.be.equal(0);
      expect(totalStakedAmount_after).to.be.lt(totalStakedAmount_before);
      expect(poolFunds_after).to.be.lt(poolFunds_before);
      expect(totalAmountTransferred).to.be.gt(tokensBN(100));             
  })
  
  it.skip("User shouldn't unstake if He/She isn't a Staker", async function(){
    // Initial Set-Up
    await createChannel(ALICESIGNER);
    await createChannel(BOBSIGNER);
    
    await EPNSCoreV1Proxy.connect(ADMINSIGNER).setStakeEpochDuration(604800);
    const tx_StakeStart = await EPNSCoreV1Proxy.connect(ADMINSIGNER).initiateNewStake();

    const tx = EPNSCoreV1Proxy.connect(CHARLIESIGNER).unStake();
    
    expect(tx).to.be.revertedWith('EPNSCoreV2::unStake: No staked tokens');
  }) 


  it.skip("User Staking and Unstaking in same tx shouldn't recieve any rewards", async function(){
    // Initial Set-Up
    await createChannel(ALICESIGNER);
    await createChannel(BOBSIGNER);
    
    await EPNSCoreV1Proxy.connect(ADMINSIGNER).setStakeEpochDuration(604800);
    const tx_StakeStart = await EPNSCoreV1Proxy.connect(ADMINSIGNER).initiateNewStake();

    const stakeBlock = bn(tx_StakeStart.blockNumber);

    const stakerBalance_before = await PushToken.balanceOf(BOB); 

    await ethers.provider.send("evm_setAutomine", [false]);
		await Promise.all([
      await stakePushTokens(BOBSIGNER, tokensBN(100)),
      await EPNSCoreV1Proxy.connect(BOBSIGNER).unStake(),
			]);
    await network.provider.send("evm_mine");
		await ethers.provider.send("evm_setAutomine", [true]);

    // await stakePushTokens(BOBSIGNER, tokensBN(100));
    // await EPNSCoreV1Proxy.connect(BOBSIGNER).unStake();
    const stakerBalance_after = await PushToken.balanceOf(BOB);

    console.log(stakerBalance_before.toString())
    console.log(stakerBalance_after.toString())
  }) 


});

  describe("🟢 Reward Calculation and Claiming Reward Tests ", function()
  {
    /***
     * Case:
     * 4 Stakers stake 100 Tokens and each of them try to claim after 100 blocks 
     * Expecatations: Rewards of -> ChannelCreator > Charlie > Alice > BOB
     */
    it("First Claim: Stakers who hold more should get more Reward after 1 day", async function(){
      // Initial Set-Up
        await createChannel(ALICESIGNER);
        await createChannel(BOBSIGNER);
        await createChannel(CHARLIESIGNER);
        await createChannel(CHANNEL_CREATORSIGNER);

        await EPNSCoreV1Proxy.connect(ADMINSIGNER).setStakeEpochDuration(604800);
        const tx_StakeStart = await EPNSCoreV1Proxy.connect(ADMINSIGNER).initiateNewStake();
        await stakePushTokens(BOBSIGNER, tokensBN(100));
        await stakePushTokens(ALICESIGNER, tokensBN(100));
        await stakePushTokens(CHARLIESIGNER, tokensBN(100));
        await stakePushTokens(CHANNEL_CREATORSIGNER, tokensBN(100));

        const stakeStartBlock = bn(tx_StakeStart.blockNumber);
        
        const [BOB_BLOCK, ALICE_BLOCK, CHARLIE_BLOCK, CHANNEL_CREATOR_BLOCK] = [
          stakeStartBlock.add(86400), 
          stakeStartBlock.add(86405), 
          stakeStartBlock.add(86410), 
          stakeStartBlock.add(86415)
        ]		
        await jumpToBlockNumber(BOB_BLOCK.sub(1));
        const tx_bob = await EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards();
        await jumpToBlockNumber(ALICE_BLOCK.sub(1));
        const tx_alice = await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();
        await jumpToBlockNumber(CHARLIE_BLOCK.sub(1));
        const tx_charlie = await EPNSCoreV1Proxy.connect(CHARLIESIGNER).claimRewards();
        await jumpToBlockNumber(CHANNEL_CREATOR_BLOCK.sub(1));
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
    it("Equal rewards should be distributed to Users after Stake Epoch End", async function(){
      // Initial Set-Up
        await createChannel(ALICESIGNER);
        await createChannel(BOBSIGNER);
        await createChannel(CHARLIESIGNER);
        await createChannel(CHANNEL_CREATORSIGNER);

        await EPNSCoreV1Proxy.connect(ADMINSIGNER).setStakeEpochDuration(604800);
        const tx_StakeStart = await EPNSCoreV1Proxy.connect(ADMINSIGNER).initiateNewStake();

        await stakePushTokens(BOBSIGNER, tokensBN(100));
        await stakePushTokens(ALICESIGNER, tokensBN(100));
        await stakePushTokens(CHARLIESIGNER, tokensBN(100));
        await stakePushTokens(CHANNEL_CREATORSIGNER, tokensBN(100));

        const stakeStartBlock = bn(tx_StakeStart.blockNumber);
        const perPersonShare = tokensBN(10);

        const [BOB_BLOCK, ALICE_BLOCK, CHARLIE_BLOCK, CHANNEL_CREATOR_BLOCK] = [
          stakeStartBlock.add(604800), 
          stakeStartBlock.add(604805), 
          stakeStartBlock.add(604810), 
          stakeStartBlock.add(604815)
        ]		
        await jumpToBlockNumber(BOB_BLOCK.sub(1));
        const tx_bob = await EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards();
        await jumpToBlockNumber(ALICE_BLOCK.sub(1));
        const tx_alice = await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();
        await jumpToBlockNumber(CHARLIE_BLOCK.sub(1));
        const tx_charlie = await EPNSCoreV1Proxy.connect(CHARLIESIGNER).claimRewards();
        await jumpToBlockNumber(CHANNEL_CREATOR_BLOCK.sub(1));
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
      
      expect(ethers.BigNumber.from(bobClaim_after)).to.be.closeTo(ethers.BigNumber.from(perPersonShare), ethers.utils.parseEther("10"));
      expect(ethers.BigNumber.from(aliceClaim_after)).to.be.closeTo(ethers.BigNumber.from(perPersonShare), ethers.utils.parseEther("10"));
      expect(ethers.BigNumber.from(charlieClaim_after)).to.be.closeTo(ethers.BigNumber.from(perPersonShare), ethers.utils.parseEther("10"));
      expect(ethers.BigNumber.from(channelCreatorClaim_after)).to.be.closeTo(ethers.BigNumber.from(perPersonShare), ethers.utils.parseEther("10"));
    })

    it("Rewards should adjust automatically if new Staker enters the Pool", async function(){
      // Initial Set-Up
        await createChannel(ALICESIGNER);
        await createChannel(BOBSIGNER);
        await createChannel(CHARLIESIGNER);
        await createChannel(CHANNEL_CREATORSIGNER);

        await EPNSCoreV1Proxy.connect(ADMINSIGNER).setStakeEpochDuration(604800);
        const tx_StakeStart = await EPNSCoreV1Proxy.connect(ADMINSIGNER).initiateNewStake();

        await stakePushTokens(BOBSIGNER, tokensBN(100));
        await stakePushTokens(ALICESIGNER, tokensBN(100));
        await stakePushTokens(CHARLIESIGNER, tokensBN(100));
        await stakePushTokens(CHANNEL_CREATORSIGNER, tokensBN(100));

        const stakeStartBlock = bn(tx_StakeStart.blockNumber);
        // Afer Day 1, Bob Claims
        const BOB_BLOCK = stakeStartBlock.add(86400)		
        await jumpToBlockNumber(BOB_BLOCK.sub(1));
        await EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards();
        const bobClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
        
        // After Day 1, a User Enters and Stakes Same 100 tokens 
        await createChannel(USER_1_SIGNER);
        await stakePushTokens(USER_1_SIGNER, tokensBN(100));

        const [USER_1_BLOCK, BOB_BLOCK_2, ALICE_BLOCK_2, CHARLIE_BLOCK_2, CHANNEL_CREATOR_BLOCK_2] = [
          stakeStartBlock.add(172800), 
          stakeStartBlock.add(172805), 
          stakeStartBlock.add(172813), 
          stakeStartBlock.add(172817),
          stakeStartBlock.add(172820)
        ]

        await jumpToBlockNumber(USER_1_BLOCK.sub(1));
        const tx_user1 = await EPNSCoreV1Proxy.connect(USER_1_SIGNER).claimRewards();
        await jumpToBlockNumber(BOB_BLOCK_2.sub(1));
        const tx_bob_2 = await EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards();
        await jumpToBlockNumber(ALICE_BLOCK_2.sub(1));
        const tx_alice_2 = await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();
        await jumpToBlockNumber(CHARLIE_BLOCK_2.sub(1));
        const tx_charlie_2 = await EPNSCoreV1Proxy.connect(CHARLIESIGNER).claimRewards();
        await jumpToBlockNumber(CHANNEL_CREATOR_BLOCK_2.sub(1));
        const tx_channelCreator_2 = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).claimRewards();
        
        const user1Claim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(USER_1);
        const bobClaim_after_2 = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
        const aliceClaim_after_2 = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
        const charlieClaim_after_2 = await EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE);
        const channelCreatorClaim_after_2 = await EPNSCoreV1Proxy.usersRewardsClaimed(CHANNEL_CREATOR);

        // // Logs if need be
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

    it("NO Claim of rewards after Complete Withdrawal", async function(){
      // Initial Set-Up
        await createChannel(ALICESIGNER);
        await createChannel(BOBSIGNER);
        await createChannel(CHARLIESIGNER);
        await createChannel(CHANNEL_CREATORSIGNER);

        await EPNSCoreV1Proxy.connect(ADMINSIGNER).setStakeEpochDuration(604800);
        const tx_StakeStart = await EPNSCoreV1Proxy.connect(ADMINSIGNER).initiateNewStake();

        await stakePushTokens(BOBSIGNER, tokensBN(100));
        await stakePushTokens(ALICESIGNER, tokensBN(100));
        await stakePushTokens(CHARLIESIGNER, tokensBN(100));
        await stakePushTokens(CHANNEL_CREATORSIGNER, tokensBN(100));

        const bobBalance_before = await PushToken.balanceOf(BOB);

        const stakeStartBlock = bn(tx_StakeStart.blockNumber);
        // Afer Day 3, Bob completely Unstakes
        const BOB_BLOCK = stakeStartBlock.add(259200)		
        await jumpToBlockNumber(BOB_BLOCK.sub(1));

        await EPNSCoreV1Proxy.connect(BOBSIGNER).unStake();
        const bobBalance_after = await PushToken.balanceOf(BOB);
        
        const claimTx = EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards();

        // Ensures that unstakes transfers Stake Amount + Claimable Rewards for BOB
        const tokenAfterUnstake = bobBalance_after.sub(bobBalance_before);
        expect(tokenAfterUnstake).to.be.gt(tokensBN(100));
        expect(claimTx).to.be.revertedWith("EPNSCoreV2::claimRewards: Caller is not a Staker")
        
    })

  });
  
  describe("🟢 Initiate New Stake - After the END of a STAKE EPOCH ", function()
  { 

    it("Old Stakers Claims and Unstakes before new Stake Starts", async function(){
      // Initial Set-Up
      await createChannel(ALICESIGNER);
      await createChannel(BOBSIGNER);
      await createChannel(CHARLIESIGNER);


      await EPNSCoreV1Proxy.connect(ADMINSIGNER).setStakeEpochDuration(604800);
      const tx_StakeStart = await EPNSCoreV1Proxy.connect(ADMINSIGNER).initiateNewStake();
      await stakePushTokens(BOBSIGNER, tokensBN(100));
      await stakePushTokens(ALICESIGNER, tokensBN(100));
      await stakePushTokens(CHARLIESIGNER, tokensBN(100));

      const stakeStartBlock = bn(tx_StakeStart.blockNumber);
      
      const [BOB_BLOCK, ALICE_BLOCK, CHARLIE_BLOCK] = [
        stakeStartBlock.add(604800), 
        stakeStartBlock.add(604805), 
        stakeStartBlock.add(604810),
      ]	
      
      const startingRewardPool = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();

      await jumpToBlockNumber(BOB_BLOCK.sub(1));
      const tx_bob = await EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards();
      await jumpToBlockNumber(ALICE_BLOCK.sub(1));
      const tx_alice = await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();
      await jumpToBlockNumber(CHARLIE_BLOCK.sub(1));
      const tx_charlie = await EPNSCoreV1Proxy.connect(CHARLIESIGNER).claimRewards();
      
      const bobClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
      const aliceClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
      const charlieClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE);

      await EPNSCoreV1Proxy.connect(BOBSIGNER).unStake()
      await EPNSCoreV1Proxy.connect(ALICESIGNER).unStake()
      await EPNSCoreV1Proxy.connect(CHARLIESIGNER).unStake()

      const remainingRewards_1 = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
      const rewardRate_1 = await EPNSCoreV1Proxy.rewardRate();
      // Logs if needed
      console.log("\n⬇️ -- First Claim -- ⬇️")
      console.log('Reward Rate ', rewardRate_1.toString())
      console.log('Starting Reward POOL', startingRewardPool.toString())
      console.log(`\nBob Claimed ${bobClaim_after.toString()} tokens at Block number ${tx_bob.blockNumber}`);
      console.log(`Alice Claimed ${aliceClaim_after.toString()} tokens at Block number ${tx_alice.blockNumber}`);
      console.log(`Charlie Claimed ${charlieClaim_after.toString()} tokens at Block number ${tx_charlie.blockNumber}`);
      console.log('\nREMAINING Reward POOL', remainingRewards_1.toString())
      
      // Two new Users Create Channel
      await createChannel(USER_1_SIGNER);
      await createChannel(USER_2_SIGNER);
      await createChannel(USER_3_SIGNER);

      // Start a new EPOCH Cycle
      const tx_StakeStart_2nd = await EPNSCoreV1Proxy.connect(ADMINSIGNER).initiateNewStake();
      
      const stakeStartBlock_2nd = bn(tx_StakeStart_2nd.blockNumber);
    
      const [USER1_BLOCK, USER2_BLOCK, USER3_BLOCK] = [
        stakeStartBlock_2nd.add(604800), 
        stakeStartBlock_2nd.add(604805), 
        stakeStartBlock_2nd.add(604810), 
      ]

      stakePushTokens(USER_1_SIGNER, tokensBN(100));
      stakePushTokens(USER_2_SIGNER, tokensBN(100));
      stakePushTokens(USER_3_SIGNER, tokensBN(100));
      
      const startingRewardPool2nd = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();

      await jumpToBlockNumber(USER1_BLOCK.sub(1));
      const tx_user1 = await EPNSCoreV1Proxy.connect(USER_1_SIGNER).claimRewards();
      await jumpToBlockNumber(USER2_BLOCK.sub(1));
      const tx_user2 = await EPNSCoreV1Proxy.connect(USER_2_SIGNER).claimRewards();
      await jumpToBlockNumber(USER3_BLOCK.sub(1));
      const tx_user3 = await EPNSCoreV1Proxy.connect(USER_3_SIGNER).claimRewards();
     
      const user3Rewards = await EPNSCoreV1Proxy.usersRewardsClaimed(USER_3);
      const user1Rewards = await EPNSCoreV1Proxy.usersRewardsClaimed(USER_1);
      const user2Rewards = await EPNSCoreV1Proxy.usersRewardsClaimed(USER_2);

      const rewardRate_2 = await EPNSCoreV1Proxy.rewardRate();
      const remainingRewards_2 = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();

      console.log("\n⬇️ -- 2nd Claim -- ⬇️")
      console.log('REWARD RATE 2nd', rewardRate_2.toString())
      console.log('Starting Reward POOL', startingRewardPool2nd.toString())
      console.log(`\nUser1 Claimed ${user1Rewards.toString()} tokens at Block number ${tx_user1.blockNumber}`);
      console.log(`User2 Claimed ${user2Rewards.toString()} tokens at Block number ${tx_user2.blockNumber}`);
      console.log(`User3 Claimed ${user3Rewards.toString()} tokens at Block number ${tx_user3.blockNumber}`);
      console.log('\nREMAINING Reward POOL', remainingRewards_2.toString())

    })

    it("No Previous Stakers Unstakes before the New Stake Starts. They claim after the 2nd Epoch Ends", async function(){
      // Initial Set-Up
      await createChannel(ALICESIGNER);
      await createChannel(BOBSIGNER);
      await createChannel(CHARLIESIGNER);

      await EPNSCoreV1Proxy.connect(ADMINSIGNER).setStakeEpochDuration(604800);
      const tx_StakeStart = await EPNSCoreV1Proxy.connect(ADMINSIGNER).initiateNewStake();

      const startingRewardPool1st = await EPNSCoreV1Proxy.REWARD_POOL();
      await stakePushTokens(BOBSIGNER, tokensBN(100));
      await stakePushTokens(ALICESIGNER, tokensBN(100));
      await stakePushTokens(CHARLIESIGNER, tokensBN(100));
      
      // 7 Days Passes. First EPOCH Ends But no One Claims
      const stakeStartBlock = bn(tx_StakeStart.blockNumber);
      const after7_days = stakeStartBlock.add(604805);
      await jumpToBlockNumber(after7_days.sub(1));

      // Two new Users Create Channel
      await createChannel(USER_1_SIGNER);
      await createChannel(USER_2_SIGNER);
      await createChannel(USER_3_SIGNER);

      // Start a new EPOCH Cycle
      const tx_StakeStart_2nd = await EPNSCoreV1Proxy.connect(ADMINSIGNER).initiateNewStake();
      
      const stakeStartBlock_2nd = bn(tx_StakeStart_2nd.blockNumber);
    
      const [USER1_BLOCK, USER2_BLOCK, USER3_BLOCK, BOB_BLOCK, ALICE_BLOCK, CHARLIE_BLOCK] = [
        stakeStartBlock_2nd.add(604800), 
        stakeStartBlock_2nd.add(604805), 
        stakeStartBlock_2nd.add(604810), 
        stakeStartBlock_2nd.add(604815), 
        stakeStartBlock_2nd.add(604820), 
        stakeStartBlock_2nd.add(604825), 
      ]

      stakePushTokens(USER_1_SIGNER, tokensBN(100));
      stakePushTokens(USER_2_SIGNER, tokensBN(100));
      stakePushTokens(USER_3_SIGNER, tokensBN(100));
      
      const startingRewardPool2nd = await EPNSCoreV1Proxy.REWARD_POOL();

      await jumpToBlockNumber(USER1_BLOCK.sub(1));
      const tx_user1 = await EPNSCoreV1Proxy.connect(USER_1_SIGNER).claimRewards();
      await jumpToBlockNumber(USER2_BLOCK.sub(1));
      const tx_user2 = await EPNSCoreV1Proxy.connect(USER_2_SIGNER).claimRewards();
      await jumpToBlockNumber(USER3_BLOCK.sub(1));
      const tx_user3 = await EPNSCoreV1Proxy.connect(USER_3_SIGNER).claimRewards();
      // OLD STAKERS CLAIMING NOW 
      await jumpToBlockNumber(BOB_BLOCK.sub(1));
      const tx_bob = await EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards();
      await jumpToBlockNumber(ALICE_BLOCK.sub(1));
      const tx_alice = await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();
      await jumpToBlockNumber(CHARLIE_BLOCK.sub(1));
      const tx_charlie = await EPNSCoreV1Proxy.connect(CHARLIESIGNER).claimRewards();

      const user3Rewards = await EPNSCoreV1Proxy.usersRewardsClaimed(USER_3);
      const user1Rewards = await EPNSCoreV1Proxy.usersRewardsClaimed(USER_1);
      const user2Rewards = await EPNSCoreV1Proxy.usersRewardsClaimed(USER_2);

      
      const bobClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
      const aliceClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
      const charlieClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE);

      const remainingRewards_1 = await EPNSCoreV1Proxy.REWARD_POOL();
      const rewardRate_1 = await EPNSCoreV1Proxy.rewardRate();
      // // Logs if needed
      console.log("\n⬇️ -- First Claim of OLD STAKERS -- ⬇️")
      console.log('REWARD RATE 1st', rewardRate_1.toString())
      console.log('Starting Reward POOL', startingRewardPool1st.toString())
      console.log(`\nBob Claimed ${bobClaim_after.toString()} tokens at Block number ${tx_bob.blockNumber}`);
      console.log(`Alice Claimed ${aliceClaim_after.toString()} tokens at Block number ${tx_alice.blockNumber}`);
      console.log(`Charlie Claimed ${charlieClaim_after.toString()} tokens at Block number ${tx_charlie.blockNumber}`);
      console.log('\nREMAINING Reward POOL', remainingRewards_1.toString())

      const rewardRate_2 = await EPNSCoreV1Proxy.rewardRate();
      const remainingRewards_2 = await EPNSCoreV1Proxy.REWARD_POOL();

      console.log("\n⬇️ -- 2nd Claim -- ⬇️")
      console.log('REWARD RATE 2nd', rewardRate_2.toString())
      console.log('Starting Reward POOL', startingRewardPool2nd.toString())
      console.log(`\nUser1 Claimed ${user1Rewards.toString()} tokens at Block number ${tx_user1.blockNumber}`);
      console.log(`User2 Claimed ${user2Rewards.toString()} tokens at Block number ${tx_user2.blockNumber}`);
      console.log(`User3 Claimed ${user3Rewards.toString()} tokens at Block number ${tx_user3.blockNumber}`);
      console.log('\nREMAINING Reward POOL', remainingRewards_2.toString())

    })

    it("ONE Old Stakers doesn't Claim and Unstakes before new Stake Starts", async function(){
      // Initial Set-Up
      await createChannel(ALICESIGNER);
      await createChannel(BOBSIGNER);
      await createChannel(CHARLIESIGNER);


      await EPNSCoreV1Proxy.connect(ADMINSIGNER).setStakeEpochDuration(604800);
      const tx_StakeStart = await EPNSCoreV1Proxy.connect(ADMINSIGNER).initiateNewStake();
      await stakePushTokens(BOBSIGNER, tokensBN(100));
      await stakePushTokens(ALICESIGNER, tokensBN(100));
      await stakePushTokens(CHARLIESIGNER, tokensBN(100));

      const stakeStartBlock = bn(tx_StakeStart.blockNumber);
      
      const [BOB_BLOCK, ALICE_BLOCK] = [
        stakeStartBlock.add(604800), 
        stakeStartBlock.add(604805), 
      ]	
      
      const startingRewardPool = await EPNSCoreV1Proxy.REWARD_POOL();

      await jumpToBlockNumber(BOB_BLOCK.sub(1));
      const tx_bob = await EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards();
      await jumpToBlockNumber(ALICE_BLOCK.sub(1));
      const tx_alice = await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();

      const bobClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
      const aliceClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);

      await EPNSCoreV1Proxy.connect(BOBSIGNER).unStake()
      await EPNSCoreV1Proxy.connect(ALICESIGNER).unStake()

      const remainingRewards_1 = await EPNSCoreV1Proxy.REWARD_POOL();
      const rewardRate_1 = await EPNSCoreV1Proxy.rewardRate();
      // Logs if needed
      console.log("\n⬇️ -- First Claim -- ⬇️")
      console.log('Reward Rate ', rewardRate_1.toString())
      console.log('Starting Reward POOL', startingRewardPool.toString())
      console.log(`\nBob Claimed ${bobClaim_after.toString()} tokens at Block number ${tx_bob.blockNumber}`);
      console.log(`Alice Claimed ${aliceClaim_after.toString()} tokens at Block number ${tx_alice.blockNumber}`);
      console.log('\nREMAINING Reward POOL', remainingRewards_1.toString())
      
      // Two new Users Create Channel
      await createChannel(USER_1_SIGNER);
      await createChannel(USER_2_SIGNER);
      await createChannel(USER_3_SIGNER);

      const poolFeeNow = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES()
      console.log(poolFeeNow.toString())
      // Start a new EPOCH Cycle
      const tx_StakeStart_2nd = await EPNSCoreV1Proxy.connect(ADMINSIGNER).initiateNewStake();
      
      const stakeStartBlock_2nd = bn(tx_StakeStart_2nd.blockNumber);
    
      const [USER1_BLOCK, USER2_BLOCK, USER3_BLOCK, CHARLIE_BLOCK] = [
        stakeStartBlock_2nd.add(604800), 
        stakeStartBlock_2nd.add(604805), 
        stakeStartBlock_2nd.add(604810), 
        stakeStartBlock_2nd.add(604815),
      ]

      stakePushTokens(USER_1_SIGNER, tokensBN(100));
      stakePushTokens(USER_2_SIGNER, tokensBN(100));
      stakePushTokens(USER_3_SIGNER, tokensBN(100));
      
      const startingRewardPool2nd = await EPNSCoreV1Proxy.REWARD_POOL();

      await jumpToBlockNumber(USER1_BLOCK.sub(1));
      const tx_user1 = await EPNSCoreV1Proxy.connect(USER_1_SIGNER).claimRewards();
      await jumpToBlockNumber(USER2_BLOCK.sub(1));
      const tx_user2 = await EPNSCoreV1Proxy.connect(USER_2_SIGNER).claimRewards();
      await jumpToBlockNumber(USER3_BLOCK.sub(1));
      const tx_user3 = await EPNSCoreV1Proxy.connect(USER_3_SIGNER).claimRewards();
      await jumpToBlockNumber(CHARLIE_BLOCK.sub(1));
      const tx_charlie = await EPNSCoreV1Proxy.connect(CHARLIESIGNER).claimRewards();
     
      const user3Rewards = await EPNSCoreV1Proxy.usersRewardsClaimed(USER_3);
      const user1Rewards = await EPNSCoreV1Proxy.usersRewardsClaimed(USER_1);
      const user2Rewards = await EPNSCoreV1Proxy.usersRewardsClaimed(USER_2);
      const charlieClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE);

      const rewardRate_2 = await EPNSCoreV1Proxy.rewardRate();
      const remainingRewards_2 = await EPNSCoreV1Proxy.REWARD_POOL();

      console.log("\n⬇️ -- 2nd Claim -- ⬇️")
      console.log('REWARD RATE 2nd', rewardRate_2.toString())
      console.log('Starting Reward POOL', startingRewardPool2nd.toString())
      console.log(`\nUser1 Claimed ${user1Rewards.toString()} tokens at Block number ${tx_user1.blockNumber}`);
      console.log(`User2 Claimed ${user2Rewards.toString()} tokens at Block number ${tx_user2.blockNumber}`);
      console.log(`User3 Claimed ${user3Rewards.toString()} tokens at Block number ${tx_user3.blockNumber}`);
      console.log(`Charlie Claimed ${charlieClaim_after.toString()} tokens at Block number ${tx_charlie.blockNumber}`);
      console.log('\nREMAINING Reward POOL', remainingRewards_2.toString())

    })

    it("TWO Old Stakers doesn't Claim and Unstakes before new Stake Starts", async function(){
      // Initial Set-Up
      await createChannel(ALICESIGNER);
      await createChannel(BOBSIGNER);
      await createChannel(CHARLIESIGNER);


      await EPNSCoreV1Proxy.connect(ADMINSIGNER).setStakeEpochDuration(604800);
      const tx_StakeStart = await EPNSCoreV1Proxy.connect(ADMINSIGNER).initiateNewStake();
      await stakePushTokens(BOBSIGNER, tokensBN(100));
      await stakePushTokens(ALICESIGNER, tokensBN(100));
      await stakePushTokens(CHARLIESIGNER, tokensBN(100));

      const stakeStartBlock = bn(tx_StakeStart.blockNumber);
      
      const [BOB_BLOCK] = [
        stakeStartBlock.add(604801), 
      ]	
      
      const startingRewardPool = await EPNSCoreV1Proxy.REWARD_POOL();

      await jumpToBlockNumber(BOB_BLOCK.sub(1));
      const tx_bob = await EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards();

      const bobClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);

      await EPNSCoreV1Proxy.connect(BOBSIGNER).unStake()

      const remainingRewards_1 = await EPNSCoreV1Proxy.REWARD_POOL();
      const rewardRate_1 = await EPNSCoreV1Proxy.rewardRate();
      // Logs if needed
      console.log("\n⬇️ -- First Claim -- ⬇️")
      console.log('Reward Rate ', rewardRate_1.toString())
      console.log('Starting Reward POOL', startingRewardPool.toString())
      console.log(`\nBob Claimed ${bobClaim_after.toString()} tokens at Block number ${tx_bob.blockNumber}`);
      console.log('\nREMAINING Reward POOL', remainingRewards_1.toString())
      
      // Two new Users Create Channel
      await createChannel(USER_1_SIGNER);
      await createChannel(USER_2_SIGNER);
      await createChannel(USER_3_SIGNER);

      const poolFeeNow = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES()
      console.log(poolFeeNow.toString())
      // Start a new EPOCH Cycle
      const tx_StakeStart_2nd = await EPNSCoreV1Proxy.connect(ADMINSIGNER).initiateNewStake();
      
      const stakeStartBlock_2nd = bn(tx_StakeStart_2nd.blockNumber);
    
      const [USER1_BLOCK, USER2_BLOCK, USER3_BLOCK, CHARLIE_BLOCK, ALICE_BLOCK] = [
        stakeStartBlock_2nd.add(604800), 
        stakeStartBlock_2nd.add(604805), 
        stakeStartBlock_2nd.add(604810), 
        stakeStartBlock_2nd.add(604815),
        stakeStartBlock_2nd.add(604825),
      ]

      stakePushTokens(USER_1_SIGNER, tokensBN(100));
      stakePushTokens(USER_2_SIGNER, tokensBN(100));
      stakePushTokens(USER_3_SIGNER, tokensBN(100));
      
      const startingRewardPool2nd = await EPNSCoreV1Proxy.REWARD_POOL();

      await jumpToBlockNumber(USER1_BLOCK.sub(1));
      const tx_user1 = await EPNSCoreV1Proxy.connect(USER_1_SIGNER).claimRewards();
      await jumpToBlockNumber(USER2_BLOCK.sub(1));
      const tx_user2 = await EPNSCoreV1Proxy.connect(USER_2_SIGNER).claimRewards();
      await jumpToBlockNumber(USER3_BLOCK.sub(1));
      const tx_user3 = await EPNSCoreV1Proxy.connect(USER_3_SIGNER).claimRewards();
      await jumpToBlockNumber(CHARLIE_BLOCK.sub(1));
      const tx_charlie = await EPNSCoreV1Proxy.connect(CHARLIESIGNER).claimRewards();
      await jumpToBlockNumber(ALICE_BLOCK.sub(1));
      const tx_alice = await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();
     
      const user3Rewards = await EPNSCoreV1Proxy.usersRewardsClaimed(USER_3);
      const user1Rewards = await EPNSCoreV1Proxy.usersRewardsClaimed(USER_1);
      const user2Rewards = await EPNSCoreV1Proxy.usersRewardsClaimed(USER_2);
      const charlieClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE);
      const aliceClaim_after = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);

      const rewardRate_2 = await EPNSCoreV1Proxy.rewardRate();
      const remainingRewards_2 = await EPNSCoreV1Proxy.REWARD_POOL();

      console.log("\n⬇️ -- 2nd Claim -- ⬇️")
      console.log('REWARD RATE 2nd', rewardRate_2.toString())
      console.log('Starting Reward POOL', startingRewardPool2nd.toString())
      console.log(`\nUser1 Claimed ${user1Rewards.toString()} tokens at Block number ${tx_user1.blockNumber}`);
      console.log(`User2 Claimed ${user2Rewards.toString()} tokens at Block number ${tx_user2.blockNumber}`);
      console.log(`User3 Claimed ${user3Rewards.toString()} tokens at Block number ${tx_user3.blockNumber}`);
      console.log(`Alice Claimed ${aliceClaim_after.toString()} tokens at Block number ${tx_alice.blockNumber}`);
      console.log(`Charlie Claimed ${charlieClaim_after.toString()} tokens at Block number ${tx_charlie.blockNumber}`);
      console.log('\nREMAINING Reward POOL', remainingRewards_2.toString())

    })
  });
 
  describe("🟢 Initiate New Stake - During an On-Going Staketeh a ", function()
  {


  });
});

});