const { ethers,waffle} = require("hardhat");
const {epnsContractFixture,tokenFixture} = require("../common/fixtures")
const {expect} = require("../common/expect")
const createFixtureLoader = waffle.createFixtureLoader;

const {
  tokensBN,
} = require("../../helpers/utils");

describe("EPNS CommV2 Protocol", function () {
  const FEE_AMOUNT = tokensBN(10)
  const ADJUST_FOR_FLOAT = bn(10 ** 7)
  const MIN_POOL_CONTRIBUTION = tokensBN(1)
  const ADD_CHANNEL_MIN_FEES = tokensBN(50)
  const ADD_CHANNEL_MAX_POOL_CONTRIBUTION = tokensBN(250000 * 50)

  let EPNSCoreV1Proxy;
  let EPNSCommV1Proxy;
  let ALICE;
  let BOB;
  let ADMINSIGNER;
  let ALICESIGNER;
  let BOBSIGNER;


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
    describe("Testing send Notification related functions", function(){

        describe("Testing Advance Subset SendNotif", function(){
          /**
            * 'sendNotificationAdvanced' function CheckPoints
            * Should revert if a User is trying to send Notif to another instead of themselves as recipient.
            * Should revert if Channel is '0x000..' but caller is any address other than Admin/Governance
            * Should revert if Delegated Notification sender is not allowed by Channel Owner.
            * Should emit event if User is sending Notif to themselves
            * Should emit event if Delegate Notif Sender is Valid
            * Should emit Event with correct parameters if Recipient is Single Address or Channel Address
            * Should emit event with correct parameters if Recipient is a Subset of Recipient
          **/
              const CHANNEL_TYPE = 2;
              const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");


               beforeEach(async function(){
                await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
                await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
                await PushToken.transfer(BOB, ADD_CHANNEL_MIN_FEES.mul(20));
                await PushToken.transfer(ALICE, ADD_CHANNEL_MIN_FEES.mul(20));
                await PushToken.connect(BOBSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_FEES.mul(20));
                await PushToken.connect(ALICESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_FEES.mul(20));

                await EPNSCoreV1Proxy.connect(BOBSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel, ADD_CHANNEL_MIN_FEES,0);
                await EPNSCoreV1Proxy.connect(ALICESIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel, ADD_CHANNEL_MIN_FEES,0);
             });
          it("Should Not Emit Notification Event if a User is sending Notif to Other Address Instead of themselves", async function(){
            const msg = ethers.utils.toUtf8Bytes("This is notification message");
            const tx = EPNSCommV1Proxy.connect(BOBSIGNER).sendNotification(CHANNEL_CREATOR, CHARLIE, msg);
            await expect(tx)
                 .not.to.emit(EPNSCommV1Proxy, 'SendNotification')
                 .withArgs(BOBSIGNER, CHARLIE, ethers.utils.hexlify(msg));
          });

          it("Should Emit Event if Recipient is Sending NOTIF Only to HIMself/Herself", async function(){
            const msg = ethers.utils.toUtf8Bytes("This is notification message");
            const tx_sendNotif = EPNSCommV1Proxy.connect(BOBSIGNER).sendNotification(CHANNEL_CREATOR, BOB, msg);
            await expect(tx_sendNotif)
                 .to.emit(EPNSCommV1Proxy, 'SendNotification')
                 .withArgs(CHANNEL_CREATOR, BOB, ethers.utils.hexlify(msg));
          });

          it("Should Not Emit Notification Event if Channel is 0x0, But Caller is any address other than Admin/Governance", async function(){
            const EPNS_ALERTER_CHANNEL = '0x0000000000000000000000000000000000000000';
            const msg = ethers.utils.toUtf8Bytes("This is notification message");
            const tx = EPNSCommV1Proxy.connect(BOBSIGNER).sendNotification(EPNS_ALERTER_CHANNEL, CHARLIE, msg);
            await expect(tx)
                 .not.to.emit(EPNSCommV1Proxy, 'SendNotification')
                 .withArgs(BOBSIGNER, CHARLIE, ethers.utils.hexlify(msg));
          });

          it("Should Emit Event if Channel is 0x00.. and Caller is Admin/Governance", async function(){
            const EPNS_ALERTER_CHANNEL = '0x0000000000000000000000000000000000000000';
            const msg = ethers.utils.toUtf8Bytes("This is notification message");
            const tx_sendNotif = EPNSCommV1Proxy.connect(ADMINSIGNER).sendNotification(EPNS_ALERTER_CHANNEL, CHARLIE, msg);
            await expect(tx_sendNotif)
                 .to.emit(EPNSCommV1Proxy, 'SendNotification')
                 .withArgs(EPNS_ALERTER_CHANNEL, CHARLIE, ethers.utils.hexlify(msg));
          });

          it("Should Not Emit Notification Event if Delegate without send notification without Approval", async function(){
            const msg = ethers.utils.toUtf8Bytes("This is notification message");
            const tx = EPNSCommV1Proxy.connect(CHARLIESIGNER).sendNotification(CHANNEL_CREATOR, BOB, msg);
            await expect(tx)
                 .not.to.emit(EPNSCommV1Proxy, 'SendNotification')
                 .withArgs(CHARLIESIGNER, BOB, ethers.utils.hexlify(msg));
          });

          it("Should Emit Event Allowed Delagtes Sends Notification to any Recipient", async function(){
            const isCharlieAllowed_before = await EPNSCommV1Proxy.connect(CHANNEL_CREATORSIGNER).delegatedNotificationSenders(CHANNEL_CREATOR, CHARLIE);
            await EPNSCommV1Proxy.connect(CHANNEL_CREATORSIGNER).addDelegate(CHARLIE);
            const isCharlieAllowed_after = await EPNSCommV1Proxy.connect(CHANNEL_CREATORSIGNER).delegatedNotificationSenders(CHANNEL_CREATOR, CHARLIE);

            const msg = ethers.utils.toUtf8Bytes("This is notification message");
            const tx_sendNotif = EPNSCommV1Proxy.connect(CHARLIESIGNER).sendNotification(CHANNEL_CREATOR, BOB, msg);

            await expect(isCharlieAllowed_before).to.equal(false);
            await expect(isCharlieAllowed_after).to.equal(true);
            await expect(tx_sendNotif)
                 .to.emit(EPNSCommV1Proxy, 'SendNotification')
                 .withArgs(CHANNEL_CREATOR, BOB, ethers.utils.hexlify(msg));
          });
        });


    });

});
});