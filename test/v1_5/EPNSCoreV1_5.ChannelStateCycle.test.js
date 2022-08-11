const { ethers,waffle } = require("hardhat");

const {
  bn,
  tokensBN,
  ChannelAction,
  readjustFairShareOfChannels,
} = require("../../helpers/utils");


const {epnsContractFixture,tokenFixture} = require("../common/fixtures")
const {expect} = require("../common/expect")
const createFixtureLoader = waffle.createFixtureLoader;

describe("EPNS CoreV2 Protocol", function () {
  const FEE_AMOUNT = tokensBN(10)
  const ADJUST_FOR_FLOAT = bn(10 ** 7)
  const MIN_POOL_CONTRIBUTION = tokensBN(1)
  const ADD_CHANNEL_MIN_FEES = tokensBN(50)
  const ADD_CHANNEL_MAX_POOL_CONTRIBUTION = tokensBN(250000 * 50)

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
      EPNS_TOKEN_ADDRS,
    } = await loadFixture(epnsContractFixture));

    ({MOCKDAI, ADAI} = await loadFixture(tokenFixture));

  });


  describe("EPNS CORE: Channel Deactivation & Reactivation Tests", function(){
    // describe("Testing Deactivation and Reactivation of Channels", function(){
    //   const CHANNEL_TYPE = 2;
    //   const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");
    //
    //   beforeEach(async function(){
    //     await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
    //     await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
    //     await PushToken.transfer(BOB, ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
    //     await PushToken.transfer(ALICE, ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
    //     await PushToken.transfer(CHARLIE, ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
    //     await PushToken.transfer(CHANNEL_CREATOR, ADD_CHANNEL_MIN_FEES);
    //     await PushToken.connect(BOBSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
    //     await PushToken.connect(ALICESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
    //     await PushToken.connect(CHARLIESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
    //     await PushToken.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_FEES);
    //   });
    //
    //   it("Should Revert if Channel is Inactiave", async function () {
    //     const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
    //     await expect(tx).to.be.revertedWith("EPNSCoreV1.5::onlyActivatedChannels: Channel Deactivated, Blocked or Does Not Exist");
    //   });
    //
    //   it("Should Revert if Channel is already Deactivated", async function () {
    //     await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel, ADD_CHANNEL_MIN_FEES, 0);
    //
    //     await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
    //     const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
    //     await expect(tx).to.be.revertedWith("EPNSCoreV1.5::onlyActivatedChannels: Channel Deactivated, Blocked or Does Not Exist");
    //   });
    //
    //   it("Should set the created Channel State to '1' and decativated to '2' ", async function() {
    //     const channelState_before = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);
    //
    //     await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel, ADD_CHANNEL_MIN_FEES, 0);
    //     const channelState_afterCreation = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);
    //
    //     await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
    //     const channelState_afterDeactivation = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);
    //
    //     await expect(channelState_before.channelState).to.be.equal(0);
    //     await expect(channelState_afterCreation.channelState).to.be.equal(1);
    //     await expect(channelState_afterDeactivation.channelState).to.be.equal(2);
    //   })
    //
    //   it("Deactivation should update the POOL_FUNDS correctly", async function() {
    //     const POOL_FUNDSBeforeChannelCreation = await EPNSCoreV1Proxy.POOL_FUNDS()
    //
    //     await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel, ADD_CHANNEL_MIN_FEES, 0);
    //     const POOL_FUNDSAfterChannelCreation = await EPNSCoreV1Proxy.POOL_FUNDS()
    //
    //     await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
    //     const POOL_FUNDSAfterChannelDeactivation = await EPNSCoreV1Proxy.POOL_FUNDS()
    //
    //     await expect(POOL_FUNDSBeforeChannelCreation).to.be.equal(0);
    //     await expect(POOL_FUNDSAfterChannelCreation).to.be.equal(ADD_CHANNEL_MIN_FEES.sub(FEE_AMOUNT));
    //     await expect(POOL_FUNDSAfterChannelDeactivation).to.be.equal(MIN_POOL_CONTRIBUTION);
    //     await expect(POOL_FUNDSAfterChannelDeactivation).to.be.lt(POOL_FUNDSAfterChannelCreation)
    //
    //   });
    //
    //   it("Deactivation shouldn't cause any Change in PROTOCOL_POOL_FEES", async function() {
    //     const POOL_FEES_BeforeChannelCreation = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES()
    //
    //     await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel, ADD_CHANNEL_MIN_FEES, 0);
    //     const POOL_FEES_AfterChannelCreation = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES()
    //
    //     await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
    //     const POOL_FEES_AfterChannelDeactivation = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES()
    //
    //     await expect(POOL_FEES_BeforeChannelCreation).to.be.equal(0);
    //     await expect(POOL_FEES_AfterChannelCreation).to.be.equal(FEE_AMOUNT);
    //     await expect(POOL_FEES_AfterChannelDeactivation).to.be.equal(POOL_FEES_AfterChannelCreation);
    //
    //   });
    //
    //   it("After deactivation, User should recieve correct amount of PUSH Token refund", async function() {
    //     const UserBalanceBeforeChannelCreation = await PushToken.balanceOf(CHANNEL_CREATOR);
    //
    //     await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(
    //       CHANNEL_TYPE,
    //       testChannel,
    //       ADD_CHANNEL_MIN_FEES,
    //       0
    //     );
    //     await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
    //
    //     const UserBalanceAfterChannelDeactivation = await PushToken.balanceOf(CHANNEL_CREATOR);
    //     const expectedUserBalance = UserBalanceBeforeChannelCreation.sub(FEE_AMOUNT).sub(MIN_POOL_CONTRIBUTION)
    //
    //     await expect(UserBalanceAfterChannelDeactivation).to.be.equal(expectedUserBalance);
    //
    //   });
    //
    //   it("Should update the Channel Weight Correctly on channel activation and deletion", async function() {
    //     const channelState_before = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);
    //
    //     await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES,0);
    //     const channelState_afterCreation = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);
    //
    //     await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
    //     const channelState_afterDeactivation = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);
    //
    //     const poolContributionBeforeDeactivation = ADD_CHANNEL_MIN_FEES.sub(FEE_AMOUNT);
    //     const poolContributionAfterDeactivation = MIN_POOL_CONTRIBUTION;
    //     const channelWeihght_OLD = poolContributionBeforeDeactivation.mul(ADJUST_FOR_FLOAT).div(MIN_POOL_CONTRIBUTION);
    //     const channelWeight_NEW = MIN_POOL_CONTRIBUTION.mul(ADJUST_FOR_FLOAT).div(MIN_POOL_CONTRIBUTION);
    //
    //     await expect(channelState_before.channelWeight).to.be.equal(0);
    //     await expect(channelState_afterCreation.poolContribution).to.be.equal(poolContributionBeforeDeactivation);
    //     await expect(channelState_afterDeactivation.poolContribution).to.be.equal(poolContributionAfterDeactivation);
    //     await expect(channelState_afterCreation.channelWeight).to.be.equal(channelWeihght_OLD);
    //     await expect(channelState_afterDeactivation.channelWeight).to.be.equal(channelWeight_NEW);
    //   });
    //
    // });

    // describe("Testing Reactivation of Channels", function(){
    //   const CHANNEL_TYPE = 2;
    //   const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");
    //
    //   beforeEach(async function(){
    //     await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
    //     await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
    //     await PushToken.transfer(BOB, ADD_CHANNEL_MIN_FEES);
    //     await PushToken.transfer(ALICE, ADD_CHANNEL_MIN_FEES);
    //     await PushToken.transfer(CHANNEL_CREATOR, ADD_CHANNEL_MIN_FEES.mul(10));
    //     await PushToken.connect(BOBSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_FEES);
    //     await PushToken.connect(ALICESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_FEES);
    //     await PushToken.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_FEES.mul(10));
    //   });
    //
    //   it("Should allow reactivation of deactivated channel", async function () {
    //     await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES,0);
    //     await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
    //     const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).reactivateChannel(ADD_CHANNEL_MIN_FEES);
    //     await expect(tx)
    //       .to.emit(EPNSCoreV1Proxy, 'ReactivateChannel')
    //       .withArgs(CHANNEL_CREATOR, ADD_CHANNEL_MIN_FEES);
    //   });
    //
    //   it("Should revert on reactivation of active or blocked channel", async function () {
    //     await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES,0);
    //
    //     // try to reactivate activated channel
    //     const tx1 = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).reactivateChannel(ADD_CHANNEL_MIN_FEES);
    //     await expect(tx1)
    //       .to.be.revertedWith('EPNSCoreV1.5::onlyDeactivatedChannels: Channel is not Deactivated Yet');
    //
    //     // try to reactive the blocked channel
    //     await EPNSCoreV1Proxy.blockChannel(CHANNEL_CREATOR);
    //     const tx2 = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).reactivateChannel(ADD_CHANNEL_MIN_FEES);
    //     await expect(tx2)
    //       .to.be.revertedWith('EPNSCoreV1.5::onlyDeactivatedChannels: Channel is not Deactivated Yet');
    //   });
    //
    //   it("Should Revert if Minimum Required Amount is not passed while Reactivating Channel", async function () {
    //     await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES,0);
    //     await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
    //     const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).reactivateChannel(FEE_AMOUNT);
    //     await expect(tx).to.be.revertedWith("EPNSCoreV1.5::reactivateChannel: Insufficient Funds Passed for Channel Reactivation");
    //   });
    //
    //   it("Should set the reactivated Channel State to '1' ", async function() {
    //     const channelState_before = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);
    //
    //     await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES,0);
    //     const channelState_afterCreation = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);
    //
    //     await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
    //     const channelState_afterDeactivation = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);
    //
    //     await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).reactivateChannel(ADD_CHANNEL_MIN_FEES);
    //     const channelState_afterReactivation= await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);
    //
    //     await expect(channelState_before.channelState).to.be.equal(0);
    //     await expect(channelState_afterCreation.channelState).to.be.equal(1);
    //     await expect(channelState_afterDeactivation.channelState).to.be.equal(2);
    //     await expect(channelState_afterReactivation.channelState).to.be.equal(1);
    //   });
    //
    //   it("Reactivation should update the POOL_FUNDS & PROTOCOL_POOL_FEES correctly", async function() {
    //       // Channel Creation
    //       await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel, ADD_CHANNEL_MIN_FEES, 0);
    //       const POOL_FUNDSAfterChannelCreation = await EPNSCoreV1Proxy.POOL_FUNDS()
    //       const POOL_FEES_AfterChannelCreation = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES()
    //       // Channel Deactivation
    //       await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
    //       const POOL_FUNDSAfterChannelDeactivation = await EPNSCoreV1Proxy.POOL_FUNDS()
    //       const POOL_FEES_BeforeChannelDeactivation = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES()
    //       // Channel Reactivation
    //       await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).reactivateChannel(ADD_CHANNEL_MIN_FEES);
    //       const POOL_FUNDSAfterChannelReactivation = await EPNSCoreV1Proxy.POOL_FUNDS()
    //       const POOL_FEES_BeforeChannelReactivation = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES()
    //
    //       // Calculating POOL_Funds and PROTOCOL_POOL_FEES changes during Activation Cyles
    //       const feesAfterChannelCreation = FEE_AMOUNT;
    //       const feesAfterChannelReactivation = FEE_AMOUNT.mul(2);
    //       const fundsAfterChannelCreation = ADD_CHANNEL_MIN_FEES.sub(FEE_AMOUNT);
    //       const fundsAfterChannelDeactivation = MIN_POOL_CONTRIBUTION;
    //       const fundsAfterChannelReactivation = ADD_CHANNEL_MIN_FEES.sub(FEE_AMOUNT).add(MIN_POOL_CONTRIBUTION);
    //       // Validating POOL_FUNDS changes
    //       await expect(POOL_FUNDSAfterChannelCreation).to.be.equal(fundsAfterChannelCreation);
    //       await expect(POOL_FUNDSAfterChannelDeactivation).to.be.equal(fundsAfterChannelDeactivation);
    //       await expect(POOL_FUNDSAfterChannelReactivation).to.be.equal(fundsAfterChannelReactivation);
    //       // Validating PROTOCOL_POOL_FEES changes
    //       await expect(POOL_FEES_AfterChannelCreation).to.be.equal(feesAfterChannelCreation);
    //       await expect(POOL_FEES_BeforeChannelDeactivation).to.be.equal(POOL_FEES_AfterChannelCreation);
    //       await expect(POOL_FEES_BeforeChannelReactivation).to.be.equal(feesAfterChannelReactivation);
    //     });
    //
    //   it("Should update the Channel Weight and Pool Contribution Correct on Reactivation", async function() {
    //     await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES,0);
    //     await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
    //     const channelState_afterDeactivation = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);
    //
    //     await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).reactivateChannel(ADD_CHANNEL_MIN_FEES);
    //     const channelState_afterReactivation = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);
    //
    //     // Calculation of Weight and Pool Contribution after Deactivation
    //     const poolContributionAfterDeactivation = MIN_POOL_CONTRIBUTION;
    //     const channelWeightAfterDeactivation = MIN_POOL_CONTRIBUTION.mul(ADJUST_FOR_FLOAT).div(MIN_POOL_CONTRIBUTION);
    //     // Calculation of Weight and Pool Contribution after Reactivation
    //     const poolFundAmount = ADD_CHANNEL_MIN_FEES.sub(FEE_AMOUNT);
    //     const poolContributionAfteReactivation = channelState_afterDeactivation.poolContribution.add(poolFundAmount);
    //     const channelWeightAfterReactivation = poolContributionAfteReactivation.mul(ADJUST_FOR_FLOAT).div(MIN_POOL_CONTRIBUTION);
    //
    //     // Validating poolContribution and ChannelWeight after Reactivation
    //     await expect(channelState_afterDeactivation.channelWeight).to.be.equal(channelWeightAfterDeactivation);
    //     await expect(channelState_afterDeactivation.poolContribution).to.be.equal(poolContributionAfterDeactivation);
    //     await expect(channelState_afterReactivation.channelWeight).to.be.equal(channelWeightAfterReactivation);
    //     await expect(channelState_afterReactivation.poolContribution).to.be.equal(poolContributionAfteReactivation);
    //   })
    //
    // });

    describe("Testing BLOCK channel Function", function(){
      const CHANNEL_TYPE = 2;
      const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

      beforeEach(async function(){
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
        await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
        await PushToken.transfer(BOB, ADD_CHANNEL_MIN_FEES);
        await PushToken.transfer(ALICE, ADD_CHANNEL_MIN_FEES);
        await PushToken.transfer(CHANNEL_CREATOR, ADD_CHANNEL_MIN_FEES.mul(10));
        await PushToken.connect(BOBSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_FEES);
        await PushToken.connect(ALICESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_FEES);
        await PushToken.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_FEES.mul(10));
      });

      it("Should revert if Caller is NOT ADMIN", async function () {
        const CHANNEL_TYPE = 2;
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES,0);

        const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).blockChannel(CHANNEL_CREATOR);

        await expect(tx).to.be.revertedWith("EPNSCoreV1.5::onlyPushChannelAdmin: Caller not pushChannelAdmin")
      });

      it("Allows admin to block any channel is active state", async function(){
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES,0);
        const tx = EPNSCoreV1Proxy.connect(ADMINSIGNER).blockChannel(CHANNEL_CREATOR);

        await expect(tx)
          .to.emit(EPNSCoreV1Proxy, 'ChannelBlocked')
          .withArgs(CHANNEL_CREATOR);
      });

      it("Allows admin to block any channel is deactive state", async function(){
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES,0);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
        const tx = EPNSCoreV1Proxy.connect(ADMINSIGNER).blockChannel(CHANNEL_CREATOR);

        await expect(tx)
          .to.emit(EPNSCoreV1Proxy, 'ChannelBlocked')
          .withArgs(CHANNEL_CREATOR);

      });

      it("Should revert if Target Channel is NOT ACTIVATED YET", async function () {
        const tx1 = EPNSCoreV1Proxy.connect(ADMINSIGNER).blockChannel(CHANNEL_CREATOR);
        await expect(tx1).to.be.revertedWith("EPNSCoreV1.5::onlyUnblockedChannels: Channel is BLOCKED Already or Not Activated Yet")
      });

      it("Should revert if Target Channel is NOT BLOCKED ALREADY", async function () {
        const CHANNEL_TYPE = 2;
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES,0);
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).blockChannel(CHANNEL_CREATOR);

        const tx1 = EPNSCoreV1Proxy.connect(ADMINSIGNER).blockChannel(CHANNEL_CREATOR);
        await expect(tx1).to.be.revertedWith("EPNSCoreV1.5::onlyUnblockedChannels: Channel is BLOCKED Already or Not Activated Yet")
      });

      it("After Blocking, PoolFunds and PoolFees Should be Updated correctly", async function(){
        const CHANNEL_TYPE = 2;
        const protocolFeeBefore = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();

        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES,0);

        const channelDetailsBeforeBlocked = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR)
        const poolFundsAfterChannelCreation = await EPNSCoreV1Proxy.POOL_FUNDS();
        const poolFeeAfterChannelCreation = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
        const protocolFeeAfterChannelCreation = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();

        await EPNSCoreV1Proxy.connect(ADMINSIGNER).blockChannel(CHANNEL_CREATOR);
        const poolFundsAfterChannelBlock = await EPNSCoreV1Proxy.POOL_FUNDS();
        const poolFeeAfterChannelBlock = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
        const channelDetailsAfterBlocked = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR)

        //Calculating Pool_Fees and Funds
        const poolContribution = channelDetailsBeforeBlocked.poolContribution.sub(MIN_POOL_CONTRIBUTION);
        const expectedPoolFundsAfterBlock = poolFundsAfterChannelCreation.sub(poolContribution);
        const expectedChannelWeightAfterBlock = MIN_POOL_CONTRIBUTION.mul(ADJUST_FOR_FLOAT).div(MIN_POOL_CONTRIBUTION);
        const expectedPoolFeesAfterBlock = poolFeeAfterChannelCreation.add(poolContribution);

        // Validating PoolFees and PoolFunds
        await expect(protocolFeeBefore).to.be.equal(0);
        await expect(poolFeeAfterChannelCreation).to.be.equal(FEE_AMOUNT);
        await expect(poolFeeAfterChannelBlock).to.be.equal(expectedPoolFeesAfterBlock);

        await expect(poolFundsAfterChannelCreation).to.be.equal(ADD_CHANNEL_MIN_FEES.sub(FEE_AMOUNT));
        await expect(poolFundsAfterChannelBlock).to.be.equal(expectedPoolFundsAfterBlock);

      });

      it("After Blocking, Channel Details Should be Updated correctly", async function(){
        const CHANNEL_TYPE = 2;
        const channelWeight_AfterChannelBlock = FEE_AMOUNT.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_FEES);
        const protocolFeeBefore = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
        const channelsCountBefore = await EPNSCoreV1Proxy.channelsCount();

        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES,0);

        const channelDetailsBeforeBlocked = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR)
        const poolFundsAfterChannelCreation = await EPNSCoreV1Proxy.POOL_FUNDS();
        const poolFeeAfterChannelCreation = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
        const protocolFeeAfterChannelCreation = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
        const channelsCountAfterChannelCreation = await EPNSCoreV1Proxy.channelsCount();

        await EPNSCoreV1Proxy.connect(ADMINSIGNER).blockChannel(CHANNEL_CREATOR);
        const poolFundsAfterChannelBlock = await EPNSCoreV1Proxy.POOL_FUNDS();
        const poolFeeAfterChannelBlock = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
        const channelDetailsAfterBlocked = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR)
        const channelsCountAfterBlocked = await EPNSCoreV1Proxy.channelsCount();

        //Calculating Pool_Fees and Funds
        const expectedPoolContributionAfterBlock = MIN_POOL_CONTRIBUTION;
        const expectedChannelWeightAfterBlock = MIN_POOL_CONTRIBUTION.mul(ADJUST_FOR_FLOAT).div(MIN_POOL_CONTRIBUTION);

        await expect(channelsCountBefore).to.be.equal(0);
        await expect(channelsCountAfterChannelCreation).to.be.equal(1);
        await expect(channelsCountAfterBlocked).to.be.equal(0);

        await expect(channelDetailsAfterBlocked.channelState).to.be.equal(3);
        await expect(channelDetailsAfterBlocked.channelWeight).to.be.equal(expectedChannelWeightAfterBlock);
        await expect(channelDetailsAfterBlocked.poolContribution).to.be.equal(expectedPoolContributionAfterBlock);
      });

    });
  });
});
