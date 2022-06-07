const { ethers,waffle } = require("hardhat");

const {
  tokensBN,
} = require("../../helpers/utils");


const {epnsContractFixture,tokenFixture} = require("../common/fixtures")
const {expect} = require("../common/expect")
const createFixtureLoader = waffle.createFixtureLoader;


describe("EPNS CoreV2 Protocol", function () {
  const ADD_CHANNEL_MIN_POOL_CONTRIBUTION = tokensBN(50)
  const ADD_CHANNEL_MAX_POOL_CONTRIBUTION = tokensBN(250000 * 50)
  const ADJUST_FOR_FLOAT = 10 ** 7

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
    } = await loadFixture(epnsContractFixture)); 

    ({MOCKDAI, ADAI} = await loadFixture(tokenFixture));
	});

	describe('EPNS CORE: CLAIM REWARD TEST', () => {
		const CHANNEL_TYPE = 2;
		const TEST_CHANNEL_CTX = ethers.utils.toUtf8Bytes("test-channel-hello-world");

		beforeEach(async function(){
			await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
			await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
			
			await PushToken.transfer(BOB, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10));
			await PushToken.transfer(ALICE, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10));
			await PushToken.transfer(CHANNEL_CREATOR, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10));
			
			await PushToken.connect(BOBSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10));
			await PushToken.connect(ALICESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10));
			await PushToken.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10));
			
			await PushToken.connect(ALICESIGNER).setHolderDelegation(EPNSCoreV1Proxy.address,true);
		});

		const createChannel = async(signer)=>{
			await EPNSCoreV1Proxy.connect(signer)
				.createChannelWithPUSH(CHANNEL_TYPE, TEST_CHANNEL_CTX, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
		}


		it("Allows token holders to claim the rewards", async function(){
			await createChannel(ALICESIGNER);
			await createChannel(BOBSIGNER);
			

			const initialClaimedRewards = await EPNSCoreV1Proxy.usersRewardsClaimed(CHANNEL_CREATOR);
			expect(initialClaimedRewards).to.equal(0);

			// wait one year
			await ethers.provider.send("hardhat_mine", ["0x100"]);
			await PushToken.connect(CHANNEL_CREATORSIGNER).setHolderDelegation(EPNSCoreV1Proxy.address,true);
			

			// claim reward
			const txn = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).claimRewards();
			await expect(txn).to.emit(EPNSCoreV1Proxy,"RewardsClaimed");

			// user claim reward increases
			const finalClaimedRewards = await EPNSCoreV1Proxy.usersRewardsClaimed(CHANNEL_CREATOR)
			expect(finalClaimedRewards).to.be.above(0);		
		})

		it("Gives reward based on the holderWeight", async() => {
			// Creating channel adds funds to the pool
			await createChannel(CHANNEL_CREATORSIGNER);
			await createChannel(BOBSIGNER);
			
			// pass few blocks
			await ethers.provider.send("hardhat_mine", ["0x10"]);			

			// alice was initally funded 50*10 PUSH
			// record alice userHolderWeight for next block
			var currentBlock = await ethers.provider.getBlock("latest");
			const userHolderWeight = await PushToken.returnHolderUnits(ALICE,currentBlock.number+1)
			const userInitalBalance = await PushToken.balanceOf(ALICE);

			// alice claims the reward
			await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards()
			const userClaimedRewards = await EPNSCoreV1Proxy.connect(ALICESIGNER).usersRewardsClaimed(ALICE);

			/**
			 * Validates if result holds this formulation
			 * userRatio = userHolderWeight / (pushTotalSupply * numberOfBlocksSincePushTokenLaunch)
			 * userReward = userRatio * poolFunds
			*/     	
			var currentBlock = await ethers.provider.getBlock("latest");
			const pushOriginBlockNumber = await PushToken.born();
			const pushTotalSupply = await PushToken.totalSupply();
			const poolFunds = await EPNSCoreV1Proxy.POOL_FUNDS();			
			const blockGap = currentBlock.number - pushOriginBlockNumber;
			const totalHolderWeight = blockGap * pushTotalSupply;
			const userRatio = Math.floor(userHolderWeight * ADJUST_FOR_FLOAT/totalHolderWeight);
			const userReward = userRatio * poolFunds/ADJUST_FOR_FLOAT
			// userClaimed value shoulld match the formulation value	
			expect(userReward).to.equal(userClaimedRewards);
			
			// user PUSH balance should be increased by `userReward`
			const expectedFinalBalance = userInitalBalance.add(userReward);
			const userFinalBalance = await PushToken.balanceOf(ALICE);
			expect(expectedFinalBalance).to.equal(userFinalBalance);		
		});

		it("Maintains resetHolderWeight to avoid double reward", async function(){
			await createChannel(ALICESIGNER);
			await createChannel(BOBSIGNER);
			await PushToken.connect(CHANNEL_CREATORSIGNER).setHolderDelegation(EPNSCoreV1Proxy.address,true);
			
			// allows claim reward
			await ethers.provider.send("hardhat_mine", ["0x100"]);
			await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).claimRewards()

			// user holder weight should be set to zero 
			var currentBlock = await ethers.provider.getBlock("latest");
			const userHolderWeight = await PushToken.returnHolderUnits(CHANNEL_CREATOR,currentBlock.number);
			expect(userHolderWeight).to.equal(0);	
			
			// fails on immediately claiming the reward on next block
			await expect(
				EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).claimRewards()
			).to.be.revertedWith("EPNSCoreV2::claimRewards: No Claimable Rewards at the Moment")
			
			// allows claming after some block passes
			await ethers.provider.send("hardhat_mine", ["0x100"]);
			const txn = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).claimRewards()
			await expect(txn).to.emit(EPNSCoreV1Proxy,"RewardsClaimed");
		})

		it("Reverts when pool balance is empty", async function(){
			await PushToken.connect(CHANNEL_CREATORSIGNER).setHolderDelegation(EPNSCoreV1Proxy.address,true);
			
			// revert as pool fund is empty
			await expect(
				EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).claimRewards()
			).to.be.revertedWith("EPNSCoreV2::claimRewards: No Claimable Rewards at the Moment")

			// add pool balance by creating the channel
			await createChannel(ALICESIGNER);
			await createChannel(BOBSIGNER);

			// now user should be able the claim the rewards
			const txn = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).claimRewards()
			await expect(txn).to.emit(EPNSCoreV1Proxy,"RewardsClaimed");			
		})

		it("Reverts when user don't have any push balance", async function(){
			// add pool balance by creating the channel
			await createChannel(ALICESIGNER);
			await createChannel(BOBSIGNER);

			// CHARLIESIGNER don't have any PUSH
			// so, it should revert on claim reward
			await PushToken.connect(CHARLIESIGNER).setHolderDelegation(EPNSCoreV1Proxy.address,true);
			await expect(
				EPNSCoreV1Proxy.connect(CHARLIESIGNER).claimRewards()
			).to.be.revertedWith("EPNSCoreV2::claimRewards: No Claimable Rewards at the Moment")
				
			// alice sends PUSH token to charlie
			await PushToken.connect(ALICESIGNER).setHolderDelegation(EPNSCoreV1Proxy.address,true);
			await PushToken.connect(ALICESIGNER).transfer(
				CHARLIE,
				ADD_CHANNEL_MIN_POOL_CONTRIBUTION
			)
			await ethers.provider.send("hardhat_mine", ["0x100"]); 			

			// now charlie should be able the claim the rewards
			const txn = EPNSCoreV1Proxy.connect(CHARLIESIGNER).claimRewards()
			await expect(txn).to.emit(EPNSCoreV1Proxy,"RewardsClaimed");			
		})
	});
});
