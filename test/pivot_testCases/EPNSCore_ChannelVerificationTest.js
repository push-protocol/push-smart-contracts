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

describe("EPNS Core Protocol Tests Channel tests", function () {
  const AAVE_LENDING_POOL = "0x1c8756FD2B28e9426CDBDcC7E3c4d64fa9A54728";
  const DAI = "0xf80A32A835F79D7787E8a8ee5721D0fEaFd78108";
  const ADAI = "0xcB1Fe6F440c49E9290c3eb7f158534c2dC374201";
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
  let EPNSCommunicatorV1Proxy;
  let TIMELOCK;
  let ADMIN;
  let MOCKDAI;
  let ADAICONTRACT;
  let ALICE;
  let BOB;
  let CHARLIE;
  let CHANNEL_CREATOR;
  let ADMINSIGNER;
  let ALICESIGNER;
  let BOBSIGNER;
  let CHARLIESIGNER;
  let CHANNEL_CREATORSIGNER;
  const ADMIN_OVERRIDE = "";

  const coder = new ethers.utils.AbiCoder();
  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.

  before(async function (){
    const MOCKDAITOKEN = await ethers.getContractFactory("MockDAI");
    MOCKDAI = MOCKDAITOKEN.attach(DAI);

    const ADAITOKENS = await ethers.getContractFactory("MockDAI");
    ADAICONTRACT = ADAITOKENS.attach(ADAI);
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

    const EPNSTOKEN = await ethers.getContractFactory("EPNS");
    EPNS = await EPNSTOKEN.deploy(ADMIN);

    const EPNSCore = await ethers.getContractFactory("EPNSCore");
    CORE_LOGIC = await EPNSCore.deploy();

    const TimeLock = await ethers.getContractFactory("Timelock");
    TIMELOCK = await TimeLock.deploy(ADMIN, delay);

    const proxyAdmin = await ethers.getContractFactory("EPNSAdmin");
    PROXYADMIN = await proxyAdmin.deploy();
    await PROXYADMIN.transferOwnership(TIMELOCK.address);

    const EPNSCommunicator = await ethers.getContractFactory("EPNSCommunicator");
    COMMUNICATOR_LOGIC = await EPNSCommunicator.deploy();

    const EPNSCoreProxyContract = await ethers.getContractFactory("EPNSCoreProxy");
    EPNSCoreProxy = await EPNSCoreProxyContract.deploy(
      CORE_LOGIC.address,
      ADMINSIGNER.address,
      AAVE_LENDING_POOL,
      DAI,
      ADAI,
      referralCode,
    );

    await EPNSCoreProxy.changeAdmin(ALICESIGNER.address);
    EPNSCoreV1Proxy = EPNSCore.attach(EPNSCoreProxy.address)

    const EPNSCommProxyContract = await ethers.getContractFactory("EPNSCommunicatorProxy");
    EPNSCommProxy = await EPNSCommProxyContract.deploy(
      COMMUNICATOR_LOGIC.address,
      ADMINSIGNER.address
    );

    await EPNSCommProxy.changeAdmin(ALICESIGNER.address);
    EPNSCommunicatorV1Proxy = EPNSCommunicator.attach(EPNSCommProxy.address)

  });

  afterEach(function () { 
    EPNS = null
    CORE_LOGIC = null
    TIMELOCK = null
    EPNSCoreProxy = null
    EPNSCoreV1Proxy = null
  });


  describe("Testing Channel Verification Functions for Admin", function()
    {
         beforeEach(async function(){
          const CHANNEL_TYPE = 2;
          const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommunicatorV1Proxy.address)
          await EPNSCommunicatorV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
          await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          await MOCKDAI.connect(CHARLIESIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          await MOCKDAI.connect(CHARLIESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          await EPNSCoreV1Proxy.connect(CHARLIESIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
       });
 

    /**
     * "verifyChannelViaAdmin" Function CHECKPOINTS
     *
     * REVERT CHECKS
     * Should revert if Caller is not ADMIN
     * Should revert if Channel is Not ACTIVATED
     * Should revert if CHANNEL IS Already Verified
     * 
     * FUNCTION Execution CHECKS
     * "isChannelVerified" flag should be assigned to 1 
     * "verifiedViaAdminRecords" mapping should be updated accordingly 
     * "channelVerifiedBy" mapping should be updated with Verifier address
     * "verifiedChannelCount" should increase for the Verifier
     * Should emit relevant Events
     **/

    
      it("Function should revert if Caller is Not Admin", async function(){
        const tx = EPNSCoreV1Proxy.connect(BOBSIGNER).verifyChannelViaAdmin(CHANNEL_CREATOR);

        await expect(tx).to.be.revertedWith('EPNSCore::onlyAdmin, user is not admin');
      });

      it("Function should revert if Channel is Not ACTIVATED", async function(){
        const tx = EPNSCoreV1Proxy.connect(ADMINSIGNER).verifyChannelViaAdmin(BOB);

        await expect(tx).to.be.revertedWith("Channel Deactivated, Blocked or Doesn't Exist")
      });

      it("Function should revert if CHANNEL IS Already Verified", async function(){
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).verifyChannelViaAdmin(CHANNEL_CREATOR);

        const tx = EPNSCoreV1Proxy.connect(ADMINSIGNER).verifyChannelViaAdmin(CHANNEL_CREATOR);

        await expect(tx).to.be.revertedWith("Channel is Already Verified")
      });

      it("Function should Execute adequately and Update State variables accordingly", async function(){
        const verifiedRecordsArray_before = await EPNSCoreV1Proxy.getAllVerifiedChannel(ADMIN);

        await EPNSCoreV1Proxy.connect(ADMINSIGNER).verifyChannelViaAdmin(CHANNEL_CREATOR);
        
        const channel = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR)
        const verifiedBy = await EPNSCoreV1Proxy.channelVerifiedBy(CHANNEL_CREATOR);
        const channelVerificationCount = await EPNSCoreV1Proxy.verifiedChannelCount(ADMIN);
        const verifiedRecordsArray_after = await EPNSCoreV1Proxy.getAllVerifiedChannel(ADMIN);

        const isRecordAvailable_before = verifiedRecordsArray_before.includes(CHANNEL_CREATOR)
        const isRecordAvailable_after = verifiedRecordsArray_after.includes(CHANNEL_CREATOR)

        await expect(verifiedBy).to.equal(ADMIN);
        await expect(channel.isChannelVerified).to.equal(1);
        await expect(channelVerificationCount).to.equal(1);
        await expect(isRecordAvailable_before).to.equal(false)
        await expect(isRecordAvailable_after).to.equal(true);
      });

      it("Function Should emit Relevant Events", async function(){
        const tx = EPNSCoreV1Proxy.connect(ADMINSIGNER).verifyChannelViaAdmin(CHANNEL_CREATOR);

        await expect(tx)
          .to.emit(EPNSCoreV1Proxy, 'ChannelVerified')
          .withArgs(CHANNEL_CREATOR, ADMIN);
      });

  });

  describe("Testing Channel Verification Function for Channel Owners", function()
    {
         beforeEach(async function(){
          const CHANNEL_TYPE = 2;
          const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommunicatorV1Proxy.address)
          await EPNSCommunicatorV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
          await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          await MOCKDAI.connect(CHARLIESIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          await MOCKDAI.connect(CHARLIESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          await EPNSCoreV1Proxy.connect(CHARLIESIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
       });
 
    /**
     * "verifyChannelViaChannelOwners" Function CHECKPOINTS
     *
     * REVERT CHECKS
     * Should revert if Caller is not Admin Verified Channel Owners
     * Should revert if Channel is Not ACTIVATED
     * Should revert if CHANNEL IS Already Verified
     * 
     * FUNCTION Execution CHECKS
     * "isChannelVerified" flag should be assigned to "2" if Verifier is CHANNEL OWNERS
     * "verifiedViaAdminRecords" mapping should be updated accordingly is CHANNEL OWNERS
     * "channelVerifiedBy" mapping should be updated with Verifier address
     * "verifiedChannelCount" should increase for the Verifier
     * Should emit relevant Events
     **/
    
      it("Function should revert if Caller is Not Channel Owners", async function(){
        const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).verifyChannelViaChannelOwners(CHARLIE);

        await expect(tx).to.be.revertedWith('Channel is NOT Verified By ADMIN');
      });

      it("Function should revert if Channel is Not ACTIVATED", async function(){
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).verifyChannelViaAdmin(CHANNEL_CREATOR);
        const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).verifyChannelViaChannelOwners(BOB);

        await expect(tx).to.be.revertedWith("Channel Deactivated, Blocked or Doesn't Exist")
      });

      it("Function should revert if CHANNEL IS Already Verified", async function(){
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).verifyChannelViaAdmin(CHANNEL_CREATOR);

        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).verifyChannelViaChannelOwners(CHARLIE);

        const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).verifyChannelViaChannelOwners(CHARLIE);

        await expect(tx).to.be.revertedWith("Channel is Already Verified")
      });

      // it("Function should Execute adequately and Update State variables accordingly", async function(){
      //   await EPNSCoreV1Proxy.connect(ADMINSIGNER).verifyChannelViaAdmin(CHANNEL_CREATOR);
      //   const verifiedRecordsArray_before = await EPNSCoreV1Proxy.getAllVerifiedChannel(ADMIN);

      //   await EPNSCoreV1Proxy.connect(ADMINSIGNER).verifyChannelViaChannelOwners(CHANNEL_CREATOR);
        
      //   const channel = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR)
      //   const verifiedBy = await EPNSCoreV1Proxy.channelVerifiedBy(CHANNEL_CREATOR);
      //   const channelVerificationCount = await EPNSCoreV1Proxy.verifiedChannelCount(ADMIN);
      //   const verifiedRecordsArray_after = await EPNSCoreV1Proxy.getAllVerifiedChannel(ADMIN);

      //   const isRecordAvailable_before = verifiedRecordsArray_before.includes(CHANNEL_CREATOR)
      //   const isRecordAvailable_after = verifiedRecordsArray_after.includes(CHANNEL_CREATOR)

      //   await expect(verifiedBy).to.equal(ADMIN);
      //   await expect(channel.isChannelVerified).to.equal(1);
      //   await expect(channelVerificationCount).to.equal(1);
      //   await expect(isRecordAvailable_before).to.equal(false)
      //   await expect(isRecordAvailable_after).to.equal(true);
      // });

      // it("Function Should emit Relevant Events", async function(){
      //   await EPNSCoreV1Proxy.connect(ADMINSIGNER).verifyChannelViaAdmin(CHANNEL_CREATOR);
      //   const tx = EPNSCoreV1Proxy.connect(ADMINSIGNER).verifyChannelViaChannelOwners(CHANNEL_CREATOR);

      //   await expect(tx)
      //     .to.emit(EPNSCoreV1Proxy, 'ChannelVerified')
      //     .withArgs(CHANNEL_CREATOR, ADMIN);
      // });

  });



});

