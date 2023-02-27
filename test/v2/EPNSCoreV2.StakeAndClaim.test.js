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
      
      await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));
      await EPNSCoreV1Proxy.connect(ADMINSIGNER).initializeStake();
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

    const getLastStakedEpoch = async(user) => {
      const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
      var userDetails = await EPNSCoreV1Proxy.userFeesInfo(user);

      const lastStakedEpoch = await EPNSCoreV1Proxy.lastEpochRelative(genesisEpoch.toNumber(), userDetails.lastStakedBlock.toNumber());
      return lastStakedEpoch;
    }

    const getLastRewardClaimedEpoch = async(user) => {
      const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
      var userDetails = await EPNSCoreV1Proxy.userFeesInfo(user);

      const lastClaimedEpoch = await EPNSCoreV1Proxy.lastEpochRelative(genesisEpoch.toNumber(), userDetails.lastClaimedBlock.toNumber());
      return lastClaimedEpoch;
    }

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
      for(i = 0; i <= totalEpochs; i++){
        var epochToTotalWeight = await EPNSCoreV1Proxy.epochToTotalStakedWeight(i);
        var epochRewardsStored = await EPNSCoreV1Proxy.epochRewards(i);
        const userEpochToStakedWeight = await EPNSCoreV1Proxy.getUserEpochToWeight(user, i);
        
        console.log('\n EACH EPOCH DETAILS ');
        console.log(`EPOCH Rewards for EPOCH ID ${i} is ${epochRewardsStored}`)
        console.log(`EPOCH to Total Weight for EPOCH ID ${i} is ${epochToTotalWeight}`)
        console.log(`userEpochToStakedWeight for EPOCH ID ${i} is ${userEpochToStakedWeight}`)
      }
    }

