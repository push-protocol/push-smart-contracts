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
const { calcChannelFairShare, calcSubscriberFairShare, getPubKey, bn, tokens, tokensBN, bnToInt, ChannelAction, readjustFairShareOfChannels, SubscriberAction, readjustFairShareOfSubscribers } = require("../../helpers/utils");

use(solidity);

describe("EPNSCoreV1 Channel tests", function () {
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
  let LOGIC;
  let LOGICV2;
  let LOGICV3;
  let EPNSProxy;
  let EPNSCoreV1Proxy;
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
    EPNS = await EPNSTOKEN.deploy();

    const EPNSCoreV1 = await ethers.getContractFactory("EPNSCoreV1");
    LOGIC = await EPNSCoreV1.deploy();

    const TimeLock = await ethers.getContractFactory("Timelock");
    TIMELOCK = await TimeLock.deploy(ADMIN, delay);

    const proxyAdmin = await ethers.getContractFactory("EPNSAdmin");
    PROXYADMIN = await proxyAdmin.deploy();
    await PROXYADMIN.transferOwnership(TIMELOCK.address);

    const EPNSPROXYContract = await ethers.getContractFactory("EPNSProxy");
    EPNSProxy = await EPNSPROXYContract.deploy(
      LOGIC.address,
      ADMINSIGNER.address,
      AAVE_LENDING_POOL,
      DAI,
      ADAI,
      referralCode
    );

    await EPNSProxy.changeAdmin(ALICESIGNER.address);
    EPNSCoreV1Proxy = EPNSCoreV1.attach(EPNSProxy.address)
  });

  afterEach(function () {
    EPNS = null
    LOGIC = null
    TIMELOCK = null
    EPNSProxy = null
    EPNSCoreV1Proxy = null
  });

 
 describe("Testing Notification Settings for CHANNELS and USERS", function(){
      /**
     * "createChannelNotificationSettings" Function CHECKPOINTS
     * Should revert if User is NOT a SUBSCRIBER Of the Channel
     * Should update the "userToChannelNotifs" mapping with the right DATA
     * Should emit out the Imperative EVENTS;
     **/

    describe("Testing the Notification Settings function for USERS", function()
      { 
        const CHANNEL_TYPE = 2;
        const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");
        const user_notifSettings = "1-1+2-40+3-0+4-98";
    
        beforeEach(async function(){
      
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(DELEGATED_CONTRACT_FEES);
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, DELEGATED_CONTRACT_FEES);
       });

        it("Should revert if User is NOT a SUBSCRIBER Of the Channel", async function () {
          const CHANNEL_TYPE = 2;
          const notif_Id = 3;
          const userDetails = await EPNSCoreV1Proxy.users(BOB);
          const tx =  EPNSCoreV1Proxy.connect(BOBSIGNER).subscribeToSpecificNotification(CHANNEL_CREATOR,notif_Id,user_notifSettings);
          expect(userDetails.userActivated).to.be.equal(false);
          await expect(tx).to.be.revertedWith("Subscriber doesn't Exists")
        });

        it("Should update the userToChannelNotifs mapping with the right DATA", async function () {
          const CHANNEL_TYPE = 2;
          const notif_Id = 3;
          const notifSettings_final = "3+1-1+2-40+3-0+4-98";
          const userDetails_before = await EPNSCoreV1Proxy.users(BOB);
          await EPNSCoreV1Proxy.connect(BOBSIGNER).subscribe(CHANNEL_CREATOR);
          const userDetails_after = await EPNSCoreV1Proxy.users(BOB);

          await EPNSCoreV1Proxy.connect(BOBSIGNER).subscribeToSpecificNotification(CHANNEL_CREATOR,notif_Id,user_notifSettings);
          const userNotifMapping = await EPNSCoreV1Proxy.userToChannelNotifs(BOB,CHANNEL_CREATOR);

          expect(userNotifMapping).to.be.equal(notifSettings_final)
          expect(userDetails_before.userActivated).to.be.equal(false);
          expect(userDetails_after.userActivated).to.be.equal(true);
        });

         it("Should Emit out the EVENTS with the right Parameters", async function (){
          const CHANNEL_TYPE = 2;
          const notif_Id = 3;
          await EPNSCoreV1Proxy.connect(BOBSIGNER).subscribe(CHANNEL_CREATOR);
          const tx =  EPNSCoreV1Proxy.connect(BOBSIGNER).subscribeToSpecificNotification(CHANNEL_CREATOR,notif_Id,user_notifSettings);
          const userNotifMapping = await EPNSCoreV1Proxy.userToChannelNotifs(BOB,CHANNEL_CREATOR);

         await expect(tx).to.emit(EPNSCoreV1Proxy,'UserNotifcationSettingsAdded').withArgs(CHANNEL_CREATOR,BOB,notif_Id,userNotifMapping);

        })

      })
  })



   /**
     * "subscribeToSpecificNotification" Function CHECKPOINTS
     * Should revert if Channel is NOT an ACTIVATED CHannel
     * Should update the "channelNotifSettings" mapping with the right DATA
     * Should emit out the Imperative EVENTS;
     **/

    describe("Testing the Notification Settings function for CHANNELS", function()
      { 
        const CHANNEL_TYPE = 2;
        const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");
        const notif_options = 5;
        const notif_description = "Governance Notif + Liquidity Notif + Price Updates + AirDrop Notif + Other Notifs";
        const channel_notifSettings = "1-0+2-50-20-100+1-1+2-78-10-150";
    
        beforeEach(async function(){
      
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(DELEGATED_CONTRACT_FEES);
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, DELEGATED_CONTRACT_FEES);
       });

        it("Should revert if Channel is NOT an ACTIVATED CHannel", async function () {
          const CHANNEL_TYPE = 2;
          const userDetails = await EPNSCoreV1Proxy.users(BOB);
          const tx =  EPNSCoreV1Proxy.connect(BOBSIGNER).createChannelNotificationSettings(notif_options,channel_notifSettings,notif_description);
          expect(userDetails.channellized).to.be.equal(false);
          await expect(tx).to.be.revertedWith("Channel deactivated or doesn't exists")
        });

        it("Should update the channelNotifSettings mapping with the right DATA", async function () {
          const CHANNEL_TYPE = 2;
          const notifSettings_final = "5+1-0+2-50-20-100+1-1+2-78-10-150";

          const userDetails = await EPNSCoreV1Proxy.users(CHANNEL_CREATOR);

          const tx =  EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelNotificationSettings(notif_options,channel_notifSettings,notif_description);
          const channelNotifMapping = await EPNSCoreV1Proxy.channelNotifSettings(CHANNEL_CREATOR);

          expect(channelNotifMapping).to.be.equal(notifSettings_final)
          expect(userDetails.channellized).to.be.equal(true);
        });

         it("Should Emit out the EVENTS with the right Parameters", async function (){
          const CHANNEL_TYPE = 2;
          const notifSettings_final = "5+1-0+2-50-20-100+1-1+2-78-10-150";

          const userDetails = await EPNSCoreV1Proxy.users(CHANNEL_CREATOR);

          const tx =  EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelNotificationSettings(notif_options,channel_notifSettings,notif_description);
          const channelNotifMapping = await EPNSCoreV1Proxy.channelNotifSettings(CHANNEL_CREATOR);

         await expect(tx).to.emit(EPNSCoreV1Proxy,'ChannelNotifcationSettingsAdded').withArgs(CHANNEL_CREATOR,notif_options,channelNotifMapping,notif_description);

        })

  })
})
