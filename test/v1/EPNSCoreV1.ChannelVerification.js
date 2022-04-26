const { ethers } = require("hardhat");
const { use, expect } = require("chai");
const { solidity } = require("ethereum-waffle");

const {
  advanceBlockTo,
  latestBlock,
  advanceBlock,
  increase,
  increaseTo,
  latest,
} = require("../time");

const {
  calcChannelFairShare,
  calcSubscriberFairShare,
  getPubKey,
  bn,
  tokens,
  tokensBN,
  bnToInt,
  ChannelAction,
  readjustFairShareOfChannels,
  SubscriberAction,
  readjustFairShareOfSubscribers,
} = require("../../helpers/utils");

use(solidity);

describe("EPNSCoreV1 Channel Verification Tests", function () {

  const DAI = "0xf80A32A835F79D7787E8a8ee5721D0fEaFd78108";
  const ADAI = "0xcB1Fe6F440c49E9290c3eb7f158534c2dC374201";
  const WETH = "0xc778417E063141139Fce010982780140Aa0cD5Ab";
  const UNISWAP_ROUTER = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
  const AAVE_LENDING_POOL = "0x1c8756FD2B28e9426CDBDcC7E3c4d64fa9A54728";

  const CHAIN_NAME = 'ROPSTEN'; // MAINNET, MATIC etc.
  const referralCode = 0;
  const ADD_CHANNEL_MIN_POOL_CONTRIBUTION = tokensBN(50)
  const ADD_CHANNEL_MAX_POOL_CONTRIBUTION = tokensBN(250000 * 50)
  const DELEGATED_CONTRACT_FEES = ethers.utils.parseEther("0.1");
  const ADJUST_FOR_FLOAT = bn(10 ** 7)
  const delay = 0; // uint for the timelock delay

  const forkAddress = {
    address: "0xe2a6cf5f463df94147a0f0a302c879eb349cb2cd",
  };

  let EPNS;
  let GOVERNOR;
  let PROXYADMIN;
  let CORE_LOGIC;
  let COMMUNICATOR_LOGIC;
  let LOGICV2;
  let LOGICV3;
  let EPNSCoreProxy;
  let EPNSCoreV1Proxy;
  let EPNSCommV1Proxy;
  let TIMELOCK;
  let ADMIN;
  let MOCKDAI;
  let ADAICONTRACT;

  let admin;
  let alice;
  let bob;
  let charlie;
  let dolly;
  let electra;
  let fizz;
  let protocolOwner;


  const coder = new ethers.utils.AbiCoder();
  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.

  before(async function (){
    const MOCKDAITOKEN = await ethers.getContractFactory("MockDAI");
    MOCKDAI = MOCKDAITOKEN.attach(DAI);

    const ADAITOKENS = await ethers.getContractFactory("MockDAI");
    ADAICONTRACT = ADAITOKENS.attach(ADAI);
  });

  before(async function () {
    // Get the ContractFactory and Signers here.
    [
      adminSigner,
      aliceSigner,
      bobSigner,
      charlieSigner,
      dollySigner,
      electraSigner,
      fizzSigner,
      protocolOwnerSigner
    ] = await ethers.getSigners();

    admin = adminSigner;
    alice = aliceSigner;
    bob = bobSigner;
    charlie = charlieSigner;
    dolly = dollySigner;
    electra = electraSigner;
    fizz = fizzSigner;
    protocolOwner = protocolOwnerSigner;

    const EPNSTOKEN = await ethers.getContractFactory("EPNS");
    EPNS = await EPNSTOKEN.deploy(admin.address);

    const EPNSCore = await ethers.getContractFactory("EPNSCoreV1");
    CORE_LOGIC = await EPNSCore.deploy();

    const TimeLock = await ethers.getContractFactory("Timelock");
    TIMELOCK = await TimeLock.deploy(admin.address, delay);

    const proxyAdmin = await ethers.getContractFactory("EPNSCoreAdmin");
    PROXYADMIN = await proxyAdmin.deploy();
    //await PROXYADMIN.transferOwnership(TIMELOCK.address);

    const EPNSCommunicator = await ethers.getContractFactory("EPNSCommV1");
    COMMUNICATOR_LOGIC = await EPNSCommunicator.deploy();

    const EPNSCoreProxyContract = await ethers.getContractFactory("EPNSCoreProxy");
    EPNSCoreProxy = await EPNSCoreProxyContract.deploy(
      CORE_LOGIC.address,
      PROXYADMIN.address,
      admin.address,
      EPNS.address,
      WETH,
      UNISWAP_ROUTER,
      AAVE_LENDING_POOL,
      DAI,
      ADAI,
      referralCode,
    );

    const EPNSCommProxyContract = await ethers.getContractFactory("EPNSCommProxy");
    EPNSCommProxy = await EPNSCommProxyContract.deploy(
      COMMUNICATOR_LOGIC.address,
      PROXYADMIN.address,
      admin.address,
      CHAIN_NAME
    );

    EPNSCoreV1Proxy = EPNSCore.attach(EPNSCoreProxy.address)
    EPNSCommV1Proxy = EPNSCommunicator.attach(EPNSCommProxy.address)
  });

  after(function () {
    EPNS = null
    CORE_LOGIC = null
    TIMELOCK = null
    EPNSCoreProxy = null
    EPNSCoreV1Proxy = null
  });


  describe("Testing Channel Verifications", function() {
    before(async function(){
      const CHANNEL_TYPE = 2;

      const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");
      await EPNSCoreV1Proxy.connect(admin).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
      await EPNSCommV1Proxy.connect(admin).setEPNSCoreAddress(EPNSCoreV1Proxy.address);

      await EPNSCoreV1Proxy.connect(admin).createChannelForPushChannelAdmin();

      // CREATE BOB CHANNEL
      await MOCKDAI.connect(bob).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
      await MOCKDAI.connect(bob).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
      await EPNSCoreV1Proxy.connect(bob).createChannelWithFees(CHANNEL_TYPE, testChannel, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

      // CREATE CHARLIE CHANNEL
      await MOCKDAI.connect(charlie).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
      await MOCKDAI.connect(charlie).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
      await EPNSCoreV1Proxy.connect(charlie).createChannelWithFees(CHANNEL_TYPE, testChannel, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

      // CREATE DELTA CHANNEL
      await MOCKDAI.connect(dolly).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
      await MOCKDAI.connect(dolly).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
      await EPNSCoreV1Proxy.connect(dolly).createChannelWithFees(CHANNEL_TYPE, testChannel, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

      // CREATE ELECTRA
      await MOCKDAI.connect(electra).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
      await MOCKDAI.connect(electra).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
      await EPNSCoreV1Proxy.connect(electra).createChannelWithFees(CHANNEL_TYPE, testChannel, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

      // Create FIZZ CHANNEL
      await MOCKDAI.connect(fizz).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
      await MOCKDAI.connect(fizz).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
      await EPNSCoreV1Proxy.connect(fizz).createChannelWithFees(CHANNEL_TYPE, testChannel, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
    });

    afterEach(async function(){
      await EPNSCoreV1Proxy.unverifyChannel(bob.address);
      await EPNSCoreV1Proxy.unverifyChannel(charlie.address);
      await EPNSCoreV1Proxy.unverifyChannel(dolly.address);
      await EPNSCoreV1Proxy.unverifyChannel(electra.address);
      await EPNSCoreV1Proxy.unverifyChannel(fizz.address);
    });

    it("should return primary verification for channel creator", async function(){
      expect((await EPNSCoreV1Proxy.getChannelVerfication(admin.address))).to.equal(1);
    });

    it("should return primary verification for 0x0", async function(){
      expect((await EPNSCoreV1Proxy.getChannelVerfication("0x0000000000000000000000000000000000000000"))).to.equal(1);
    });

    it("should return not verified for unverified channels", async function(){
      expect((await EPNSCoreV1Proxy.getChannelVerfication(bob.address))).to.equal(0);
    });

    it("should return primary verified for channels verified by admin", async function(){
      await EPNSCoreV1Proxy.connect(admin).verifyChannel(bob.address);
      expect((await EPNSCoreV1Proxy.getChannelVerfication(bob.address))).to.equal(1);
    });

    it("should return secondary verified for channels for channel to channel verification", async function(){
      await EPNSCoreV1Proxy.connect(admin).verifyChannel(bob.address);
      await EPNSCoreV1Proxy.connect(bob).verifyChannel(charlie.address);
      expect((await EPNSCoreV1Proxy.getChannelVerfication(charlie.address))).to.equal(2);
    });

    it("should be able to upgrade secondary verified to primary", async function(){
      await EPNSCoreV1Proxy.connect(admin).verifyChannel(charlie.address);
      expect((await EPNSCoreV1Proxy.getChannelVerfication(charlie.address))).to.equal(1);
    });

    it("should not be able to verify a channel if itself unverified", async function(){
      await expect(EPNSCoreV1Proxy.connect(bob).verifyChannel(charlie.address))
        .to.be.revertedWith('EPNSCoreV1::verifyChannel: Caller is not verified')
    });

    it("should be able to unverify if from push channel owner", async function(){
      await EPNSCoreV1Proxy.connect(admin).verifyChannel(bob.address);
      expect((await EPNSCoreV1Proxy.getChannelVerfication(bob.address))).to.equal(1);

      await EPNSCoreV1Proxy.connect(admin).unverifyChannel(bob.address);
      expect((await EPNSCoreV1Proxy.getChannelVerfication(charlie.address))).to.equal(0);
    });

    it("should be able to unverify if from secondary ownership by that owner", async function(){
      await EPNSCoreV1Proxy.connect(admin).verifyChannel(bob.address);
      await EPNSCoreV1Proxy.connect(bob).verifyChannel(charlie.address);
      expect((await EPNSCoreV1Proxy.getChannelVerfication(charlie.address))).to.equal(2);

      await EPNSCoreV1Proxy.connect(bob).unverifyChannel(charlie.address);
      expect((await EPNSCoreV1Proxy.getChannelVerfication(charlie.address))).to.equal(0);
    });

    it("should be able to unverify if from secondary ownership by the push channel owner", async function(){
      await EPNSCoreV1Proxy.connect(admin).verifyChannel(bob.address);
      await EPNSCoreV1Proxy.connect(bob).verifyChannel(charlie.address);
      expect((await EPNSCoreV1Proxy.getChannelVerfication(charlie.address))).to.equal(2);

      await EPNSCoreV1Proxy.connect(admin).unverifyChannel(charlie.address);
      expect((await EPNSCoreV1Proxy.getChannelVerfication(charlie.address))).to.equal(0);
    });

    it("should not be able to unverify if not from that owner or push channel", async function(){
      await EPNSCoreV1Proxy.connect(admin).verifyChannel(bob.address);
      await EPNSCoreV1Proxy.connect(bob).verifyChannel(charlie.address);
      expect((await EPNSCoreV1Proxy.getChannelVerfication(charlie.address))).to.equal(2);

      await expect(EPNSCoreV1Proxy.connect(dolly).unverifyChannel(charlie.address))
        .to.be.revertedWith('EPNSCoreV1::unverifyChannel: Only channel who verified this or Push Channel Admin can revoke')
    });

    it("should not be able to downgrade primary verified to secondary", async function(){
      await EPNSCoreV1Proxy.connect(admin).verifyChannel(charlie.address);

      await EPNSCoreV1Proxy.connect(admin).verifyChannel(bob.address);
      await expect(EPNSCoreV1Proxy.connect(bob).verifyChannel(charlie.address))
        .to.be.revertedWith('EPNSCoreV1::verifyChannel: Channel already verified')
    });

    describe("Testing Propogation of Verification", function() {
      beforeEach(async function(){
        await EPNSCoreV1Proxy.connect(admin).verifyChannel(bob.address);
        await EPNSCoreV1Proxy.connect(admin).verifyChannel(charlie.address);

        await EPNSCoreV1Proxy.connect(bob).verifyChannel(dolly.address);
        await EPNSCoreV1Proxy.connect(bob).verifyChannel(electra.address);

        await EPNSCoreV1Proxy.connect(electra).verifyChannel(fizz.address);
      });

      it("should be able to propogate correctly", async function(){
        expect((await EPNSCoreV1Proxy.getChannelVerfication(bob.address))).to.equal(1);
        expect((await EPNSCoreV1Proxy.getChannelVerfication(charlie.address))).to.equal(1);
        expect((await EPNSCoreV1Proxy.getChannelVerfication(dolly.address))).to.equal(2);
        expect((await EPNSCoreV1Proxy.getChannelVerfication(electra.address))).to.equal(2);
        expect((await EPNSCoreV1Proxy.getChannelVerfication(fizz.address))).to.equal(2);
      });

      it("should be able to unverify by assignor", async function(){
        await EPNSCoreV1Proxy.connect(electra).unverifyChannel(fizz.address);
        expect((await EPNSCoreV1Proxy.getChannelVerfication(fizz.address))).to.equal(0);

        await EPNSCoreV1Proxy.connect(bob).unverifyChannel(electra.address);
        expect((await EPNSCoreV1Proxy.getChannelVerfication(electra.address))).to.equal(0);

        await EPNSCoreV1Proxy.connect(bob).unverifyChannel(dolly.address);
        expect((await EPNSCoreV1Proxy.getChannelVerfication(dolly.address))).to.equal(0);

        await EPNSCoreV1Proxy.connect(admin).unverifyChannel(bob.address);
        expect((await EPNSCoreV1Proxy.getChannelVerfication(bob.address))).to.equal(0);
      });

      it("should be able to unverify from mid by push channel admin", async function(){
        await EPNSCoreV1Proxy.connect(admin).unverifyChannel(bob.address);

        expect((await EPNSCoreV1Proxy.getChannelVerfication(bob.address))).to.equal(0);
        expect((await EPNSCoreV1Proxy.getChannelVerfication(dolly.address))).to.equal(0);
        expect((await EPNSCoreV1Proxy.getChannelVerfication(electra.address))).to.equal(0);
        expect((await EPNSCoreV1Proxy.getChannelVerfication(fizz.address))).to.equal(0);
      });

      it("should be able to unverify from mid by secondary channel", async function(){
        await EPNSCoreV1Proxy.connect(bob).unverifyChannel(electra.address);
        expect((await EPNSCoreV1Proxy.getChannelVerfication(dolly.address))).to.equal(2);

        expect((await EPNSCoreV1Proxy.getChannelVerfication(electra.address))).to.equal(0);
        expect((await EPNSCoreV1Proxy.getChannelVerfication(fizz.address))).to.equal(0);
      });

      afterEach(async function(){
        await EPNSCoreV1Proxy.connect(admin).unverifyChannel(bob.address);
        await EPNSCoreV1Proxy.connect(admin).unverifyChannel(charlie.address);
        await EPNSCoreV1Proxy.connect(admin).unverifyChannel(dolly.address);
        await EPNSCoreV1Proxy.connect(admin).unverifyChannel(electra.address);
        await EPNSCoreV1Proxy.connect(admin).unverifyChannel(fizz.address);
      });
    });

    describe("Testing Batch Channel Verification & Unverification", function() {

    it("Only Admin should be able to execute Batch Verification", async function(){
        const _startIndex = 0;
        const _endIndex = 4;
        const channelArray = [bob.address, charlie.address, dolly.address, electra.address];
        const tx = EPNSCoreV1Proxy.connect(bob).batchVerification(_startIndex, _endIndex, channelArray);
        await expect(tx).to.be.revertedWith("EPNSCoreV1::onlyPushChannelAdmin: Caller not pushChannelAdmin");
     });

    it("Only Admin should be able to execute Batch Revoke Verification", async function(){
         const _startIndex = 0;
         const _endIndex = 4;
         const channelArray = [bob.address, charlie.address, dolly.address, electra.address];
         const tx = EPNSCoreV1Proxy.connect(bob).batchRevokeVerification(_startIndex, _endIndex, channelArray);
         await expect(tx).to.be.revertedWith("EPNSCoreV1::onlyPushChannelAdmin: Caller not pushChannelAdmin");
    });

    it("Admin should be able to verify a Batch of Channels", async function(){
        const _startIndex = 0;
        const _endIndex = 4;
         const channelArray = [bob.address, charlie.address, dolly.address, electra.address];

         await EPNSCoreV1Proxy.connect(admin).batchVerification(_startIndex, _endIndex, channelArray);
         expect((await EPNSCoreV1Proxy.getChannelVerfication(bob.address))).to.equal(1);
         expect((await EPNSCoreV1Proxy.getChannelVerfication(charlie.address))).to.equal(1);
         expect((await EPNSCoreV1Proxy.getChannelVerfication(dolly.address))).to.equal(1);
         expect((await EPNSCoreV1Proxy.getChannelVerfication(electra.address))).to.equal(1);
    });

    it("Admin should be able to Revoke Verification of a Batch of Channels", async function(){
          const _startIndex = 0;
          const _endIndex = 4;
         const channelArray = [bob.address, charlie.address, dolly.address, electra.address];
         await EPNSCoreV1Proxy.connect(admin).batchVerification(_startIndex, _endIndex, channelArray);

         const bob_Verification_before = await EPNSCoreV1Proxy.getChannelVerfication(bob.address);
         const charlie_Verification_before = await EPNSCoreV1Proxy.getChannelVerfication(charlie.address);
         const dolly_Verification_before = await EPNSCoreV1Proxy.getChannelVerfication(dolly.address);
         const electra_Verification_before = await EPNSCoreV1Proxy.getChannelVerfication(electra.address);

         await EPNSCoreV1Proxy.connect(admin).batchRevokeVerification(_startIndex, _endIndex, channelArray);

         await expect(bob_Verification_before).to.be.equal(1);
         await expect(charlie_Verification_before).to.be.equal(1);
         await expect(dolly_Verification_before).to.be.equal(1);
         await expect(electra_Verification_before).to.be.equal(1);
         expect((await EPNSCoreV1Proxy.getChannelVerfication(bob.address))).to.equal(0);
         expect((await EPNSCoreV1Proxy.getChannelVerfication(charlie.address))).to.equal(0);
         expect((await EPNSCoreV1Proxy.getChannelVerfication(dolly.address))).to.equal(0);
         expect((await EPNSCoreV1Proxy.getChannelVerfication(electra.address))).to.equal(0);
  });
   });


  });
});
