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
  const ADD_CHANNEL_MIN_POOL_CONTRIBUTION = tokensBN(50)
  const ADD_CHANNEL_MAX_POOL_CONTRIBUTION = tokensBN(250000 * 50)
  const CHANNEL_DEACTIVATION_FEES = tokensBN(10);
  const ADJUST_FOR_FLOAT = bn(10 ** 7)

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
    describe("Testing Deactivation and Reactivation of Channels", function(){
      const CHANNEL_TYPE = 2;
      const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

      beforeEach(async function(){
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
        await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
        await PushToken.transfer(BOB, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await PushToken.transfer(ALICE, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await PushToken.transfer(CHANNEL_CREATOR, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await PushToken.connect(BOBSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await PushToken.connect(ALICESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await PushToken.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
      });

      it("Should Revert if Channel is Inactiave", async function () {
        const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
        await expect(tx).to.be.revertedWith("EPNSCoreV1::onlyActivatedChannels: Channel Deactivated, Blocked or Does Not Exist");
      });

      it("Should Revert if Channel is already Deactivated", async function () {
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
        const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
        await expect(tx).to.be.revertedWith("EPNSCoreV1::onlyActivatedChannels: Channel Deactivated, Blocked or Does Not Exist");
      });

      it("Should set the created Channel State to '1' and decativated to '2' ", async function() {
        const channelState_before = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        const channelState_afterCreation = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
        const channelState_afterDeactivation = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

        await expect(channelState_before.channelState).to.be.equal(0);
        await expect(channelState_afterCreation.channelState).to.be.equal(1);
        await expect(channelState_afterDeactivation.channelState).to.be.equal(2);
      })

      it("Should decrease Pool balance on Channel Deactivation", async function() {
        const POOL_FUNDSBeforeChannelCreation = await EPNSCoreV1Proxy.POOL_FUNDS()

        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        const POOL_FUNDSAfterChannelCreation = await EPNSCoreV1Proxy.POOL_FUNDS()

        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
        const POOL_FUNDSAfterChannelDeactivation = await EPNSCoreV1Proxy.POOL_FUNDS()

        await expect(POOL_FUNDSBeforeChannelCreation).to.be.equal(0);
        await expect(POOL_FUNDSAfterChannelCreation).to.be.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await expect(POOL_FUNDSAfterChannelDeactivation).to.be.equal(CHANNEL_DEACTIVATION_FEES);

      });

      it("Should increase user balance on Channel Deactivation", async function() {
        const UserBalanceBeforeChannelCreation = await PushToken.balanceOf(CHANNEL_CREATOR);

        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(
          CHANNEL_TYPE, 
          testChannel,
          ADD_CHANNEL_MIN_POOL_CONTRIBUTION
        );
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
        
        const UserBalanceAfterChannelDeactivation = await PushToken.balanceOf(CHANNEL_CREATOR);
        const expectedUserBalance = UserBalanceBeforeChannelCreation.sub(CHANNEL_DEACTIVATION_FEES)

        await expect(UserBalanceAfterChannelDeactivation).to.be.equal(expectedUserBalance);

      });

      it("Should update the Channel Weight Correctly on channel activation and deletion", async function() {
        const channelState_before = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        const channelState_afterCreation = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
        const channelState_afterDeactivation = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

        const channelWeihght_OLD = ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        const channelWeight_NEW = CHANNEL_DEACTIVATION_FEES.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

        await expect(channelState_before.channelWeight).to.be.equal(0);
        await expect(channelState_afterCreation.poolContribution).to.be.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await expect(channelState_afterDeactivation.poolContribution).to.be.equal(CHANNEL_DEACTIVATION_FEES);
        await expect(channelState_afterCreation.channelWeight).to.be.equal(channelWeihght_OLD);
        await expect(channelState_afterDeactivation.channelWeight).to.be.equal(channelWeight_NEW);
      });      


    });

    describe("Testing Reactivation of Channels", function(){
      const CHANNEL_TYPE = 2;
      const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

      beforeEach(async function(){
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
        await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
        await PushToken.transfer(BOB, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await PushToken.transfer(ALICE, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await PushToken.transfer(CHANNEL_CREATOR, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10));
        await PushToken.connect(BOBSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await PushToken.connect(ALICESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await PushToken.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10));
      });

      it("Should allow reactivation of deactivated channel", async function () {
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
        const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).reactivateChannel(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await expect(tx)
          .to.emit(EPNSCoreV1Proxy, 'ReactivateChannel')
          .withArgs(CHANNEL_CREATOR, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
      });
      
      it("Should revert on reactivation of active or blocked channel", async function () {
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        
        // try to reactivate activated channel
        const tx1 = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).reactivateChannel(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await expect(tx1)
          .to.be.revertedWith('EPNSCoreV1::onlyDeactivatedChannels: Channel is not Deactivated Yet');
        
        // try to reactive the blocked channel
        await EPNSCoreV1Proxy.blockChannel(CHANNEL_CREATOR);
        const tx2 = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).reactivateChannel(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await expect(tx2)
          .to.be.revertedWith('EPNSCoreV1::onlyDeactivatedChannels: Channel is not Deactivated Yet');
      });

      it("Should Revert if Minimum Required Amount is not passed while Reactivating Channel", async function () {
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
        const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).reactivateChannel(CHANNEL_DEACTIVATION_FEES);
        await expect(tx).to.be.revertedWith("EPNSCoreV1::reactivateChannel: Insufficient Funds Passed for Channel Reactivation");
      });

      it("Should set the reactivated Channel State to '1' ", async function() {
        const channelState_before = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        const channelState_afterCreation = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
        const channelState_afterDeactivation = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).reactivateChannel(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        const channelState_afterReactivation= await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

        await expect(channelState_before.channelState).to.be.equal(0);
        await expect(channelState_afterCreation.channelState).to.be.equal(1);
        await expect(channelState_afterDeactivation.channelState).to.be.equal(2);
        await expect(channelState_afterReactivation.channelState).to.be.equal(1);
      });

      it("Should update the Channel Weight and Pool Contribution Correctl on Reactivation", async function() {
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
        const channelState_afterDeactivation = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).reactivateChannel(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        const channelState_afterReactivation = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

        const newChannelPoolContribution = ADD_CHANNEL_MIN_POOL_CONTRIBUTION.add(CHANNEL_DEACTIVATION_FEES);
        const channelWeihght_Deact = CHANNEL_DEACTIVATION_FEES.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        const channelWeight_React = newChannelPoolContribution.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

        await expect(channelState_afterDeactivation.channelWeight).to.be.equal(channelWeihght_Deact);
        await expect(channelState_afterDeactivation.poolContribution).to.be.equal(CHANNEL_DEACTIVATION_FEES);
        await expect(channelState_afterReactivation.channelWeight).to.be.equal(channelWeight_React);
        await expect(channelState_afterReactivation.poolContribution).to.be.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION.add(CHANNEL_DEACTIVATION_FEES));
      })

      it("Should update pool balance correctly on Channel Reactivation", async function() {
        const POOL_FUNDSBeforeChannelCreation = await EPNSCoreV1Proxy.POOL_FUNDS()

        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        const POOL_FUNDSAfterChannelCreation = await EPNSCoreV1Proxy.POOL_FUNDS()

        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
        const POOL_FUNDSAfterChannelDeactivation = await EPNSCoreV1Proxy.POOL_FUNDS()

        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).reactivateChannel(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        const POOL_FUNDSAfterChannelReactivation = await EPNSCoreV1Proxy.POOL_FUNDS()

        await expect(POOL_FUNDSBeforeChannelCreation).to.be.equal(0);
        await expect(POOL_FUNDSAfterChannelCreation).to.be.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await expect(POOL_FUNDSAfterChannelDeactivation).to.be.equal(CHANNEL_DEACTIVATION_FEES);
        await expect(POOL_FUNDSAfterChannelReactivation).to.be.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION.add(CHANNEL_DEACTIVATION_FEES));
      });
    });

    describe("Testomg BLOCK channel Function", function(){
      const CHANNEL_TYPE = 2;
      const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

      beforeEach(async function(){
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
        await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
        await PushToken.transfer(BOB, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await PushToken.transfer(ALICE, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await PushToken.transfer(CHANNEL_CREATOR, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10));
        await PushToken.connect(BOBSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await PushToken.connect(ALICESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await PushToken.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10));
      });

      it("Should revert if Caller is NOT ADMIN", async function () {
        const CHANNEL_TYPE = 2;
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

        const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).blockChannel(CHANNEL_CREATOR);

        await expect(tx).to.be.revertedWith("EPNSCoreV1::onlyPushChannelAdmin: Caller not pushChannelAdmin")
      });

      it("Allows admin to block any channel is active state", async function(){
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        const tx = EPNSCoreV1Proxy.connect(ADMINSIGNER).blockChannel(CHANNEL_CREATOR);

        await expect(tx)
          .to.emit(EPNSCoreV1Proxy, 'ChannelBlocked')
          .withArgs(CHANNEL_CREATOR);
      }); 

      it("Allows admin to block any channel is deactive state", async function(){
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
        const tx = EPNSCoreV1Proxy.connect(ADMINSIGNER).blockChannel(CHANNEL_CREATOR);

        await expect(tx)
          .to.emit(EPNSCoreV1Proxy, 'ChannelBlocked')
          .withArgs(CHANNEL_CREATOR);

      }); 

      it("Should revert if Target Channel is NOT ACTIVATED YET", async function () {
        const tx1 = EPNSCoreV1Proxy.connect(ADMINSIGNER).blockChannel(CHANNEL_CREATOR);
        await expect(tx1).to.be.revertedWith("EPNSCoreV1::onlyUnblockedChannels: Channel is BLOCKED Already or Not Activated Yet")
      });

      it("Should revert if Target Channel is NOT BLOCKED ALREADY", async function () {
        const CHANNEL_TYPE = 2;
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).blockChannel(CHANNEL_CREATOR);

        const tx1 = EPNSCoreV1Proxy.connect(ADMINSIGNER).blockChannel(CHANNEL_CREATOR);
        await expect(tx1).to.be.revertedWith("EPNSCoreV1::onlyUnblockedChannels: Channel is BLOCKED Already or Not Activated Yet")
      });

      it("Should update Channel's Details Correctly", async function(){
        const CHANNEL_TYPE = 2;
        const channelWeight_AfterChannelBlock = CHANNEL_DEACTIVATION_FEES.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        const protocolFeeBefore = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
        const channelsCountBefore = await EPNSCoreV1Proxy.channelsCount();

        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

        const protocolFeeAfterChannelCreation = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
        const channelDetailsAfter = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR)
        const channelsCountAfterChannelCreation = await EPNSCoreV1Proxy.channelsCount();

        await EPNSCoreV1Proxy.connect(ADMINSIGNER).blockChannel(CHANNEL_CREATOR);
        const channelDetailsAfterBlocked = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR)
        const channelsCountAfterBlocked = await EPNSCoreV1Proxy.channelsCount();
        const protocolFeeAfterChannelBlocked = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();

        await expect(channelsCountBefore).to.be.equal(0);
        await expect(channelsCountAfterChannelCreation).to.be.equal(1);
        await expect(channelsCountAfterBlocked).to.be.equal(0);

        await expect(protocolFeeBefore).to.be.equal(0);
        await expect(protocolFeeAfterChannelCreation).to.be.equal(0);
        await expect(protocolFeeAfterChannelBlocked).to.be.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION.sub(CHANNEL_DEACTIVATION_FEES));

        await expect(channelDetailsAfterBlocked.channelState).to.be.equal(3);
        await expect(channelDetailsAfterBlocked.channelWeight).to.be.equal(channelWeight_AfterChannelBlock);
        await expect(channelDetailsAfterBlocked.poolContribution).to.be.equal(CHANNEL_DEACTIVATION_FEES);

      });

      it("Should update PROTOCOL_POOL_FEES on Channel Block", async function() {
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        const POOL_FUNDS_BFORE_BLOCK = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES()

        await EPNSCoreV1Proxy.blockChannel(CHANNEL_CREATOR);
        const POOL_FUNDSAfterChannelBlock = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES()
        const expectedPoolBalance = POOL_FUNDS_BFORE_BLOCK.add(ADD_CHANNEL_MIN_POOL_CONTRIBUTION.sub(CHANNEL_DEACTIVATION_FEES))

        await expect(expectedPoolBalance).to.be.equal(POOL_FUNDSAfterChannelBlock);
      });

    });

  });
});
