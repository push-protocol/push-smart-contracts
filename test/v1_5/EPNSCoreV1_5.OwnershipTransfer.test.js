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
  const ADD_CHANNEL_MAX_POOL_CONTRIBUTION = tokensBN(250 * 50)

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

    /***
   * CHECKPOINTS TO CONSIDER WHILE TESTING -> Overall Stake-N-Claim Tests
   * ------------------------------------------
   * 1. Should only be called by the Channel Owner and For Activated Channels ✅
   * 2. Should only be called when contract is not PAUSED ✅
   * 3. Fee Amount should not be invalid ✅
   * 4. Protocol Pool Fee should be updated correctly on ownership transfer ✅
   * 5. Transfer of Channel Ownership should be done to the new Channel Address ✅
   * 6. Old Channel owner should be unsubscribed to the previously subscribed channels ✅
   * 7. Old Channel owner details should be erased from the contract ✅
   * 8. Function should emit the right event parameters ✅
   * 9. PUSH Channel Admin shouldn't be able to Change the ownership of any other Channel ✅
   * 10. Channel Ownership can't be transferred to an already existing Channel ✅
   */

     describe("EPNS CORE: Channel Ownership transfer Tests", function(){
        describe("Testing the transferChannelOwnership() Function", function()
           {
               const CHANNEL_TYPE = 2;
               const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");
     
                beforeEach(async function(){
                 await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
                 await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);

                 await PushToken.transfer(BOB, ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
                 await PushToken.transfer(ALICE, ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
                 await PushToken.transfer(CHARLIE, ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
                 await PushToken.transfer(CHANNEL_CREATOR, ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
                 await PushToken.connect(BOBSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
                 await PushToken.connect(ALICESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
                 await PushToken.connect(CHARLIESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
                 await PushToken.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
     
              });

               it("Should revert if IF Caller is not the owner of the Channel ", async function () {
                 await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES,0);
     
                 const tx = EPNSCoreV1Proxy.connect(BOBSIGNER).transferChannelOwnership(CHANNEL_CREATOR, BOB,ADD_CHANNEL_MIN_FEES);
     
                 await expect(tx).to.be.revertedWith("EPNSCoreV1_5::transferChannelOwnership: Invalid Channel Owner or Channel State")
               });

               it("Should revert if IF Contract is paused ", async function () {    
                await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES,0);
            
                await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
                const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).transferChannelOwnership(CHANNEL_CREATOR, BOB, ADD_CHANNEL_MIN_FEES);
    
                await expect(tx).to.be.revertedWith("Pausable: paused");

                await EPNSCoreV1Proxy.connect(ADMINSIGNER).unPauseContract();
                const tx_2nd = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).transferChannelOwnership(CHANNEL_CREATOR, BOB, ADD_CHANNEL_MIN_FEES);
                await expect(tx_2nd).to.emit(EPNSCoreV1Proxy, 'ChannelOwnershipTransfer')
                .withArgs(CHANNEL_CREATOR, BOB);

              });
     
            it("Should revert if Fee Amount passed is insufficient", async function(){                
                const feeAmount = tokensBN(10);
                await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES, 0);
    
                const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).transferChannelOwnership(CHANNEL_CREATOR, BOB, feeAmount);

                await expect(tx).to.be.revertedWith("EPNSCoreV1_5::transferChannelOwnership: Insufficient Funds Passed for Ownership Transfer Reactivation")
            });

            it("Incoming PUSH Tokens should adjusted accurately in Protocol Pool Fee (and Not Pool Funds)", async function(){
                await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES, 0);
                
                const poolFunds_before = await EPNSCoreV1Proxy.CHANNEL_POOL_FUNDS();
                const poolFee_before = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
                const coreBalance_before = await PushToken.balanceOf(EPNSCoreV1Proxy.address);

                const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).transferChannelOwnership(CHANNEL_CREATOR, BOB, ADD_CHANNEL_MIN_FEES);

                const poolFunds_after = await EPNSCoreV1Proxy.CHANNEL_POOL_FUNDS();
                const poolFee_after = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
                const coreBalance_after = await PushToken.balanceOf(EPNSCoreV1Proxy.address);

                await expect(poolFunds_after).to.be.equal(poolFunds_before);
                await expect(poolFee_after).to.be.equal(poolFee_before.add(ADD_CHANNEL_MIN_FEES));
                await expect(coreBalance_after).to.be.equal(coreBalance_before.add(ADD_CHANNEL_MIN_FEES));
            });

            it("Transfer of Ownership and all Channel details to new Channel should be done adequately ", async function(){
                await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES, 0);
                
                const oldChannel_before = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).channels(CHANNEL_CREATOR)
            
                //Old Channel Details
                const oldChannelType = oldChannel_before.channelType;
                const oldChannelState = oldChannel_before.channelState;
                const oldChannelWeight = oldChannel_before.channelWeight;
                const oldChannelStartBlock = oldChannel_before.channelStartBlock;
                const oldChannelUpdateBlock = oldChannel_before.channelUpdateBlock;
                const oldChannel_poolContribution = oldChannel_before.poolContribution;

                await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).transferChannelOwnership(CHANNEL_CREATOR, BOB, ADD_CHANNEL_MIN_FEES);

                const newChannel = await EPNSCoreV1Proxy.channels(BOB);

                // New Channel gets all Old Channel's Data
                expect(newChannel.channelState).to.equal(oldChannelState);
                expect(newChannel.poolContribution).to.equal(oldChannel_poolContribution);
                expect(newChannel.channelType).to.equal(oldChannelType);
                expect(newChannel.channelStartBlock).to.equal(oldChannelStartBlock);
                expect(newChannel.channelUpdateBlock).to.equal(oldChannelUpdateBlock);
                expect(newChannel.channelWeight).to.equal(oldChannelWeight);
                
                const oldChannel_after = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).channels(CHANNEL_CREATOR)

                //OldChannel is deleted
                expect(oldChannel_after.channelState).to.equal(0);
                expect(oldChannel_after.poolContribution).to.equal(0);
                expect(oldChannel_after.channelType).to.equal(0);
                expect(oldChannel_after.channelStartBlock).to.equal(0);
                expect(oldChannel_after.channelUpdateBlock).to.equal(0);
                expect(oldChannel_after.channelWeight).to.equal(0);
            });

            it("Channel Ownership Transfer should unsubscribes Old Channel address from PUSH Channels", async function(){
                await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES, 0);
        
                // before ownership transfer 
                var isNewOwnerSubscribedToOwnChannel_before = await EPNSCommV1Proxy.isUserSubscribed(BOB, BOB);
                var isNewOwnerSubscribedToAlerter_before = await EPNSCommV1Proxy.isUserSubscribed(ethers.constants.AddressZero, BOB);
                var isPushAdminSubscribedToNewOwner_before = await EPNSCommV1Proxy.isUserSubscribed(BOB, ADMIN);
                var isPushAdminSubscribedToOldChannel_before = await EPNSCommV1Proxy.isUserSubscribed(CHANNEL_CREATOR, ADMIN);
                
                expect(isNewOwnerSubscribedToOwnChannel_before).to.be.false;
                expect(isNewOwnerSubscribedToAlerter_before).to.be.false;
                expect(isPushAdminSubscribedToNewOwner_before).to.be.false;
                expect(isPushAdminSubscribedToOldChannel_before).to.be.true;
        
                
                await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).transferChannelOwnership(CHANNEL_CREATOR, BOB, ADD_CHANNEL_MIN_FEES);
        
                var isNewOwnerSubscribedToOwnChannel_after = await EPNSCommV1Proxy.isUserSubscribed(BOB, BOB);
                var isNewOwnerSubscribedToAlerter_after = await EPNSCommV1Proxy.isUserSubscribed(ethers.constants.AddressZero, BOB);
                var isPushAdminSubscribedToNewOwner_after = await EPNSCommV1Proxy.isUserSubscribed(BOB, ADMIN);
                var isPushAdminSubscribedToOldChannel_after = await EPNSCommV1Proxy.isUserSubscribed(CHANNEL_CREATOR, ADMIN);
                
                expect(isNewOwnerSubscribedToOwnChannel_after).to.be.true;
                expect(isNewOwnerSubscribedToAlerter_after).to.be.true;
                expect(isPushAdminSubscribedToNewOwner_after).to.be.true;
                expect(isPushAdminSubscribedToOldChannel_after).to.be.false;
              });
     
             it("Function should emit events correctly ", async function () {  
                await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES,0);

                const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).transferChannelOwnership(CHANNEL_CREATOR, BOB,ADD_CHANNEL_MIN_FEES);
                await expect(tx).to.emit(EPNSCoreV1Proxy, 'ChannelOwnershipTransfer')
                .withArgs(CHANNEL_CREATOR, BOB);

              });

              it("Should revert if IF PUSH Channel Admin tries to transfer ownership of any other Channel ", async function () {
                await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES,0);
    
                const tx = EPNSCoreV1Proxy.connect(ADMINSIGNER).transferChannelOwnership(CHANNEL_CREATOR, BOB, ADD_CHANNEL_MIN_FEES);
    
                await expect(tx).to.be.revertedWith("EPNSCoreV1_5::transferChannelOwnership: Invalid Channel Owner or Channel State")
              });

              it("Ownership can't be transferred to an already existing Channel", async function () {
                await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES,0);
                await EPNSCoreV1Proxy.connect(BOBSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES,0);

                const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).transferChannelOwnership(CHANNEL_CREATOR, BOB, ADD_CHANNEL_MIN_FEES);
    
                await expect(tx).to.be.revertedWith("EPNSCoreV1_5::transferChannelOwnership: Invalid address for new channel owner")
              });
     
         });
     
     });
});