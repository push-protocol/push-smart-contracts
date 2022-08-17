const { ethers,waffle } = require("hardhat");

const {
  tokensBN, returnWeight,
} = require("../../helpers/utils");


const {epnsContractFixture,tokenFixture} = require("../common/fixtures")
const {expect} = require("../common/expect");
const { utils } = require("ethers");
const createFixtureLoader = waffle.createFixtureLoader;


describe("EPNS CoreV2 Protocol", function () {
  const ADD_CHANNEL_MIN_POOL_CONTRIBUTION = tokensBN(50)
  const ADD_CHANNEL_MAX_POOL_CONTRIBUTION = tokensBN(250000 * 50)
  const TOTAL_SUPPLY = tokensBN(10e6)
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

	const maintainSameBal = async(signer,bal)=>{
		const userBal = await PushToken.balanceOf(signer.address);
		const amtToSend = userBal.sub(bal);
		await PushToken.connect(signer).transfer(ADMIN,amtToSend);
	}

	// TODO: need to update the cliam rewards
	describe('EPNS CORE: CLAIM REWARD TEST', () => {
		const CHANNEL_TYPE = 2;
		const TEST_CHANNEL_CTX = ethers.utils.toUtf8Bytes("test-channel-hello-world");

		beforeEach(async function(){
			await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
			await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);

			await PushToken.approve(EPNSCoreV1Proxy.address,TOTAL_SUPPLY);
			await PushToken.connect(BOBSIGNER).approve(EPNSCoreV1Proxy.address, TOTAL_SUPPLY);
			await PushToken.connect(ALICESIGNER).approve(EPNSCoreV1Proxy.address, TOTAL_SUPPLY);
			await PushToken.connect(CHARLIESIGNER).approve(EPNSCoreV1Proxy.address, TOTAL_SUPPLY);

			await PushToken.connect(ALICESIGNER).setHolderDelegation(EPNSCoreV1Proxy.address,true);
			await PushToken.connect(BOBSIGNER).setHolderDelegation(EPNSCoreV1Proxy.address,true);
			await PushToken.connect(CHARLIESIGNER).setHolderDelegation(EPNSCoreV1Proxy.address,true);
		});

		const createChannelWithCustomFee = async(fee)=>{
			await EPNSCoreV1Proxy.createChannelWithPUSH(CHANNEL_TYPE, TEST_CHANNEL_CTX, fee,0);
		}

		const updateChannel = async(fee)=>{
			await EPNSCoreV1Proxy.updateChannelMeta(
				ADMIN,
				"0x00",
				fee
			);
		}

		const addFundsToPoolFees = async(fees)=>{
			await createChannelWithCustomFee(tokensBN(50));
			fees = fees.sub(tokensBN(10))
			await updateChannel(fees)
		}

    const addMoreRewards = async(fees) =>{
      await updateChannel(fees);
    }

		const gotoBlockNumber = async(blockNumber) =>{
			blockNumber = blockNumber.toNumber();
			const currentBlock = await ethers.provider.getBlock("latest");
			const numBlockToIncrease = blockNumber - currentBlock.number;
			const blockIncreaseHex = `0x${numBlockToIncrease.toString(16)}`;
			await ethers.provider.send("hardhat_mine", [blockIncreaseHex]);
		}

		it("Allows multiple users to claim at same block; users claiming at last gets more", async function(){
			const PUSH_BORN = await PushToken.born();
			const BLOCK_GAP = 2000;
			const WITHDRWAL_BLOCK_NUM = PUSH_BORN.add(BLOCK_GAP);

			// Add 5000 PUSH to PROTOCOL_POOL_FEES by creating the channel
			await addFundsToPoolFees(tokensBN(5_000))
			const poolFees = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
			expect(poolFees).to.equal(tokensBN(5_000))


			// Alice gets: 5M PUSH
			// Bob gets: 5M PUSH
			// Charlie gets: 5M PUSH
			await PushToken.transfer(ALICE, tokensBN(5_000_000));
			await PushToken.transfer(BOB, tokensBN(5_000_000));
			await PushToken.transfer(CHARLIE, tokensBN(5_000_000));

			const [aliceWt, bobWt, charlieWt] = await Promise.all([
				PushToken.returnHolderUnits(ALICE, WITHDRWAL_BLOCK_NUM),
				PushToken.returnHolderUnits(BOB, WITHDRWAL_BLOCK_NUM),
				PushToken.returnHolderUnits(CHARLIE, WITHDRWAL_BLOCK_NUM),
			]);

			// assert userholder wt
			// expect(aliceWt).to.equal(tokensBN(10_000_000_000))
			// expect(bobWt).to.equal(tokensBN(10_000_000_000))
			// expect(charlieWt).to.equal(tokensBN(10_000_000_000))

			// move to one block before `WITHDRWAL_BLOCK_NUM`
			await gotoBlockNumber(WITHDRWAL_BLOCK_NUM.sub(1))

			// add multiple transaction in single block
			await ethers.provider.send("evm_setAutomine", [false]);
			await Promise.all([
				EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards(),
				EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards(),
				EPNSCoreV1Proxy.connect(CHARLIESIGNER).claimRewards(),
			]);
			await network.provider.send("evm_mine");
			await ethers.provider.send("evm_setAutomine", [true]);

			// after claim rewards currentBlock should equal `WITHDRWAL_BLOCK_NUM`
			const currentBlock = await ethers.provider.getBlock("latest");
			expect(currentBlock.number).to.equal(WITHDRWAL_BLOCK_NUM);

			// finally assert reward yields
			const [aliceRw, bobRw, charlieRw] = await Promise.all([
				EPNSCoreV1Proxy.usersRewardsClaimed(ALICE),
				EPNSCoreV1Proxy.usersRewardsClaimed(BOB),
				EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE),
			]);

      console.log(`Total PROTOCOL_POOL_FEES for all scenario is ${ethers.utils.formatEther(poolFees)}`);
			console.log("Part 1 - All user Hold 5M PUSH and Claims at Same Block");
			console.log("Alice's Reward",ethers.utils.formatEther(aliceRw));
			console.log("Bob's Reward",ethers.utils.formatEther(bobRw));
			console.log("Charlie's Reward",ethers.utils.formatEther(charlieRw));
      console.log("-------------------------------------------------------");
      console.log('\n');

			// transaction at last shall be rewarded more
			// expect(bobRw).to.be.above(aliceRw)
			// expect(charlieRw).to.be.above(bobRw)

			// should get expected rewards
			// expect(aliceRw).to.equal(ethers.utils.parseEther("0.5"),ethers.utils.parseEther("0.000001"))
			// expect(bobRw).to.be.closeTo(ethers.utils.parseEther("0.5263157898"),ethers.utils.parseEther("0.000001"))
			// expect(charlieRw).to.be.closeTo(ethers.utils.parseEther("0.5555555556"),ethers.utils.parseEther("0.000001"))
		})

		it("Allows Multiple users claming at same time; user with larger push holding should be rewarded more", async function(){
			const PUSH_BORN = await PushToken.born();
			const BLOCK_GAP = 2000;
			const WITHDRWAL_BLOCK_NUM = PUSH_BORN.add(BLOCK_GAP);

			// Add 5000 PUSH to PROTOCOL_POOL_FEES by creating the channel
			await addFundsToPoolFees(tokensBN(5_000))
			const poolFees = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
			expect(poolFees).to.equal(tokensBN(5_000))

			// Alice gets: 5M PUSH
			// Bob gets: 500K PUSH
			// Charlie gets: 50K PUSH
			await PushToken.transfer(ALICE, tokensBN(5_000_000));
			await PushToken.transfer(BOB, tokensBN(500_000));
			await PushToken.transfer(CHARLIE, tokensBN(50_000));

			const [aliceWt, bobWt, charlieWt] = await Promise.all([
				PushToken.returnHolderUnits(ALICE, WITHDRWAL_BLOCK_NUM),
				PushToken.returnHolderUnits(BOB, WITHDRWAL_BLOCK_NUM),
				PushToken.returnHolderUnits(CHARLIE, WITHDRWAL_BLOCK_NUM),
			]);

			// assert userholder wt
			expect(aliceWt).to.equal(tokensBN(10_000_000_000))
			expect(bobWt).to.equal(tokensBN(1_000_000_000))
			expect(charlieWt).to.equal(tokensBN(100_000_000))

			// move to one block before `WITHDRWAL_BLOCK_NUM`
			await gotoBlockNumber(WITHDRWAL_BLOCK_NUM.sub(1))

			// add multiple transaction in single block
			await ethers.provider.send("evm_setAutomine", [false]);
			await Promise.all([
				EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards(),
				EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards(),
				EPNSCoreV1Proxy.connect(CHARLIESIGNER).claimRewards(),
			]);
			await network.provider.send("evm_mine");
			await ethers.provider.send("evm_setAutomine", [true]);

			// after claim rewards currentBlock should equal `WITHDRWAL_BLOCK_NUM`
			const currentBlock = await ethers.provider.getBlock("latest");
			expect(currentBlock.number).to.equal(WITHDRWAL_BLOCK_NUM);

			// finally assert reward yields
			var [aliceRw, bobRw, charlieRw] = await Promise.all([
				EPNSCoreV1Proxy.usersRewardsClaimed(ALICE),
				EPNSCoreV1Proxy.usersRewardsClaimed(BOB),
				EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE),
			]);

			console.log("Part 2.a -> Alice holds 5M, Bob Holds 500K and Charlie Holds 50K");
      console.log("Alice's Reward",ethers.utils.formatEther(aliceRw));
			console.log("Bob's Reward",ethers.utils.formatEther(bobRw));
			console.log("Charlie's Reward",ethers.utils.formatEther(charlieRw));
      console.log("-------------------------------------------------------");

			// larzer token holder larger reward
			// expect(bobRw).to.be.below(aliceRw)
			// expect(charlieRw).to.be.below(bobRw)

			// should get expected rewards
			// expect(aliceRw).to.equal(ethers.utils.parseEther("0.5"),ethers.utils.parseEther("0.000001"))
			// expect(bobRw).to.be.closeTo(ethers.utils.parseEther("0.05263157898"),ethers.utils.parseEther("0.000001"))
			// expect(charlieRw).to.be.closeTo(ethers.utils.parseEther("0.005291005291"),ethers.utils.parseEther("0.000001"))

			/* go to block 4000 */
			await gotoBlockNumber(WITHDRWAL_BLOCK_NUM.mul(2).sub(1))
			// add multiple transaction in single block
			await ethers.provider.send("evm_setAutomine", [false]);
			await Promise.all([
				EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards(),
				EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards(),
				EPNSCoreV1Proxy.connect(CHARLIESIGNER).claimRewards(),
			]);
			await network.provider.send("evm_mine");
			await ethers.provider.send("evm_setAutomine", [true]);

			// finally assert reward yields
			var [aliceRw, bobRw, charlieRw] = await Promise.all([
				EPNSCoreV1Proxy.usersRewardsClaimed(ALICE),
				EPNSCoreV1Proxy.usersRewardsClaimed(BOB),
				EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE),
			]);

			console.log("Part 2.a -> Alice holds 5M, Bob Holds 500K and Charlie Holds 50K & CLAIMS AGAIN");
      console.log("Alice's Reward",ethers.utils.formatEther(aliceRw));
			console.log("Bob's Reward",ethers.utils.formatEther(bobRw));
			console.log("Charlie's Reward",ethers.utils.formatEther(charlieRw));
      console.log("-------------------------------------------------------");
      console.log('\n');
		})

		it("Tests for multiple users claming reward at diffrent block times gets correct reward", async function(){
			const PUSH_BORN = await PushToken.born();

			// Add 5000 PUSH to PROTOCOL_POOL_FEES by creating the channel
			await addFundsToPoolFees(tokensBN(5_000))
			const poolFees = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
			expect(poolFees).to.equal(tokensBN(5_000))

			// Alice gets: 40M PUSH
			// Bob gets: 20M PUSH
			// Charlie gets: 10M PUSH
			await PushToken.transfer(ALICE, tokensBN(40_000_000));
			await PushToken.transfer(BOB, tokensBN(20_000_000));
			await PushToken.transfer(CHARLIE, tokensBN(10_000_000));

			const [ALICE_BLOCK, BOB_BLOCK, CHARLIE_BLOCK] = [
				PUSH_BORN.add(2_000),
				PUSH_BORN.add(3_000),
				PUSH_BORN.add(4_000)
			]
			const [aliceWt, bobWt, charlieWt] = await Promise.all([
				PushToken.returnHolderUnits(ALICE, ALICE_BLOCK),
				PushToken.returnHolderUnits(BOB, BOB_BLOCK),
				PushToken.returnHolderUnits(CHARLIE, CHARLIE_BLOCK),
			]);

			// assert userholder wt
			// expect(aliceWt).to.equal(tokensBN(80_000_000_000))
			// expect(bobWt).to.equal(tokensBN(60_000_000_000))
			// expect(charlieWt).to.equal(tokensBN(40_000_000_000))

			// move to one block before `WITHDRWAL_BLOCK_NUM` and claim rewards
			await gotoBlockNumber(ALICE_BLOCK.sub(1));
			await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();

			await gotoBlockNumber(BOB_BLOCK.sub(1));
			await EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards();

			await gotoBlockNumber(CHARLIE_BLOCK.sub(1));
			await EPNSCoreV1Proxy.connect(CHARLIESIGNER).claimRewards();

			// finally assert reward yields
			const [aliceRw, bobRw, charlieRw] = await Promise.all([
				EPNSCoreV1Proxy.usersRewardsClaimed(ALICE),
				EPNSCoreV1Proxy.usersRewardsClaimed(BOB),
				EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE),
			]);

			console.log("Part 3 -> Alice(40M), BOB(20M), CHARLIE(10M) claims at different block times");
      console.log("Alice's Reward",ethers.utils.formatEther(aliceRw));
			console.log("Bob's Reward",ethers.utils.formatEther(bobRw));
			console.log("Charlie's Reward",ethers.utils.formatEther(charlieRw));
      console.log("-------------------------------------------------------");
      console.log('\n');
			// expect(aliceRw).to.equal(ethers.utils.parseEther("4"))
			// expect(bobRw).to.be.closeTo(ethers.utils.parseEther("2.727272727272727"),ethers.utils.parseEther("0.000001"))
			// expect(charlieRw).to.be.closeTo(ethers.utils.parseEther("1.5384615384615385"),ethers.utils.parseEther("0.000001"))
		})

		it(" ❌ Allows multiple users with same amt claiming different at times; user holding longer should get more reward", async function(){
			const PUSH_BORN = await PushToken.born();

			// Add 5000 PUSH to PROTOCOL_POOL_FEES by creating the channel
			await addFundsToPoolFees(tokensBN(5_000))
			const poolFees = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
			expect(poolFees).to.equal(tokensBN(5_000))


			// Alice gets: 200k PUSH
			// Bob gets: 200k PUSH
			// Charlie gets: 200k PUSH
			await PushToken.transfer(ALICE, tokensBN(200_000));
			await PushToken.transfer(BOB, tokensBN(200_000));
			await PushToken.transfer(CHARLIE, tokensBN(200_000));

			var [ALICE_BLOCK, BOB_BLOCK, CHARLIE_BLOCK] = [
				PUSH_BORN.add(2_000),
				PUSH_BORN.add(3_000),
				PUSH_BORN.add(4_000)
			]
			var [aliceWt, bobWt, charlieWt] = await Promise.all([
				PushToken.returnHolderUnits(ALICE, ALICE_BLOCK),
				PushToken.returnHolderUnits(BOB, BOB_BLOCK),
				PushToken.returnHolderUnits(CHARLIE, CHARLIE_BLOCK),
			]);

			// assert userholder wt
			// expect(aliceWt).to.equal(tokensBN(40_000_000_000))
			// expect(bobWt).to.equal(tokensBN(60_000_000_000))
			// expect(charlieWt).to.equal(tokensBN(80_000_000_000))
      console.log('Total Pool before First Claim Iteration ->', ethers.utils.formatEther(poolFees));

			// move to one block before `WITHDRWAL_BLOCK_NUM` and claim rewards
			await gotoBlockNumber(ALICE_BLOCK.sub(1));
			await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();
      await addMoreRewards(tokensBN(100))

			await gotoBlockNumber(BOB_BLOCK.sub(1));
			await EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards();
      await addMoreRewards(tokensBN(150))

			await gotoBlockNumber(CHARLIE_BLOCK.sub(1));
			await EPNSCoreV1Proxy.connect(CHARLIESIGNER).claimRewards();
      await addMoreRewards(tokensBN(200))


			// finally assert reward yields
			var [aliceRw, bobRw, charlieRw] = await Promise.all([
				EPNSCoreV1Proxy.usersRewardsClaimed(ALICE),
				EPNSCoreV1Proxy.usersRewardsClaimed(BOB),
				EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE),
			]);

			console.log("Part 4.a -> Alice, Bob and Charlie hold 200K but claim 2K, 3K & 4K block gap respectively");
      console.log("Alice's Reward",ethers.utils.formatEther(aliceRw));
			console.log("Bob's Reward",ethers.utils.formatEther(bobRw));
			console.log("Charlie's Reward",ethers.utils.formatEther(charlieRw));
      console.log("-------------------------------------------------------");

			// expect(bobRw).to.be.above(aliceRw)
			// expect(charlieRw).to.be.above(bobRw)


			/** Second Iteration */
			var [ALICE_BLOCK, BOB_BLOCK, CHARLIE_BLOCK] = [
				PUSH_BORN.add(5000),
				PUSH_BORN.add(6000),
				PUSH_BORN.add(7000)
			]

      const pool_fees2nd = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
      console.log('\nPool_Fees before Second Claim Iteration', ethers.utils.formatEther(pool_fees2nd));
			// move to one block before `WITHDRWAL_BLOCK_NUM` and claim rewards
			await gotoBlockNumber(ALICE_BLOCK.sub(1));
			await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();
      await addMoreRewards(tokensBN(250))

			await gotoBlockNumber(BOB_BLOCK.sub(1));
			await EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards();
      await addMoreRewards(tokensBN(300))

			await gotoBlockNumber(CHARLIE_BLOCK.sub(1));
			await EPNSCoreV1Proxy.connect(CHARLIESIGNER).claimRewards();
      await addMoreRewards(tokensBN(350))

			// finally assert reward yields
			var [aliceRw, bobRw, charlieRw] = await Promise.all([
				EPNSCoreV1Proxy.usersRewardsClaimed(ALICE),
				EPNSCoreV1Proxy.usersRewardsClaimed(BOB),
				EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE),
			]);

      console.log("\nPart 4.b -> Alice, Bob and Charlie claims again at 5K, 6K & 7K block gap respectively");
      console.log("Alice's Reward",ethers.utils.formatEther(aliceRw));
			console.log("Bob's Reward",ethers.utils.formatEther(bobRw));
			console.log("Charlie's Reward",ethers.utils.formatEther(charlieRw));
      console.log("-------------------------------------------------------");

      var [ALICE_BLOCK, BOB_BLOCK, CHARLIE_BLOCK] = [
				PUSH_BORN.add(8000),
				PUSH_BORN.add(9000),
				PUSH_BORN.add(10000)
			]


      const pool_fees4th = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
      console.log('Pool_Fees before Second Claim Iteration', ethers.utils.formatEther(pool_fees4th));
			// move to one block before `WITHDRWAL_BLOCK_NUM` and claim rewards
			await gotoBlockNumber(ALICE_BLOCK.sub(1));
			await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();

			await gotoBlockNumber(BOB_BLOCK.sub(1));
			await EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards();

			await gotoBlockNumber(CHARLIE_BLOCK.sub(1));
			await EPNSCoreV1Proxy.connect(CHARLIESIGNER).claimRewards();

			// finally assert reward yields
			var [aliceRw, bobRw, charlieRw] = await Promise.all([
				EPNSCoreV1Proxy.usersRewardsClaimed(ALICE),
				EPNSCoreV1Proxy.usersRewardsClaimed(BOB),
				EPNSCoreV1Proxy.usersRewardsClaimed(CHARLIE),
			]);

      console.log("\nPart 4.c -> Alice, Bob and Charlie claims again at 8K, 9K & 10K block gap respectively");
      console.log("Alice's Reward",ethers.utils.formatEther(aliceRw));
			console.log("Bob's Reward",ethers.utils.formatEther(bobRw));
			console.log("Charlie's Reward",ethers.utils.formatEther(charlieRw));
      console.log("-------------------------------------------------------");
      console.log('\n');

			// expect(bobRw).to.be.above(aliceRw)
			// expect(charlieRw).to.be.above(bobRw)

		})

		it("Resets the userHolderWeights on every withdrwal", async function(){
			const PUSH_BORN = await PushToken.born();

			// Add 5000 PUSH to PROTOCOL_POOL_FEES by creating the channel
			await addFundsToPoolFees(tokensBN(5_000))
			const poolFees = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
			expect(poolFees).to.equal(tokensBN(5_000))

			// Alice gets: 40M PUSH
			await PushToken.transfer(ALICE, tokensBN(40_000_000));

			// Alice's holderWeight before
  		    const holderWeightBefore = await PushToken.holderWeight(ALICE);

			// Pass 1000 blocks
			await gotoBlockNumber(PUSH_BORN.add(999));

			// claim reward
			await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();

			const currentBlock = PUSH_BORN.add(1000)
	      	// Alice's holderWeight After
	      	const holderWeightAfter = await PushToken.holderWeight(ALICE);

		    expect(holderWeightAfter.sub(holderWeightBefore)).to.equal(1000);
			expect(holderWeightAfter.sub(currentBlock)).to.equal(0);
		})

		it("Emits error if user don't own any push",async function(){
			const PUSH_BORN = await PushToken.born();

			// Add 10 PUSH to pool by creating the channel
			await createChannelWithCustomFee(tokensBN(4_000))

			// Pass 1000 blocks
			await gotoBlockNumber(PUSH_BORN.add(999));

			// claim rewards get err
			const txn =  EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();
			await expect(txn).to.be.revertedWith("EPNSCoreV2::claimRewards: No Claimable Rewards at the Moment")
			var rewards = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
			expect(rewards).to.equal(0)

			//alice gets some tokens:40M
			await PushToken.transfer(ALICE, tokensBN(40_000_000));

			// alice waits for some time
			await gotoBlockNumber(PUSH_BORN.add(1999));

			// alice can finally claim
			await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();
			var rewards = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
			expect(rewards).to.be.above(0)
		})

		it("Emits error if contract don't have any PROTOCOL_POOL_FEES",async function(){
			const PUSH_BORN = await PushToken.born();

			//alice gets some tokens:40M
			await PushToken.transfer(ALICE, tokensBN(40_000_000));

			// Pass 1000 blocks
			await gotoBlockNumber(PUSH_BORN.add(999));

			// claim rewards get err
			const txn =  EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();
			await expect(txn).to.be.revertedWith("EPNSCoreV2::claimRewards: No Claimable Rewards at the Moment")
			var rewards = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
			expect(rewards).to.equal(0)

			// Add 10 PUSH to pool by creating the channel
			await createChannelWithCustomFee(tokensBN(4_000))

			// alice waits for some time
			await gotoBlockNumber(PUSH_BORN.add(1999));

			// alice can finally claim
			await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards();
			var rewards = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE);
			expect(rewards).to.be.above(0)
		})

		it("❌ 2 users with equal PUSH Tokens claim rewards diffrent fequencies.", async function(){

			// Initally Alice and Bob withdraw after 2000 block
			// Then Alice claims for each 1000 block, five times
			// Bob claims finally after 5001 block
			const PUSH_BORN = await PushToken.born();
			const BLOCK_GAP = 2000;
			const WITHDRWAL_BLOCK_NUM = PUSH_BORN.add(BLOCK_GAP);

			// Add 5000 PUSH to PROTOCOL_POOL_FEES by creating the channel
			await addFundsToPoolFees(tokensBN(5_000))
			const poolFees = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
			expect(poolFees).to.equal(tokensBN(5_000))


			// Alice gets: 5M PUSH
			// Bob gets: 5M PUSH
			const CONST_PUSH_BAL = tokensBN(1_000_000)
			await PushToken.transfer(ALICE, CONST_PUSH_BAL);
			await PushToken.transfer(BOB, CONST_PUSH_BAL);


			// move to one block before `WITHDRWAL_BLOCK_NUM`
			await gotoBlockNumber(WITHDRWAL_BLOCK_NUM.sub(1))

			// add multiple transaction in single block
			await ethers.provider.send("evm_setAutomine", [false]);
			await Promise.all([
				EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards(),
				EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards(),
			]);
			await network.provider.send("evm_mine");
			await ethers.provider.send("evm_setAutomine", [true]);

			// after claim rewards currentBlock should equal `WITHDRWAL_BLOCK_NUM`
			const currentBlock = await ethers.provider.getBlock("latest");
			// expect(currentBlock.number).to.equal(WITHDRWAL_BLOCK_NUM);

			// finally assert reward yields
			const [aliceRw, bobRw] = await Promise.all([
				EPNSCoreV1Proxy.usersRewardsClaimed(ALICE),
				EPNSCoreV1Proxy.usersRewardsClaimed(BOB),
			]);

      console.log("\nPart 6.a -> Alice and Bob holds 1M PUSH Tokens - Both Claims after 2K Blocks");
			console.log("Alice frist reward claimed",ethers.utils.formatEther(aliceRw));
			console.log("Bod frist reward claimed",ethers.utils.formatEther(bobRw));


			// BOB rewards more than alice
			// expect(bobRw).to.be.above(aliceRw);
			await maintainSameBal(ALICESIGNER,CONST_PUSH_BAL);
			await maintainSameBal(BOBSIGNER,CONST_PUSH_BAL);


			// alice tires to claim every 1000 blocks five times
			for (let i = 0; i < 5; i++) {
				await maintainSameBal(ALICESIGNER,CONST_PUSH_BAL);
				await EPNSCoreV1Proxy.connect(BOBSIGNER).claimRewards();
				const currentBlock = await ethers.provider.getBlock("latest").then(b=>b.number);
				await gotoBlockNumber( ethers.BigNumber.from(currentBlock + 1000));
			}

			// bob claims after 5001 block
			await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards()

			const bobFinalRewards = await EPNSCoreV1Proxy.usersRewardsClaimed(BOB)
			const aliceFinalRewards = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE)

      console.log("\nPart 6.b -> For 2nd Claim, BOB claims after every 1K blocks for 5 times, while ALICE claims directly after 5K blocks.");
			console.log("Alice second reward claimed",ethers.utils.formatEther(aliceFinalRewards));
			console.log("Bob second reward claimed",ethers.utils.formatEther(bobFinalRewards));
      console.log("-------------------------------------------------------");

			// alice overall rewards should be more or equal to bob
			// expect(aliceFinalRewards).to.be.at.least(bobFinalRewards)
		})

		// it.skip(" ❌ User can drain the contract by claiming at every block", async function(){
    //         await PushToken.transfer(ALICE, tokensBN(50_000));
    //
    //         // Add 5000 PUSH to PROTOCOL_POOL_FEES by creating the channel
		// 	await addFundsToPoolFees(tokensBN(100_000))
		// 	const poolFees = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
    //
		// 	const userBal = await PushToken.balanceOf(ALICE)
    //         console.log("Users Holds",ethers.utils.formatEther(userBal)," push");
    //         console.log("PROTOCOL_POOL_FEES_WERE",ethers.utils.formatEther(poolFees),"\n");
    //
    //         NUM_ITER = 50;
    //         BLOCK_SKIP = 10;
    //
    //         // const currentBlock = await ethers.provider.getBlock("latest").then(b=>b.number);
    //         // await gotoBlockNumber( ethers.BigNumber.from(currentBlock + 2000 - 1));
    //
    //         let lastReward = 0
    //         let currentReward = 0
    //         for (let i = 0; i < NUM_ITER; i++) {
    //             await EPNSCoreV1Proxy.connect(ALICESIGNER).claimRewards()
    //             var reward = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE)
    //             currentReward = reward.sub(lastReward)
    //             lastReward = reward
    //             const currentBlock = await ethers.provider.getBlock("latest").then(b=>b.number);
    //             console.log("claim at blockNo got ",currentBlock," got reward",ethers.utils.formatEther(currentReward));
    //             await gotoBlockNumber( ethers.BigNumber.from(currentBlock + BLOCK_SKIP - 1));
    //         }
    //         var reward = await EPNSCoreV1Proxy.usersRewardsClaimed(ALICE)
    //         console.log("Total reward",ethers.utils.formatEther(reward));
    //     })

	});
});