/** Test Cases Starts Here **/

   /* CHECKPOINTS: lastEpochRelative() function 
    * Should Reverts on overflow
    * Should calculate relative epoch numbers accurately
    * Shouldn't change epoch value if epoch "to" block number lies in same epoch boundry
    * User BOB stakes: Ensure epochIDs of lastStakedEpoch and lastClaimedEpoch are recorded accurately 
    * User BOB stakes & then Harvests: Ensure epochIDs of lastStakedEpoch and lastClaimedEpoch are updated accurately 
    * **/
    describe("🟢 lastEpochRelative Tests ", function()
    {

      it("Should revert on Block number overflow", async function(){
        const genesisBlock = await getCurrentBlock()
        await passBlockNumers(2*EPOCH_DURATION);
        const futureBlock = await getCurrentBlock();

        const tx = EPNSCoreV1Proxy.lastEpochRelative(futureBlock.number, genesisBlock.number);
        await expect(tx).to.be.revertedWith("EPNSCoreV2:lastEpochRelative:: Relative Blocnumber Overflow");
      })

      it("Should calculate relative epoch numbers accurately", async function(){
        const genesisBlock = await getCurrentBlock()
        await passBlockNumers(5*EPOCH_DURATION);
        const futureBlock = await getCurrentBlock();

        const epochID = await EPNSCoreV1Proxy.lastEpochRelative(genesisBlock.number, futureBlock.number);
        await expect(epochID).to.be.equal(6);
      })

      it("Shouldn't change epoch value if '_to' block lies in same epoch boundary", async function(){
        const genesisBlock = await getCurrentBlock()
        await passBlockNumers(EPOCH_DURATION/2);
        const futureBlock = await getCurrentBlock();

        const epochID = await EPNSCoreV1Proxy.lastEpochRelative(genesisBlock.number, futureBlock.number);
        await expect(epochID).to.be.equal(1);
      })
  
      it("Should count staked EPOCH of user correctly", async function(){
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

      it("Should track User's Staked and Harvest block accurately", async function(){
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
        await expect(userLastClaimedEpochId).to.be.equal(fiveBlocks + tenBlocks + 1);
      })

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
     * Unstake function is only accessible for actual stakers
     * Unstaked users cannot claim any further rewards
     * Staking and Unstaking in same epoch doesn't lead to any rewards
     * User Fees Info is accurately updated after unstake
     * 
     * 
     */

    describe("🟢 Stake Tests ", function()
    {
      it("User stakes 3 times in a single epoch - user and total weights should update accuratley ✅", async function(){
        const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
        const stakeAmount = tokensBN(100);
        const bobDetails = await EPNSCoreV1Proxy.userFeesInfo(BOB);
        const userWeight = await bobDetails.stakedWeight;
        expect(userWeight).to.be.equal(0);
        
        //Stakes for 1st time
        let holderweight = await PushToken.holderWeight(BOB);
        holderweight = holderweight.toString();
        await stakePushTokens(BOBSIGNER, stakeAmount);
        let currentBlock = await getCurrentBlock();
        let blocknumber = currentBlock.number;
        let bobDetails_afterStake = await EPNSCoreV1Proxy.userFeesInfo(BOB);
        let userWeight_afterStake = await bobDetails_afterStake.stakedWeight;
        expect(userWeight_afterStake).to.be.equal((stakeAmount.mul(blocknumber - holderweight)));

        //Stakes for 2nd time
        let bobDetails_beforeStake = await EPNSCoreV1Proxy.userFeesInfo(BOB);
        let userWeight_beforeStake = await bobDetails_beforeStake.stakedWeight;
        await stakePushTokens(BOBSIGNER, stakeAmount);
        currentBlock = await getCurrentBlock();
        blocknumber = currentBlock.number;
        holderweight = await PushToken.holderWeight(BOB);
        holderweight = holderweight.toString();
        bobDetails_afterStake = await EPNSCoreV1Proxy.userFeesInfo(BOB);
        userWeight_afterStake = await bobDetails_afterStake.stakedWeight;
        expect(userWeight_afterStake).to.be.equal(userWeight_beforeStake.add((stakeAmount.mul(blocknumber - holderweight))));

        //Stakes for 3rd time
        bobDetails_beforeStake = await EPNSCoreV1Proxy.userFeesInfo(BOB);
        userWeight_beforeStake = await bobDetails_beforeStake.stakedWeight;
        await stakePushTokens(BOBSIGNER, stakeAmount);
        currentBlock = await getCurrentBlock();
        blocknumber = currentBlock.number;
        holderweight = await PushToken.holderWeight(BOB);
        holderweight = holderweight.toString();
        bobDetails_afterStake = await EPNSCoreV1Proxy.userFeesInfo(BOB);
        userWeight_afterStake = await bobDetails_afterStake.stakedWeight;
        expect(userWeight_afterStake).to.be.equal(userWeight_beforeStake.add((stakeAmount.mul(blocknumber - holderweight))));
      });

      it("3 users stakes 1 time in a single epoch - total weights should update accuratley ✅", async function(){
        const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
        const stakeAmount = tokensBN(100);

        await stakePushTokens(BOBSIGNER, stakeAmount);
        let bobcurrentblock = await getCurrentBlock();
        let bobblocknumber = bobcurrentblock.number;

        await stakePushTokens(ALICESIGNER, stakeAmount);
        let alicecurrentblock = await getCurrentBlock();
        let aliceblocknumber = alicecurrentblock.number;

        await stakePushTokens(CHARLIESIGNER, stakeAmount);
        let charliecurrentblock = await getCurrentBlock();
        let charlieblocknumber = charliecurrentblock.number;

        let bobdetails = await EPNSCoreV1Proxy.userFeesInfo(BOB);
        let bobweight = await bobdetails.stakedWeight;
        let alicedetails = await EPNSCoreV1Proxy.userFeesInfo(ALICE);
        let aliceweight = await alicedetails.stakedWeight;
        let charliedetails = await EPNSCoreV1Proxy.userFeesInfo(CHARLIE);
        let charlieweight = await charliedetails.stakedWeight;
        
        let bobholderweight = await PushToken.holderWeight(BOB);
        bobholderweight = bobholderweight.toString();
        let aliceholderweight = await PushToken.holderWeight(ALICE);
        aliceholderweight = aliceholderweight.toString();
        let charlieholderweight = await PushToken.holderWeight(CHARLIE);
        charlieholderweight = charlieholderweight.toString();

        expect(bobweight).to.be.equal((stakeAmount.mul(bobblocknumber - bobholderweight)));
        expect(aliceweight).to.be.equal((stakeAmount.mul(aliceblocknumber - aliceholderweight)));
        expect(charlieweight).to.be.equal((stakeAmount.mul(charlieblocknumber - charlieholderweight)));
      });

      it("Bob should not get rewards for staking and unstaking at same epoch", async function(){
        const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
        const stakeAmount = tokensBN(100);
        const totalPoolFee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();

        const bobDetails = await EPNSCoreV1Proxy.userFeesInfo(BOB);
        const userWeight = await bobDetails.stakedWeight;
        expect(userWeight).to.be.equal(0);
        const fourEpochs=4;

        await stakePushTokens(BOBSIGNER, stakeAmount);
        await passBlockNumers(fourEpochs * EPOCH_DURATION);
        await stakePushTokens(BOBSIGNER, stakeAmount);
        await EPNSCoreV1Proxy.connect(BOBSIGNER).unstake();
        const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
        expect(ethers.BigNumber.from(rewards_bob)).to.be.closeTo(ethers.BigNumber.from(totalPoolFee), ethers.utils.parseEther("10"));
      });

      it("Bob stakes at epoch 1 and again at epoch 5 user weight should update accurately ✅", async function(){
        const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
        const stakeAmount = tokensBN(100);
        const fourEpochs=4;

        await stakePushTokens(BOBSIGNER, stakeAmount);
        bobDetails = await EPNSCoreV1Proxy.userFeesInfo(BOB);
        let userWeight_1 = await bobDetails.stakedWeight;

        await passBlockNumers(fourEpochs * EPOCH_DURATION);
        await stakePushTokens(BOBSIGNER, stakeAmount);
        let currentBlock = await getCurrentBlock();
        let blocknumber = currentBlock.number;
        let holderweight = await PushToken.holderWeight(BOB);
        holderweight = holderweight.toString();
        const userWeight = (stakeAmount.mul(blocknumber - holderweight));

        bobDetails = await EPNSCoreV1Proxy.userFeesInfo(BOB);
        let userWeight_2 = await bobDetails.stakedWeight;


        expect(userWeight_2).to.be.equal(userWeight_1.add(userWeight));

      });

      it("Bob unstakes stakes and again unstakes at the same epoch, should not get any rewards", async function(){
        const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
        const stakeAmount = tokensBN(100);
        const bobDetails = await EPNSCoreV1Proxy.userFeesInfo(BOB);
        const userWeight = await bobDetails.stakedWeight;
        expect(userWeight).to.be.equal(0);
        const fourEpochs=4;

        await stakePushTokens(BOBSIGNER, stakeAmount);
        await passBlockNumers(fourEpochs * EPOCH_DURATION);
        await EPNSCoreV1Proxy.connect(BOBSIGNER).unstake();
        const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
        await stakePushTokens(BOBSIGNER, stakeAmount);
        passBlockNumers(EPOCH_DURATION/2);
        await EPNSCoreV1Proxy.connect(BOBSIGNER).unstake();
        const rewards_bob2 = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
        expect(rewards_bob2).to.be.equal(rewards_bob);
      });

      it("Bob stakes after 5 epoch and unstake at the same epoch", async function(){
        const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
        const stakeAmount = tokensBN(100);
        const bobDetails = await EPNSCoreV1Proxy.userFeesInfo(BOB);
        const userWeight = await bobDetails.stakedWeight;
        expect(userWeight).to.be.equal(0);
        const fourEpochs=4;

        await passBlockNumers(fourEpochs * EPOCH_DURATION);
        await stakePushTokens(BOBSIGNER, stakeAmount);
        await passBlockNumers(EPOCH_DURATION/2);        
        await EPNSCoreV1Proxy.connect(BOBSIGNER).unstake();
        const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
        expect(rewards_bob).to.be.equal("0");
      })

      it("Bob stakes at epoch 1 and unstakes at epoch 5, also Alice stakes and unstake at epoch 5 :", async function(){
        const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
        const stakeAmount = tokensBN(100);
        const totalPoolFee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();

        const bobDetails = await EPNSCoreV1Proxy.userFeesInfo(BOB);
        const userWeight = await bobDetails.stakedWeight;
        expect(userWeight).to.be.equal(0);
        const fourEpochs=4;

        await stakePushTokens(BOBSIGNER, stakeAmount);
        await passBlockNumers(fourEpochs * EPOCH_DURATION);
        await stakePushTokens(ALICESIGNER, stakeAmount);  
        await passBlockNumers(EPOCH_DURATION/2);
        await EPNSCoreV1Proxy.connect(ALICESIGNER).unstake();
        await EPNSCoreV1Proxy.connect(BOBSIGNER).unstake();
        const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
        const rewards_alice = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
        expect(ethers.BigNumber.from(rewards_bob)).to.be.closeTo(ethers.BigNumber.from(totalPoolFee), ethers.utils.parseEther("10"));
        expect(rewards_alice).to.be.equal("0");
      });
    });

    describe("🟢 unStake Tests ", function()
    { 
      it("Unstaking allows users to Claim their pending rewards ✅", async function(){
        const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
        const oneEpochs= 1;
        const fiveEpochs= 5;
        const totalPoolFee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
        
        await passBlockNumers(oneEpochs * EPOCH_DURATION);
        await stakePushTokens(BOBSIGNER, tokensBN(100))
        await stakePushTokens(ALICESIGNER, tokensBN(100))
        // Fast Forward 5 epoch - Bob Unstakes
        await passBlockNumers(fiveEpochs * EPOCH_DURATION);
        await EPNSCoreV1Proxy.connect(BOBSIGNER).unstake();
        const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);

        expect(ethers.BigNumber.from(rewards_bob)).to.be.closeTo(ethers.BigNumber.from(totalPoolFee.div(2)), ethers.utils.parseEther("100"));

      })

      it("Unstaking function should update User's Detail accurately after unstake ✅", async function(){
        const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
        const oneEpochs= 1;
        const fiveEpochs= 5;
        const totalPoolFee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
        
        await passBlockNumers(oneEpochs * EPOCH_DURATION);
        await stakePushTokens(BOBSIGNER, tokensBN(100))
        await stakePushTokens(ALICESIGNER, tokensBN(100))
        // Fast Forward 5 epoch - Bob Unstakes
        await passBlockNumers(fiveEpochs * EPOCH_DURATION);
        await EPNSCoreV1Proxy.connect(BOBSIGNER).unstake();

        const bobDetails = await EPNSCoreV1Proxy.userFeesInfo(BOB);
        const currentBlock = await getCurrentBlock()
        await expect(bobDetails.stakedAmount).to.be.equal(0);
        await expect(bobDetails.stakedWeight).to.be.equal(0);
        await expect(bobDetails.lastClaimedBlock).to.be.equal(currentBlock.number);
      })

      it("Users cannot claim rewards after unstaking ✅", async function(){
        const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
        const oneEpochs= 1;
        const fiveEpochs= 5;
        const totalPoolFee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
        
        await passBlockNumers(oneEpochs * EPOCH_DURATION);
        await stakePushTokens(BOBSIGNER, tokensBN(100))
        await stakePushTokens(ALICESIGNER, tokensBN(100))
        // Fast Forward 5 epoch - Bob Unstakes
        await passBlockNumers(fiveEpochs * EPOCH_DURATION);
        await EPNSCoreV1Proxy.connect(BOBSIGNER).unstake();

        // Fast Forward 15 epoch - Bob tries to Unstake again
        await passBlockNumers(fiveEpochs * EPOCH_DURATION);
        const tx = EPNSCoreV1Proxy.connect(BOBSIGNER).unstake();
        
        await expect(tx).to.be.revertedWith("EPNSCoreV2::unstake: Caller is not a staker");
      })

      it("BOB Stakes and Unstakes in same Epoch- Should get ZERO rewards ✅", async function(){
        const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
        const oneEpochs= 1;
        const totalPoolFee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
        
        await passBlockNumers(oneEpochs * EPOCH_DURATION);
        await stakePushTokens(BOBSIGNER, tokensBN(100))
        // Fast Forward 1/2 epoch, lands in same EPOCH more epochs 
        await passBlockNumers(EPOCH_DURATION/2);
        await EPNSCoreV1Proxy.connect(BOBSIGNER).unstake();

        const bobLastStakedEpoch = await getLastStakedEpoch(BOB);
        const bobLastClaimedEpochId = await getLastRewardClaimedEpoch(BOB);
        const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);

        await expect(rewards_bob).to.be.equal(0);
        await expect(bobLastStakedEpoch).to.be.equal(oneEpochs+1);
        await expect(bobLastClaimedEpochId).to.be.equal(oneEpochs+1);
      })

      it("Unstaking function should transfer accurate amount of PUSH tokens to User ✅", async function(){
        const oneEpochs= 1;
        const fiveEpochs= 5;
        
        await passBlockNumers(oneEpochs * EPOCH_DURATION);
        await stakePushTokens(BOBSIGNER, tokensBN(100))
        await stakePushTokens(ALICESIGNER, tokensBN(100))
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
      })

    });

    describe("🟢 calcEpochRewards Tests: Calculating the accuracy of claimable rewards", function()
    {
      it("BOB Stakes at EPOCH 1 and Harvests alone- Should get all rewards ✅", async function(){
        const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
        const oneEpochs= 1;
        const fiveEpochs= 5;
        const totalPoolFee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
        
       // await passBlockNumers(oneEpochs * EPOCH_DURATION);
        await stakePushTokens(BOBSIGNER, tokensBN(100))
        // Fast Forward 5 more epochs 
        await passBlockNumers(fiveEpochs * EPOCH_DURATION);
        await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAll();

        const bobLastStakedEpoch = await getLastStakedEpoch(BOB);
        const bobLastClaimedEpochId = await getLastRewardClaimedEpoch(BOB);
        const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);

        await expect(bobLastStakedEpoch).to.be.equal(oneEpochs);
        await expect(bobLastClaimedEpochId).to.be.equal(fiveEpochs+1);
        expect(ethers.BigNumber.from(rewards_bob)).to.be.closeTo(ethers.BigNumber.from(totalPoolFee), ethers.utils.parseEther("10"));
      })

      it("BOB Stakes after EPOCH 1 and Harvests alone- Should get all rewards ✅", async function(){
        const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
        const oneEpochs= 1;
        const fiveEpochs= 5;
        const totalPoolFee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
        
        await passBlockNumers(oneEpochs * EPOCH_DURATION);
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));

        await stakePushTokens(BOBSIGNER, tokensBN(100))
        // Fast Forward 5 more epochs 
        await passBlockNumers(fiveEpochs * EPOCH_DURATION);
        await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAll();

        const bobLastStakedEpoch = await getLastStakedEpoch(BOB);
        const bobLastClaimedEpochId = await getLastRewardClaimedEpoch(BOB);
        const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
 
        await expect(bobLastStakedEpoch).to.be.equal(oneEpochs+1);
        await expect(bobLastClaimedEpochId).to.be.equal(oneEpochs+fiveEpochs+1);
        expect(ethers.BigNumber.from(rewards_bob)).to.be.closeTo(ethers.BigNumber.from(totalPoolFee), ethers.utils.parseEther("10"));
      })

      it("BOB & Alice Stakes(Same Amount) and Harvests together- Should get equal rewards ✅", async function(){
        const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
        const oneEpochs = 1;
        const fiveEpochs = 5;
        const totalPoolFee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
        const perStakerShare = totalPoolFee.div(2)

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
        const aliceLastClaimedEpochId = await getLastRewardClaimedEpoch(ALICE);
        const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);
        const rewards_alice = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);

        await expect(bobLastStakedEpoch).to.be.equal(oneEpochs+1);
        await expect(bobLastClaimedEpochId).to.be.equal(oneEpochs+fiveEpochs+1);
        await expect(aliceLastStakedEpoch).to.be.equal(oneEpochs+1);
        await expect(aliceLastClaimedEpochId).to.be.equal(oneEpochs+fiveEpochs+1);
        expect(ethers.BigNumber.from(rewards_bob)).to.be.closeTo(ethers.BigNumber.from(totalPoolFee.div(2)), ethers.utils.parseEther("10"));
        expect(ethers.BigNumber.from(rewards_alice)).to.be.closeTo(ethers.BigNumber.from(totalPoolFee.div(2)), ethers.utils.parseEther("10"));
      })

      it("4 Users Stakes(Same Amount) and Harvests together- Should get equal rewards ✅", async function(){
        const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
        const oneEpochs = 1;
        const fiveEpochs = 5;
        const totalPoolFee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
        const perStakerShare = totalPoolFee.div(2)

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
        const rewards_alice = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
        const rewards_charlie = await EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE);
        const rewards_channelCreator = await EPNSCoreV1Proxy.usersRewardsClaimed(CHANNEL_CREATOR);
        
        expect(ethers.BigNumber.from(rewards_bob)).to.be.closeTo(ethers.BigNumber.from(totalPoolFee.div(2)), ethers.utils.parseEther("100"));
        expect(ethers.BigNumber.from(rewards_alice)).to.be.closeTo(ethers.BigNumber.from(totalPoolFee.div(2)), ethers.utils.parseEther("100"));
        expect(ethers.BigNumber.from(rewards_charlie)).to.be.closeTo(ethers.BigNumber.from(totalPoolFee.div(2)), ethers.utils.parseEther("100"));
        expect(ethers.BigNumber.from(rewards_channelCreator)).to.be.closeTo(ethers.BigNumber.from(totalPoolFee.div(2)), ethers.utils.parseEther("100"));

      })

      it("4 Users Stakes(Same Amount) and Harvests together- Last Claimer Gets More ✅", async function(){
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
        const rewards_alice = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
        const rewards_charlie = await EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE);
        const rewards_channelCreator = await EPNSCoreV1Proxy.usersRewardsClaimed(CHANNEL_CREATOR);

        await expect(rewards_alice).to.be.gt(rewards_bob);
        await expect(rewards_charlie).to.be.gt(rewards_alice);
        await expect(rewards_channelCreator).to.be.gt(rewards_charlie);
      })

      it("4 Users Stakes different amount and Harvests together- Last Claimer & Major Staker Gets More ✅", async function(){
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
        const rewards_alice = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
        const rewards_charlie = await EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE);
        const rewards_channelCreator = await EPNSCoreV1Proxy.usersRewardsClaimed(CHANNEL_CREATOR);

        await expect(rewards_alice).to.be.gt(rewards_bob);
        await expect(rewards_charlie).to.be.gt(rewards_alice);
        await expect(rewards_channelCreator).to.be.gt(rewards_charlie);
      })
      // Expected Result = BOB_REWARDS > Alice > Charlie > Channel_CREATOR
      it("TEST CHECKS-5.1: 4 Users Stakes different amount and Harvests together- Last Claimer & Major Staker Gets More(First Staker stakes the MOST) ✅", async function(){
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
        const rewards_alice = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
        const rewards_charlie = await EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE);
        const rewards_channelCreator = await EPNSCoreV1Proxy.usersRewardsClaimed(CHANNEL_CREATOR);

        await expect(rewards_charlie).to.be.gt(rewards_channelCreator);
        await expect(rewards_alice).to.be.gt(rewards_charlie);
        await expect(rewards_bob).to.be.gt(rewards_alice);
      })

      it(" 4 Users Stakes(Same Amount) & Harvests after a gap of 2 epochs each - Last Claimer should get More Rewards ✅", async function(){
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
        const rewards_alice = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
        const rewards_charlie = await EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE);
        const rewards_channelCreator = await EPNSCoreV1Proxy.usersRewardsClaimed(CHANNEL_CREATOR);

        await expect(rewards_alice).to.be.gt(rewards_bob);
        await expect(rewards_charlie).to.be.gt(rewards_alice);
        await expect(rewards_channelCreator).to.be.gt(rewards_charlie);
      })

      it("BOB Stakes and Harvests alone in same Epoch- Should get ZERO rewards ✅", async function(){
        const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
        const oneEpochs= 1;
        const totalPoolFee = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
        
        await passBlockNumers(oneEpochs * EPOCH_DURATION);
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).addPoolFees(tokensBN(200));
        
        await stakePushTokens(BOBSIGNER, tokensBN(100))
        // Fast Forward 1/2 epoch, lands in same EPOCH more epochs 
        await passBlockNumers(EPOCH_DURATION/2);
        await EPNSCoreV1Proxy.connect(BOBSIGNER).harvestAll();

        const bobLastStakedEpoch = await getLastStakedEpoch(BOB);
        const bobLastClaimedEpochId = await getLastRewardClaimedEpoch(BOB);
        const rewards_bob = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB);

        await expect(rewards_bob).to.be.equal(0);
        await expect(bobLastStakedEpoch).to.be.equal(oneEpochs+1);
        await expect(bobLastClaimedEpochId).to.be.equal(oneEpochs+1);
      })

    });

    describe("🟢 Harvesting Rewards Tests ", function()
    {

    });
    
    describe("🟢 daoHarvest Rewards Tests ", function()
    {

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
    describe("🟢 LEVEL-2: Tests on Stake N Rewards", function()
     {
      it("TEST CHECKS-7: 4 Users Stakes(Same Amount) after a GAP of 2 epochs each & Harvests together - Last Claimer should get More Rewards ✅", async function(){
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
        const rewards_alice = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);

        const charlie_ClaimedBlock = await getLastStakedEpoch(CHARLIE);
        const rewards_charlie = await EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE);
        
        const channeCreator_ClaimedBlock = await getLastStakedEpoch(CHANNEL_CREATOR);
        const rewards_channelCreator = await EPNSCoreV1Proxy.usersRewardsClaimed(CHANNEL_CREATOR);

        await expect(rewards_bob).to.be.gt(rewards_alice);
        await expect(rewards_alice).to.be.gt(rewards_charlie);
        await expect(rewards_charlie).to.be.gt(rewards_channelCreator);

        console.log(`BOB Staked at EPOCH-${bob_ClaimedBlock.toNumber()} and got ${rewards_bob.toString()} Rewards`)
        console.log(`ALICE Staked at EPOCH-${alice_ClaimedBlock.toNumber()} and got ${rewards_alice.toString()} Rewards`)
        console.log(`CHARLIE Staked at EPOCH-${charlie_ClaimedBlock.toNumber()} and got ${rewards_charlie.toString()} Rewards`)
        console.log(`CHANNEL_CREATOR Staked at EPOCH-${channeCreator_ClaimedBlock.toNumber()} and got ${rewards_channelCreator.toString()} Rewards`)
      })

      it("TEST CHECKS-8: Stakers Stakes again in same EPOCH - Claimable Reward Calculation should be accurate ✅", async function(){
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
        const rewards_alice = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);

        const charlie_ClaimedBlock = await getLastStakedEpoch(CHARLIE);
        const rewards_charlie = await EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE);
        
        const channeCreator_ClaimedBlock = await getLastStakedEpoch(CHANNEL_CREATOR);
        const rewards_channelCreator = await EPNSCoreV1Proxy.usersRewardsClaimed(CHANNEL_CREATOR);

        await expect(rewards_bob).to.be.gt(rewards_alice);
        await expect(rewards_alice).to.be.gt(rewards_charlie);
        await expect(rewards_charlie).to.be.gt(rewards_channelCreator);

        console.log(`BOB Staked at EPOCH-${bob_ClaimedBlock.toNumber()} and got ${rewards_bob.toString()} Rewards`)
        console.log(`ALICE Staked at EPOCH-${alice_ClaimedBlock.toNumber()} and got ${rewards_alice.toString()} Rewards`)
        console.log(`CHARLIE Staked at EPOCH-${charlie_ClaimedBlock.toNumber()} and got ${rewards_charlie.toString()} Rewards`)
        console.log(`CHANNEL_CREATOR Staked at EPOCH-${channeCreator_ClaimedBlock.toNumber()} and got ${rewards_channelCreator.toString()} Rewards`)

      })

      it("TEST CHECKS-8.1: Stakers Stakes again in Same EPOCH with other pre-existing stakers - Claimable Reward Calculation should be accurate for all", async function(){
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
        const rewards_alice = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);

        const charlie_ClaimedBlock = await getLastStakedEpoch(CHARLIE);
        const rewards_charlie = await EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE);
        
        const channeCreator_ClaimedBlock = await getLastStakedEpoch(CHANNEL_CREATOR);
        const rewards_channelCreator = await EPNSCoreV1Proxy.usersRewardsClaimed(CHANNEL_CREATOR);

        await expect(rewards_bob).to.be.gt(rewards_alice);
        await expect(rewards_alice).to.be.gt(rewards_charlie);
        await expect(rewards_charlie).to.be.gt(rewards_channelCreator);

        console.log(`BOB Staked at EPOCH-${bob_ClaimedBlock.toNumber()} and got ${rewards_bob.toString()} Rewards`)
        console.log(`ALICE Staked at EPOCH-${alice_ClaimedBlock.toNumber()} and got ${rewards_alice.toString()} Rewards`)
        console.log(`CHARLIE Staked at EPOCH-${charlie_ClaimedBlock.toNumber()} and got ${rewards_charlie.toString()} Rewards`)
        console.log(`CHANNEL_CREATOR Staked at EPOCH-${channeCreator_ClaimedBlock.toNumber()} and got ${rewards_channelCreator.toString()} Rewards`)
      })

      it("TEST CHECKS-9: Stakers Stakes again in Different EPOCH - Claimable Reward Calculation should be accurate", async function(){
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

        console.log(`BOB Staked at EPOCH-${bob_ClaimedBlock.toNumber()} and got ${rewards_bob.toString()} Rewards`)
      })

      it("TEST CHECKS-9.1: Stakers Stakes again in Different EPOCH with pre-existing stakers - Claimable Reward Calculation should be accurate for all ✅", async function(){
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
        const rewards_alice = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);

        const charlie_ClaimedBlock = await getLastStakedEpoch(CHARLIE);
        const rewards_charlie = await EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE);
        
        const channeCreator_ClaimedBlock = await getLastStakedEpoch(CHANNEL_CREATOR);
        const rewards_channelCreator = await EPNSCoreV1Proxy.usersRewardsClaimed(CHANNEL_CREATOR);

        // await expect(rewards_bob).to.be.gt(rewards_alice);
        // await expect(rewards_alice).to.be.gt(rewards_charlie);
        // await expect(rewards_charlie).to.be.gt(rewards_channelCreator);

        console.log(`BOB Staked at EPOCH-${bob_ClaimedBlock.toNumber()} and got ${rewards_bob.toString()} Rewards`)
        console.log(`ALICE Staked at EPOCH-${alice_ClaimedBlock.toNumber()} and got ${rewards_alice.toString()} Rewards`)
        console.log(`CHARLIE Staked at EPOCH-${charlie_ClaimedBlock.toNumber()} and got ${rewards_charlie.toString()} Rewards`)
        console.log(`CHANNEL_CREATOR Staked at EPOCH-${channeCreator_ClaimedBlock.toNumber()} and got ${rewards_channelCreator.toString()} Rewards`)
      })

      it("TEST CHECKS-10: Staking and Unstaking at Same Epoch should not lead to increase in rewards-(for previously staked users)✅", async function(){
        // const genesisEpoch = await EPNSCoreV1Proxy.genesisEpoch();
        const stakeAmount = tokensBN(100);
        const bobDetails = await EPNSCoreV1Proxy.userFeesInfo(BOB);
        const userWeight = await bobDetails.stakedWeight;
        expect(userWeight).to.be.equal(0);
        const fourEpochs=4;
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

// PENDING Items
/**
 * Contract Related
 * Include a genesisTotalWeight state variable. If any epoch has no totalWeight, they will use the genesisTotalWeight that comes from the PUSH Admin stake of 1 push
 * Add events where necessary 
 * 
 * TEST Cases Related
 * Ensure that Subscribe and Unsubscribe doesn't break the adjustment functions
 * Ensure that Total Epoch Rewards of 1 epoch gets equally distributed among all users - Manually ✅
 * Ensure that Total Epoch Rewards of 1 epoch gets equally distributed among all users - Using Script
 * Write a script to check CLAIMABLE rewards for staker, given their weight, amount and current block.
 * Arrange test cases in their respective slots
 * 
 */


// Details - TEST CHECK-9
/**
 * ISSUE: Calculation of userLastClaimedBlock in harvestTill() function was flawed - lead to errors in reward calculation coz of epoch differences, Made the fix.
 * lastClaimedEpoch can actually be acheieved via - lastEpochRelative(genesisEpoch, userFeesInfo[msg.sender].lastClaimedBlock); 
 */