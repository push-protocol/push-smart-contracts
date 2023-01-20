const { ethers, waffle } = require("hardhat");

const { tokensBN } = require("../../helpers/utils");

const { epnsContractFixture, tokenFixture } = require("../common/fixturesV2");
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

  });
  /***
   * CHECKPOINTS TO CONSIDER WHILE TESTING -> Overall Stake-N-Claim Tests
   * ------------------------------------------
   * 1. Stake
   *  - Staking function should execute as expected-Updates user's staked amount, PUSH transfer etc ✅
   *  - FIRST stake should update user's stakedWeight, stakedAmount and other imperative details accurately
   *  - Consecutive stakes should update details accurately: 2 cases
   *    - a. User staking again in same epoch, Should add user's stake details in the same epoch
   *    - b. User staking in different epoch, should update the epoch's in between with last epoch details - and last epoch with latest details
   * 
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
   *  - Verify that total reward actually gets distrubuted between stakers in one given epoch ✅
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
   * 
   */

  describe("EPNS CORE V2: Stake and Claim Tests", () => {
    const CHANNEL_TYPE = 2;
    const EPOCH_DURATION = 20 * 7160 // number of blocks = 143200 
    const TEST_CHANNEL_CTX = ethers.utils.toUtf8Bytes(
      "test-channel-hello-world"
    );

    beforeEach(async function () {
        /** INITIAL SET-UP **/
      await EPNSCoreV1Proxy.connect(ADMINSIGNER).setMinPoolContribution(
        ethers.utils.parseEther('1')
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
      
      await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));
      await EPNSCoreV1Proxy.connect(ADMINSIGNER).initializeStake();
      // await PushToken.connect(ALICESIGNER).setHolderDelegation(
      //   EPNSCoreV1Proxy.address,
      //   true
      // );
    });
    //*** Helper Functions - Related to Channel, Tokens and Stakes ***//
    const addPoolFees = async (signer, amount) => {
      await EPNSCoreV1Proxy.connect(signer).addPoolFees(amount);
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
    }

    /** ⛔️ Not used currently - Prefer using passBlockNumbers **/
    const jumpToBlockNumber = async (blockNumber) => {
      blockNumber = blockNumber.toNumber();
      const currentBlock = await ethers.provider.getBlock("latest");
      const numBlockToIncrease = blockNumber - currentBlock.number;
      const blockIncreaseHex = `0x${numBlockToIncrease.toString(16)}`;
      await ethers.provider.send("hardhat_mine", [blockIncreaseHex]);
    };

    const passBlockNumers = async(blockNumber)=>{
      blockNumber = `0x${blockNumber.toString(16)}`;
      await ethers.provider.send("hardhat_mine", [blockNumber]);
    }

    const claimRewardsInSingleBlock = async (signers) => {
      await ethers.provider.send("evm_setAutomine", [false]);
      await Promise.all(
        signers.map((signer) => EPNSCoreV1Proxy.connect(signer).harvestAll())
      );
      await network.provider.send("evm_mine");
      await ethers.provider.send("evm_setAutomine", [true]);
    };

    const getUserTokenWeight = async (user, amount, atBlock) =>{
      const holderWeight = await PushToken.holderWeight(user);
      return amount.mul(atBlock - holderWeight);
    }

    const getRewardsClaimed = async (signers) => {
      return await Promise.all(
        signers.map((signer) => EPNSCoreV1Proxy.usersRewardsClaimed(signer))
      );
    };

    const getEachEpochDetails = async(user, totalEpochs) =>{
      for(i = 1; i <= totalEpochs; i++){
        // var reward = await EPNSCoreV1Proxy.epochRewards(i);

        // const userData = await EPNSCoreV1Proxy.userFeesInfo(BOB);
        // var userStakedWeight = userData.epochToUserStakedWeight(i);
        var epochToTotalWeight = await EPNSCoreV1Proxy.epochToTotalStakedWeight(i);
        var epochRewardsStored = await EPNSCoreV1Proxy.epochRewards(i);
        const userEpochToStakedWeight = await EPNSCoreV1Proxy.getUserEpochToWeight(user, i);
        //const userStakedWeight = await EPNSCoreV1Proxy.userFeesInfo(user);
        //var tempVal = await EPNSCoreV1Proxy.epochToUserStakedWeightt();

        console.log('\n EACH EPOCH DETAILS ');
        // console.log(`EPOCH to Total Weight for EPOCH ID ${i} is ${userStakedWeight}`)
        console.log(`EPOCH to Total Weight for EPOCH ID ${i} is ${epochToTotalWeight}`)
        console.log(`EPOCH Rewards for EPOCH ID ${i} is ${epochRewardsStored}`)
        //console.log(`USER STAKED WEIGHT for EPOCH ID ${i} is ${userStakedWeight.stakedWeight}`)
        console.log(`userEpochToStakedWeight for EPOCH ID ${i} is ${userEpochToStakedWeight}`)
        // console.log(`\n TEMP VAL ${i} is ${tempVal}`)

       // console.log(userStakedWeight.epochToUserStakedWeight)
      }
    }

/** Test Cases Starts Here **/

   /* CHECKPOINTS: lastEpochRelative() function 
    * Should Reverts on overflow
    * Should calculate relative epoch numbers accurately
    * Shouldn't change epoch value if epoch "to" block number lies in same epoch boundry
    * **/
    describe("🟢 lastEpochRelative Tests ", function()
    {

      it.skip("Should revert on Block number overflow", async function(){
        const genesisBlock = await getCurrentBlock()
        await passBlockNumers(2*EPOCH_DURATION);
        const futureBlock = await getCurrentBlock();

        const tx = EPNSCoreV1Proxy.lastEpochRelative(futureBlock.number, genesisBlock.number);
        await expect(tx).to.be.revertedWith("EPNSCoreV2:lastEpochRelative:: Relative Blocnumber Overflow");
      })

      it.skip("Should calculate relative epoch numbers accurately", async function(){
        const genesisBlock = await getCurrentBlock()
        await passBlockNumers(5*EPOCH_DURATION);
        const futureBlock = await getCurrentBlock();

        const epochID = await EPNSCoreV1Proxy.lastEpochRelative(genesisBlock.number, futureBlock.number);
        await expect(epochID).to.be.equal(6);
      })

      it.skip("Shouldn't change epoch value if '_to' block lies in same epoch boundary", async function(){
        const genesisBlock = await getCurrentBlock()
        await passBlockNumers(EPOCH_DURATION/2);
        const futureBlock = await getCurrentBlock();

        const epochID = await EPNSCoreV1Proxy.lastEpochRelative(genesisBlock.number, futureBlock.number);
        await expect(epochID).to.be.equal(1);
      })
      // User A stakes: Check lastStakedEpoch, lastClaimedEpoch 
      it.skip("Should count staked EPOCH of user correctly", async function(){
        await addPoolFees(ADMINSIGNER, tokensBN(200))
        const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
        const passBlocks = 5;

        await passBlockNumers(passBlocks * EPOCH_DURATION);
        await stakePushTokens(BOBSIGNER, tokensBN(10));

        const bobDetails_2nd = await EPNSCoreV1Proxy.userFeesInfo(BOB);
        const userLastStakedEpochId = await EPNSCoreV1Proxy.lastEpochRelative(genesisEpoch.toNumber(), bobDetails_2nd.lastStakedBlock.toNumber());
        const userLastClaimedEpochId = await EPNSCoreV1Proxy.lastEpochRelative(genesisEpoch.toNumber(), bobDetails_2nd.lastClaimedBlock.toNumber());

        await expect(userLastClaimedEpochId).to.be.equal(1); // Epoch 1 - since no claim done yet
        await expect(userLastStakedEpochId).to.be.equal(passBlocks + 1);
      })

      it.skip("Should track User's Staked and Harvest block accurately", async function(){
        const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
        const fiveBlocks = 5;
        const tenBlocks = 10;

        await passBlockNumers(fiveBlocks * EPOCH_DURATION);
        // Stakes Push Tokens after 5 blocks, at 6th EPOCH
        await stakePushTokens(BOBSIGNER, tokensBN(10));
        const bobDetails_afterStake = await EPNSCoreV1Proxy.userFeesInfo(BOB);
        const userLastStakedEpochId = await EPNSCoreV1Proxy.lastEpochRelative(genesisEpoch.toNumber(), bobDetails_afterStake.lastStakedBlock.toNumber());

        await passBlockNumers(tenBlocks * EPOCH_DURATION);
        // Harvests Push Tokens after 15 blocks, at 16th EPOCH
        await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAll();
        const bobDetails_afterClaim = await EPNSCoreV1Proxy.userFeesInfo(BOB);
        const userLastClaimedEpochId = await EPNSCoreV1Proxy.lastEpochRelative(genesisEpoch.toNumber(), bobDetails_afterClaim.lastClaimedBlock.toNumber());

        await expect(userLastStakedEpochId).to.be.equal(fiveBlocks + 1);
        await expect(userLastClaimedEpochId).to.be.equal(16);
      })

      it("TEST CHECKS", async function(){
        const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
        const fiveBlocks = 1;
        const tenBlocks = 5;
       
        await passBlockNumers(fiveBlocks * EPOCH_DURATION);
        // const poolFee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
        // console.log('POOL FEE - ', poolFee.toString())

        await stakePushTokens(BOBSIGNER, tokensBN(100));
        const bobDetails_afterStake = await EPNSCoreV1Proxy.userFeesInfo(BOB);
        const userLastStakedEpochId = await EPNSCoreV1Proxy.lastEpochRelative(genesisEpoch.toNumber(), bobDetails_afterStake.lastStakedBlock.toNumber());

        await passBlockNumers(tenBlocks * EPOCH_DURATION);
        // // Harvests Push Tokens after 15 blocks, at 16th EPOCH
        await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAll();
        await getEachEpochDetails(BOB, 11);

        // await EPNSCoreV1Proxy.setUserEpochToWeight(BOB, 1, tokensBN(14322300))
        // const epochToStakedWeight = await EPNSCoreV1Proxy.connect(BOBSIGNER).getUserEpochToWeight(1);
        // console.log(epochToStakedWeight.toNumber())

        const rewards = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
        console.log('\n REWARDS OF BOB',rewards.toString())


        // console.log('\n BOBs Details ')
        // const bobDetails = await EPNSCoreV1Proxy.userFeesInfo(BOB);
        // console.log(bobDetails)
        // const bobDetails_afterClaim = await EPNSCoreV1Proxy.userFeesInfo(BOB);
        // const userLastClaimedEpochId = await EPNSCoreV1Proxy.lastEpochRelative(genesisEpoch.toNumber(), bobDetails_afterClaim.lastClaimedBlock.toNumber());


      })

    });

    describe("🟢 calcEpochRewards Tests ", function()
    {

    });

    describe("🟢 Stake Tests ", function()
    {

    });

    describe("🟢 unStake Tests ", function()
    {

    });

    describe("🟢 Harvesting Rewards Tests ", function()
    {

    });
    
    describe("🟢 daoHarvest Rewards Tests ", function()
    {

    });

/**Test Cases Ends Here **/
  });
});