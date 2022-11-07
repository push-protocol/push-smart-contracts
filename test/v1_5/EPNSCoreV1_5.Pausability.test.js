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

    ({MOCKDAI, ADAI, DAI_WHALE_SIGNER} = await loadFixture(tokenFixture));

  });

 describe("EPNS CORE: Channel Creation Tests", function(){
   describe("Testing the Base Create Channel Function", function()
      {
          const CHANNEL_TYPE = 2;
          const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

           beforeEach(async function(){
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
            await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
            
            // DAI Token
            await MOCKDAI.connect(DAI_WHALE_SIGNER).transfer(CHANNEL_CREATOR,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

            await PushToken.transfer(CHANNEL_CREATOR, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await PushToken.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
         });
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

          it("Should revert if IF EPNSCoreV1::onlyInactiveChannels: Channel already Activated ", async function () {
            const CHANNEL_TYPE = 2;
            await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION,0)
            await expect(
              EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION,0)
            ).to.be.revertedWith("EPNSCoreV1_5::onlyInactiveChannels: Channel already Activated")
          });

          // Pauseable Tests
          it("Contract should only be Paused via GOVERNANCE", async function(){
            const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).pauseContract();

            await expect(tx).to.be.revertedWith('EPNSCoreV1_5::onlyGovernance: Caller not Governance')
          });

          it("Contract should only be UnPaused via GOVERNANCE", async function(){
            const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).unPauseContract();

            await expect(tx).to.be.revertedWith('EPNSCoreV1_5::onlyGovernance: Caller not Governance')
          });

          it("Channel Creation Should not be executed if Contract is Paused", async function(){
            const CHANNEL_TYPE = 2;

            await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
            const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION,0)

            await expect(tx).to.be.revertedWith("Pausable: paused")
          });

          it("Channel Creation Should execute after UNPAUSE", async function(){
            const CHANNEL_TYPE = 2;

            await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
            const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION,0)

            await expect(tx).to.be.revertedWith("Pausable: paused");
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).unPauseContract();
            const tx_2 = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION,0)

            await expect(tx_2)
              .to.emit(EPNSCoreV1Proxy, 'AddChannel')
              .withArgs(CHANNEL_CREATOR, CHANNEL_TYPE, ethers.utils.hexlify(testChannel));

          });

          it("Channel Deactivation Should not be executed if Contract is Paused", async function(){
            const CHANNEL_TYPE = 2;

            await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
            const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();

            await expect(tx).to.be.revertedWith("Pausable: paused")
          });

          it("Channel Reactivation Should not be executed if Contract is Paused", async function(){
            const CHANNEL_TYPE = 2;

            await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
            const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).reactivateChannel(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

            await expect(tx).to.be.revertedWith("Pausable: paused")
          });

          it("Channel Blocking Should not be executed if Contract is Paused", async function(){
            const CHANNEL_TYPE = 2;

            await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
            const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).blockChannel(CHANNEL_CREATOR);

            await expect(tx).to.be.revertedWith("Pausable: paused")
          });
    });

});
});