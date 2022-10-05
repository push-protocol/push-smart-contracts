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
  const MIN_POOL_CONTRIBUTION = tokensBN(1)
  const ADD_CHANNEL_MIN_FEES = tokensBN(50)
  const ADD_CHANNEL_MAX_POOL_CONTRIBUTION = tokensBN(250000 * 50)
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


 describe("EPNS CORE: Channel Creation Tests", function(){
   describe("Testing the Base Create Channel Function", function()
      {
          const CHANNEL_TYPE = 2;
          const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

           beforeEach(async function(){
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
            await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
            await PushToken.transfer(BOB, ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
            await PushToken.transfer(ALICE, ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
            await PushToken.transfer(CHARLIE, ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
            await PushToken.transfer(CHANNEL_CREATOR, ADD_CHANNEL_MIN_FEES);
            await PushToken.connect(BOBSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
            await PushToken.connect(ALICESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
            await PushToken.connect(CHARLIESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
            await PushToken.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_FEES);

         });
          /**
            * "createChannelWithPUSH" Function CheckPoints
            * REVERT CHECKS
            * Should revert IF EPNSCoreV1::onlyInactiveChannels: Channel already Activated
            * Should revert if Channel Type is NOT THE Allowed One
            * Should revert if AMOUNT Passed if Not greater than or equal to the 'ADD_CHANNEL_MIN_FEES'
            *
            * FUNCTION Execution CHECKS
            * The Channel Creation Fees should be Transferred to the EPNS Core Proxy
            * Should deposit funds EPNS Core Proxy Contract and Increase the POOL_FUNDS State variable
            * Should Update the State Variables Correctly and Activate the Channel
            * Readjustment of the FS Ratio should be checked
            * Should Interact successfully with EPNS Communicator and Subscribe Channel Owner to his own Channel
            * Should subscribe Channel owner to 0x000 channel
            * Should subscribe ADMIN to the Channel Creator's Channel
           **/

          it("Should revert if IF EPNSCoreV1::onlyInactiveChannels: Channel already Activated ", async function () {
            const CHANNEL_TYPE = 2;
            await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES,0);

            const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES,0);

            await expect(tx).to.be.revertedWith("EPNSCoreV1.5::onlyInactiveChannels: Channel already Activated")
          });

          it("Should revert Channel Type is not the ALLOWED TYPES", async function () {
            const CHANNEL_TYPE = 0;
            const tx1 = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel, ADD_CHANNEL_MIN_FEES,0);

            await expect(tx1).to.be.revertedWith("EPNSCoreV1.5::onlyUserAllowedChannelType: Channel Type Invalid")

            const CHANNEL_TYPE_SECOND = 1;
            const testChannelSecond = ethers.utils.toUtf8Bytes("test-channel-hello-world-two");

            const tx2 = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE_SECOND, testChannelSecond,ADD_CHANNEL_MIN_FEES,0);

            await expect(tx2).to.be.revertedWith("EPNSCoreV1.5::onlyUserAllowedChannelType: Channel Type Invalid")
          });

          it("should revert if allowance is not greater than min fees", async function(){
            const CHANNEL_TYPE = 2;

            await PushToken.transfer(CHARLIE, ADD_CHANNEL_MIN_FEES);
            await PushToken.connect(CHARLIESIGNER).approve(EPNSCoreV1Proxy.address, tokensBN(10));

            const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,tokensBN(10),0);

            await expect(tx).to.be.revertedWith("EPNSCoreV1.5::_createChannelWithPUSH: Insufficient Deposit Amount")
          });

            it("should revert if amount being transferred is greater than actually approved", async function(){
            const CHANNEL_TYPE = 2;

            await PushToken.transfer(CHARLIE, ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
            await PushToken.connect(CHARLIESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_FEES);

            const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MAX_POOL_CONTRIBUTION,0);

            await expect(tx).to.be.revertedWith("Push::transferFrom: transfer amount exceeds spender allowance")
          });


          it("should transfer given fees from creator account to proxy", async function(){
            const CHANNEL_TYPE = 2;

            const pushBalanceBefore_user = await PushToken.balanceOf(CHANNEL_CREATOR);
            const pushBalanceBefore_coreContract = await PushToken.balanceOf(EPNSCoreV1Proxy.address);

            await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES,0);

            const pushBalanceAfter_user = await PushToken.balanceOf(CHANNEL_CREATOR);
            const pushBalanceAfter_coreContract = await PushToken.balanceOf(EPNSCoreV1Proxy.address);

            expect(pushBalanceBefore_user.sub(pushBalanceAfter_user)).to.equal(pushBalanceAfter_coreContract.sub(pushBalanceBefore_coreContract));
          });

          it("EPNS Core Should create Channel and Update Relevant State variables accordingly", async function(){
          const channelsCountBefore = await EPNSCoreV1Proxy.channelsCount();

          const tx = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES,0);
          const channel = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).channels(CHANNEL_CREATOR)

          const blockNumber = tx.blockNumber;
          const expectedPoolContribution = ADD_CHANNEL_MIN_FEES.sub(FEE_AMOUNT)
          const channelWeight = expectedPoolContribution.mul(ADJUST_FOR_FLOAT).div(MIN_POOL_CONTRIBUTION);
          const channelsCountAfter = await EPNSCoreV1Proxy.channelsCount();
          const pool_funds = await EPNSCoreV1Proxy.POOL_FUNDS();

          // console.log(pool_funds.toString());
          expect(pool_funds).to.equal(expectedPoolContribution);
          expect(channel.channelState).to.equal(1);
          expect(channel.poolContribution).to.equal(expectedPoolContribution);
          expect(channel.channelType).to.equal(CHANNEL_TYPE);
          expect(channel.channelStartBlock).to.equal(blockNumber);
          expect(channel.channelUpdateBlock).to.equal(blockNumber);
          expect(channel.channelWeight).to.equal(channelWeight);
          expect(await EPNSCoreV1Proxy.channelById(channelsCountAfter.sub(1))).to.equal(CHANNEL_CREATOR);
          expect(channelsCountBefore.add(1)).to.equal(channelsCountAfter);
        }).timeout(10000);

      it("POOL_FUNDS & PROTOCOL_POOL_FEES should be updated correctly for Single Channel Creation", async function(){
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES,0);

        const expectedPoolContribution = ADD_CHANNEL_MIN_FEES.sub(FEE_AMOUNT)
        const pool_funds = await EPNSCoreV1Proxy.POOL_FUNDS();
        const pool_fees = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();

        expect(pool_fees).to.equal(FEE_AMOUNT);
        expect(pool_funds).to.equal(expectedPoolContribution);
      }).timeout(10000);

      it("POOL_FUNDS & PROTOCOL_POOL_FEES should be updated correctly for Multiple Channel Creation", async function(){
        // CHANNEL_CREATOR -> creates with 50 Push
        // BOB -> creates with 150 Push
        // Alice -> Creates with 290 PUSH
        // Charlie -> creates with 500
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES,0);
        await EPNSCoreV1Proxy.connect(BOBSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,tokensBN(150),0);
        await EPNSCoreV1Proxy.connect(ALICESIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,tokensBN(290),0);
        await EPNSCoreV1Proxy.connect(CHARLIESIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,tokensBN(500),0);

        const totalFeeFunds = FEE_AMOUNT.mul(4);
        const totalAmounDeposited = ADD_CHANNEL_MIN_FEES.add(tokensBN(150).add(tokensBN(290).add(tokensBN(500))));
        const totalPoolFunds = totalAmounDeposited.sub(totalFeeFunds);

        const pool_funds = await EPNSCoreV1Proxy.POOL_FUNDS();
        const pool_fees = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();

        expect(pool_fees).to.equal(totalFeeFunds);
        expect(pool_funds).to.equal(totalPoolFunds);
      }).timeout(10000);


        it("EPNS Core Should Interact with EPNS Communcator and make the necessary Subscriptions", async function(){
          const EPNS_ALERTER = '0x0000000000000000000000000000000000000000';

          const isChannelOwnerSubscribed_before = await EPNSCommV1Proxy.isUserSubscribed(CHANNEL_CREATOR, CHANNEL_CREATOR);
          const isChannelSubscribedToEPNS_before = await EPNSCommV1Proxy.isUserSubscribed(EPNS_ALERTER, CHANNEL_CREATOR);
          const isAdminSubscribedToChannel_before = await EPNSCommV1Proxy.isUserSubscribed(CHANNEL_CREATOR, ADMIN);

          await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES,0);
          const channel = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).channels(CHANNEL_CREATOR)

          const isChannelOwnerSubscribed_after = await EPNSCommV1Proxy.isUserSubscribed(CHANNEL_CREATOR, CHANNEL_CREATOR);
          const isChannelSubscribedToEPNS_after = await EPNSCommV1Proxy.isUserSubscribed(EPNS_ALERTER, CHANNEL_CREATOR);
          const isAdminSubscribedToChannel_after = await EPNSCommV1Proxy.isUserSubscribed(CHANNEL_CREATOR, ADMIN);

          await expect(isChannelOwnerSubscribed_before).to.equal(false);
          await expect(isChannelSubscribedToEPNS_before).to.equal(false);
          await expect(isAdminSubscribedToChannel_before).to.equal(false);
          await expect(isChannelOwnerSubscribed_after).to.equal(true);
          await expect(isChannelSubscribedToEPNS_after).to.equal(true);
          await expect(isAdminSubscribedToChannel_after).to.equal(true);

        }).timeout(10000);

        it("Function Should emit Relevant Events", async function(){
          const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_FEES,0);

          await expect(tx)
            .to.emit(EPNSCoreV1Proxy, 'AddChannel')
            .withArgs(CHANNEL_CREATOR, CHANNEL_TYPE, ethers.utils.hexlify(testChannel));
        });

    });

});
});