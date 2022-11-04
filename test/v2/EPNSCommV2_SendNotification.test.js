const { ethers, waffle } = require("hardhat");

const { bn, tokensBN } = require("../../helpers/utils");

const { epnsContractFixture, tokenFixture } = require("../common/fixtures");
const { expect } = require("../common/expect");
const createFixtureLoader = waffle.createFixtureLoader;

describe("EPNS CoreV2 Protocol", function () {
  const ADD_CHANNEL_MIN_POOL_CONTRIBUTION = tokensBN(50);

  let PushToken;
  let EPNSCoreV1Proxy;
  let EPNSCommV1Proxy;
  let ALICE;
  let BOB;
  let CHANNEL_CREATOR;
  let ADMINSIGNER;
  let ALICESIGNER;
  let BOBSIGNER;
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

    ({
      PROXYADMIN,
      EPNSCoreV1Proxy,
      EPNSCommV1Proxy,
      ROUTER,
      PushToken,
      EPNS_TOKEN_ADDRS,
    } = await loadFixture(epnsContractFixture));

    ({ MOCKDAI, ADAI } = await loadFixture(tokenFixture));
  });

  describe("EPNS COMM: EIP 1271 & 712 Support", function () {
    const CHANNEL_TYPE = 2;
    const msg = ethers.utils.toUtf8Bytes("test-channel-hello-world");

    describe("Send Notification Tests", function () {
      beforeEach(async function () {
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(
          EPNSCommV1Proxy.address
        );
        await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(
          EPNSCoreV1Proxy.address
        );
        await PushToken.transfer(BOB, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await PushToken.transfer(ALICE, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await PushToken.transfer(
          CHANNEL_CREATOR,
          ADD_CHANNEL_MIN_POOL_CONTRIBUTION
        );
        await PushToken.connect(BOBSIGNER).approve(
          EPNSCoreV1Proxy.address,
          ADD_CHANNEL_MIN_POOL_CONTRIBUTION
        );
        await PushToken.connect(ALICESIGNER).approve(
          EPNSCoreV1Proxy.address,
          ADD_CHANNEL_MIN_POOL_CONTRIBUTION
        );
        await PushToken.connect(CHANNEL_CREATORSIGNER).approve(
          EPNSCoreV1Proxy.address,
          ADD_CHANNEL_MIN_POOL_CONTRIBUTION
        );

        // create a channel
        await EPNSCoreV1Proxy.connect(
          CHANNEL_CREATORSIGNER
        ).createChannelWithPUSH(
          CHANNEL_TYPE,
          msg,
          ADD_CHANNEL_MIN_POOL_CONTRIBUTION,
          0
        );
      });

      it("Should return false if a User is sending Notif to Other Address Instead of themselves", async function () {
        var tx = await EPNSCommV1Proxy.connect(
          BOBSIGNER
        ).callStatic.sendNotification(CHANNEL_CREATOR, CHARLIE, msg);
        expect(tx).to.be.false;

        var tx = await EPNSCommV1Proxy.connect(BOBSIGNER).sendNotification(
          CHANNEL_CREATOR,
          CHARLIE,
          msg
        );

        await expect(tx).to.not.emit(EPNSCommV1Proxy, "SendNotification");
      });

      it("Should Emit Event if Recipient is Sending NOTIF Only to HIMself/Herself", async function () {
        var tx = await EPNSCommV1Proxy.connect(
          BOBSIGNER
        ).callStatic.sendNotification(CHANNEL_CREATOR, BOB, msg);
        expect(tx).to.be.true;

        var tx = await EPNSCommV1Proxy.connect(BOBSIGNER).sendNotification(
          CHANNEL_CREATOR,
          BOB,
          msg
        );
        await expect(tx)
          .to.emit(EPNSCommV1Proxy, "SendNotification")
          .withArgs(CHANNEL_CREATOR, BOB, ethers.utils.hexlify(msg));
      });

      it("Should return false if Channel is 0x00.. But Caller is any address other than Admin/Governance", async function(){
        const EPNS_ALERTER_CHANNEL = '0x0000000000000000000000000000000000000000';
        var tx = await EPNSCommV1Proxy.connect(BOBSIGNER).callStatic.sendNotification(EPNS_ALERTER_CHANNEL, CHARLIE, msg);
        expect(tx).to.be.false;

        var tx = await EPNSCommV1Proxy.connect(BOBSIGNER).sendNotification(EPNS_ALERTER_CHANNEL, CHARLIE, msg);
        await expect(tx).to.not.emit(EPNSCommV1Proxy, "SendNotification");
      });

      it("Should Emit Event if Channel is 0x00.. and Caller is Admin/Governance", async function(){
        const EPNS_ALERTER_CHANNEL = '0x0000000000000000000000000000000000000000';
        var txn = await EPNSCommV1Proxy.connect(ADMINSIGNER).callStatic.sendNotification(EPNS_ALERTER_CHANNEL, CHARLIE, msg);
        expect(txn).to.be.true;

        var txn = await EPNSCommV1Proxy.connect(ADMINSIGNER).sendNotification(EPNS_ALERTER_CHANNEL, CHARLIE, msg);
        await expect(txn)
             .to.emit(EPNSCommV1Proxy, 'SendNotification')
             .withArgs(EPNS_ALERTER_CHANNEL, CHARLIE, ethers.utils.hexlify(msg));
      });

      it("Should return false if Delegate without send notification without Approval", async function(){
        var tx = await EPNSCommV1Proxy.connect(CHARLIESIGNER).callStatic.sendNotification(CHANNEL_CREATOR, BOB, msg);
        expect(tx).to.be.false;

        var tx = await EPNSCommV1Proxy.connect(CHARLIESIGNER).sendNotification(CHANNEL_CREATOR, BOB, msg);
        await expect(tx).to.not.emit(EPNSCommV1Proxy, "SendNotification");
      });

      it("Should Emit Event Allowed Delagtes Sends Notification to any Recipient", async function(){
        const isCharlieAllowed_before = await EPNSCommV1Proxy.connect(CHANNEL_CREATORSIGNER).delegatedNotificationSenders(CHANNEL_CREATOR, CHARLIE);
        await EPNSCommV1Proxy.connect(CHANNEL_CREATORSIGNER).addDelegate(CHARLIE);
        const isCharlieAllowed_after = await EPNSCommV1Proxy.connect(CHANNEL_CREATORSIGNER).delegatedNotificationSenders(CHANNEL_CREATOR, CHARLIE);

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
