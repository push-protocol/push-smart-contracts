const { ethers, waffle } = require("hardhat");

const { bn, tokensBN } = require("../../../helpers/utils");

const { epnsContractFixture } = require("../../common/fixturesV2");
const { expect } = require("../../common/expect");
const createFixtureLoader = waffle.createFixtureLoader;

describe("EPNS Comm V2 Protocol", function () {
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
      EPNSCoreV1Proxy,
      EPNSCommV1Proxy,
      ROUTER,
      PushToken,
      EPNS_TOKEN_ADDRS,
    } = await loadFixture(epnsContractFixture));
  });

  describe("EPNS COMM: EIP 1271 & 712 Support", function () {
    const CHANNEL_TYPE = 2;
    const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

    const getDomainParameters = (chainId, verifyingContract) => {
      const EPNS_DOMAIN = {
        name: "EPNS COMM V1",
        chainId: chainId,
        verifyingContract: verifyingContract,
      };
      return [EPNS_DOMAIN];
    };

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
          testChannel,
          ADD_CHANNEL_MIN_POOL_CONTRIBUTION,
          0
        );
      });

      const type = {
        SendNotification: [
          { name: "channel", type: "address" },
          { name: "recipient", type: "address" },
          { name: "identity", type: "bytes" },
          { name: "nonce", type: "uint256" },
          { name: "expiry", type: "uint256" },
        ],
      };

      it("Allows to send channel notification with 712 sig", async function () {
        const chainId = await EPNSCommV1Proxy.chainID().then((e) =>
          e.toNumber()
        );
        const [EPNS_DOMAIN, _] = getDomainParameters(
          chainId,
          EPNSCommV1Proxy.address
        );

        const [channel, subscriber, expiry] = [
          CHANNEL_CREATOR,
          BOBSIGNER.address,
          Date.now() + 3600,
        ];

        const nonce = await EPNSCommV1Proxy.nonces(channel);
        const message = {
          channel: channel,
          recipient: subscriber,
          identity: testChannel,
          nonce: nonce,
          expiry: expiry,
        };

        const signature = await CHANNEL_CREATORSIGNER._signTypedData(
          EPNS_DOMAIN,
          type,
          message
        );
        const { v, r, s } = ethers.utils.splitSignature(signature);
        const tx = EPNSCommV1Proxy.sendNotifBySig(
          channel,
          subscriber,
          CHANNEL_CREATOR,
          testChannel,
          nonce,
          expiry,
          v,
          r,
          s
        );

        await expect(tx).to.emit(EPNSCommV1Proxy, "SendNotification");
      });

      it("Allows delegatee to send notification with sig", async function () {
        const chainId = await EPNSCommV1Proxy.chainID().then((e) =>
          e.toNumber()
        );
        const [EPNS_DOMAIN, _] = getDomainParameters(
          chainId,
          EPNSCommV1Proxy.address
        );

        // Alice is not delegattee nut tries to send notification
        const [channel, subscriber, expiry] = [
          CHANNEL_CREATOR,
          BOBSIGNER.address,
          Date.now() + 3600,
        ];
        const nonce = await EPNSCommV1Proxy.nonces(channel);
        const message = {
          channel: channel,
          recipient: subscriber,
          identity: testChannel,
          nonce: nonce,
          expiry: expiry,
        };
        const signature = await ALICESIGNER._signTypedData(
          EPNS_DOMAIN,
          type,
          message
        );
        const { v, r, s } = ethers.utils.splitSignature(signature);
        var tx = await EPNSCommV1Proxy.callStatic.sendNotifBySig(
          channel,
          subscriber,
          ALICE,
          testChannel,
          nonce,
          expiry,
          v,
          r,
          s
        );

        // Not notification sent
        expect(tx).to.be.false;

        // Now channel creator adds Alice as delegattee
        await EPNSCommV1Proxy.connect(CHANNEL_CREATORSIGNER).addDelegate(ALICE);
        
        // Again alice tries to send notification with sig
        var tx = await EPNSCommV1Proxy.callStatic.sendNotifBySig(
          channel,
          subscriber,
          ALICE,
          testChannel,
          nonce,
          expiry,
          v,
          r,
          s
        ); 
        expect(tx).to.be.true;
        
        // Actual txn emits notification
        var tx = await EPNSCommV1Proxy.sendNotifBySig(
          channel,
          subscriber,
          ALICE,
          testChannel,
          nonce,
          expiry,
          v,
          r,
          s
        ); 
        await expect(tx).to.emit(EPNSCommV1Proxy, "SendNotification");
      });

      it("Allow to send channel notification with 1271 sig", async function () {
        // mock verifier contract
        const VerifierContract = await ethers
          .getContractFactory("SignatureVerifier")
          .then((c) => c.deploy());
        const chainId = await EPNSCommV1Proxy.chainID().then((e) =>
          e.toNumber()
        );
        const [EPNS_DOMAIN] = getDomainParameters(
          chainId,
          EPNSCommV1Proxy.address
        );

        // use verifier contract as subscriber
        const [channel, subscriber, expiry] = [
          VerifierContract.address,
          BOBSIGNER.address,
          Date.now() + 3600,
        ];

        const nonce = await EPNSCommV1Proxy.nonces(channel);
        const message = {
          channel: channel,
          recipient: subscriber,
          identity: testChannel,
          nonce: nonce,
          expiry: expiry,
        };

        // ALICE is not owner of Verifier Contract
        // so, ALIC signature is invalid
        // invalid signature should fail
        const invalid_signature = await ALICESIGNER._signTypedData(
          EPNS_DOMAIN,
          type,
          message
        );
        var { v, r, s } = ethers.utils.splitSignature(invalid_signature);
        var tx = await EPNSCommV1Proxy.callStatic.sendNotifBySig(
          channel,
          subscriber,
          VerifierContract.address,
          testChannel,
          nonce,
          expiry,
          v,
          r,
          s
        );
        // Invalid txn yields false
        await expect(tx).to.be.false;

        // Admin signer is owner of Verifier Contract
        // so Admin signer signs on behalf of contract
        const valid_signature = await ADMINSIGNER._signTypedData(
          EPNS_DOMAIN,
          type,
          message
        );
        var { v, r, s } = ethers.utils.splitSignature(valid_signature);
        var tx = await EPNSCommV1Proxy.callStatic.sendNotifBySig(
          channel,
          subscriber,
          VerifierContract.address,
          testChannel,
          nonce,
          expiry,
          v,
          r,
          s
        );

        // valid sig yields true
        await expect(tx).to.be.true;

        var tx = await EPNSCommV1Proxy.sendNotifBySig(
          channel,
          subscriber,
          VerifierContract.address,
          testChannel,
          nonce,
          expiry,
          v,
          r,
          s
        );

        // actual txn emits event
        await expect(tx).to.emit(EPNSCommV1Proxy, "SendNotification");
      });

      it("Returns false on signature replay", async function () {
        const chainId = await EPNSCommV1Proxy.chainID().then((e) =>
          e.toNumber()
        );
        const [EPNS_DOMAIN, _] = getDomainParameters(
          chainId,
          EPNSCommV1Proxy.address
        );

        const [channel, subscriber, expiry] = [
          CHANNEL_CREATORSIGNER.address,
          BOBSIGNER.address,
          Date.now() + 3600,
        ];

        const nonce = await EPNSCommV1Proxy.nonces(subscriber);
        const message = {
          channel: channel,
          recipient: subscriber,
          identity: testChannel,
          nonce: nonce,
          expiry: expiry,
        };

        const signature = await CHANNEL_CREATORSIGNER._signTypedData(
          EPNS_DOMAIN,
          type,
          message
        );
        const { v, r, s } = ethers.utils.splitSignature(signature);
        const tx = EPNSCommV1Proxy.sendNotifBySig(
          channel,
          subscriber,
          CHANNEL_CREATOR,
          testChannel,
          nonce,
          expiry,
          v,
          r,
          s
        );
        await expect(tx).to.emit(EPNSCommV1Proxy, "SendNotification");

        // should return false
        var tx2 = await EPNSCommV1Proxy.callStatic.sendNotifBySig(
          channel,
          subscriber,
          CHANNEL_CREATOR,
          testChannel,
          nonce,
          expiry,
          v,
          r,
          s
        );
        expect(tx2).to.be.false;

        // should not emit any envy
        var tx2 = EPNSCommV1Proxy.sendNotifBySig(
          channel,
          subscriber,
          CHANNEL_CREATOR,
          testChannel,
          nonce,
          expiry,
          v,
          r,
          s
        );
        await expect(tx2).to.not.emit(EPNSCommV1Proxy, "SendNotification");
      });

      it("Returns false on signature expire", async function () {
        const chainId = await EPNSCommV1Proxy.chainID().then((e) =>
          e.toNumber()
        );
        const [EPNS_DOMAIN, _] = getDomainParameters(
          chainId,
          EPNSCommV1Proxy.address
        );

        const [channel, subscriber, expiry] = [
          CHANNEL_CREATORSIGNER.address,
          BOBSIGNER.address,
          3600,
        ];

        const nonce = await EPNSCommV1Proxy.nonces(subscriber);
        const message = {
          channel: channel,
          recipient: subscriber,
          identity: testChannel,
          nonce: nonce,
          expiry: expiry,
        };

        const signature = await CHANNEL_CREATORSIGNER._signTypedData(
          EPNS_DOMAIN,
          type,
          message
        );
        const { v, r, s } = ethers.utils.splitSignature(signature);

        // it should return false
        var tx = await EPNSCommV1Proxy.callStatic.sendNotifBySig(
          channel,
          subscriber,
          CHANNEL_CREATOR,
          testChannel,
          nonce,
          expiry,
          v,
          r,
          s
        );
        expect(tx).to.be.false;

        // it should not emit event
        var tx = EPNSCommV1Proxy.sendNotifBySig(
          channel,
          subscriber,
          CHANNEL_CREATOR,
          testChannel,
          nonce,
          expiry,
          v,
          r,
          s
        );
        await expect(tx).to.not.emit(EPNSCommV1Proxy, "SendNotification");
      });
    });
  });
});