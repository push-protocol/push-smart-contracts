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

describe("EPNS COMMUNICATOR Protocol ", function () {

  const DAI = "0xf80A32A835F79D7787E8a8ee5721D0fEaFd78108";
  const ADAI = "0xcB1Fe6F440c49E9290c3eb7f158534c2dC374201";
  const WETH = "0xc778417E063141139Fce010982780140Aa0cD5Ab";
  const UNISWAP_ROUTER = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
  const AAVE_LENDING_POOL = "0x1c8756FD2B28e9426CDBDcC7E3c4d64fa9A54728";

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
  let ALICE;
  let BOB;
  let USER1;
  let USER2;
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
      user1signer,
      user2signer,
    ] = await ethers.getSigners();

    ADMINSIGNER = adminSigner;
    ALICESIGNER = aliceSigner;
    BOBSIGNER = bobSigner;
    CHARLIESIGNER = charlieSigner;
    CHANNEL_CREATORSIGNER = channelCreatorSigner;
    USER1SIGNER = user1signer;
    USER2SIGNER = user2signer;

    ADMIN = await adminSigner.getAddress();
    ALICE = await aliceSigner.getAddress();
    BOB = await bobSigner.getAddress();
    CHARLIE = await charlieSigner.getAddress();
    CHANNEL_CREATOR = await channelCreatorSigner.getAddress();
    USER1 = await user1signer.getAddress();
    USER2 = await user2signer.getAddress();

    const EPNSTOKEN = await ethers.getContractFactory("EPNS");
    EPNS = await EPNSTOKEN.deploy(ADMIN);

    const EPNSCore = await ethers.getContractFactory("EPNSCoreV1");
    CORE_LOGIC = await EPNSCore.deploy();

    const TimeLock = await ethers.getContractFactory("Timelock");
    TIMELOCK = await TimeLock.deploy(ADMIN, delay);

    const proxyAdmin = await ethers.getContractFactory("EPNSAdmin");
    PROXYADMIN = await proxyAdmin.deploy();
    await PROXYADMIN.transferOwnership(TIMELOCK.address);

    const EPNSCommV1 = await ethers.getContractFactory("EPNSCommV1");
    COMMUNICATOR_LOGIC = await EPNSCommV1.deploy();

    const EPNSCoreProxyContract = await ethers.getContractFactory("EPNSCoreProxy");
    EPNSCoreProxy = await EPNSCoreProxyContract.deploy(
      CORE_LOGIC.address,
      ADMINSIGNER.address,
      EPNS.address,
      WETH,
      UNISWAP_ROUTER,
      AAVE_LENDING_POOL,
      DAI,
      ADAI,
      referralCode,
    );

    await EPNSCoreProxy.changeAdmin(ALICESIGNER.address);
    EPNSCoreV1Proxy = EPNSCore.attach(EPNSCoreProxy.address)

    const EPNSCommProxyContract = await ethers.getContractFactory("EPNSCommProxy");
    EPNSCommProxy = await EPNSCommProxyContract.deploy(
      COMMUNICATOR_LOGIC.address,
      ADMINSIGNER.address
    );

    await EPNSCommProxy.changeAdmin(ALICESIGNER.address);
    EPNSCommV1Proxy = EPNSCommV1.attach(EPNSCommProxy.address)

  });

  afterEach(function () {
    EPNS = null
    CORE_LOGIC = null
    TIMELOCK = null
    EPNSCoreProxy = null
    EPNSCoreV1Proxy = null
  });


 describe("EPNS COMMUNICATOR: Notification Test Cases", function(){

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
                 await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
                 await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
                 await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
              });
           it("Should revert if a User is sending Notif to Other Address Instead of themselves", async function(){
             const msg = ethers.utils.toUtf8Bytes("This is notification message");
             const tx = EPNSCommV1Proxy.connect(BOBSIGNER).sendNotification(CHANNEL_CREATOR, BOB, CHARLIE, msg);
             await expect(tx).to.be.revertedWith("EPNSCommV1::_checkNotifReq: Invalid Channel, Delegate or Subscriber");
           });

           it("Should Emit Event if Recipient is Sending NOTIF Only to HIMself/Herself", async function(){
             const msg = ethers.utils.toUtf8Bytes("This is notification message");
             const tx_sendNotif = EPNSCommV1Proxy.connect(BOBSIGNER).sendNotification(CHANNEL_CREATOR, BOB, BOB, msg);
             await expect(tx_sendNotif)
                  .to.emit(EPNSCommV1Proxy, 'SendNotification')
                  .withArgs(CHANNEL_CREATOR, BOB, ethers.utils.hexlify(msg));
           });

           it("Should revert if Channel is 0x00.. But Caller is any address other than Admin/Governance", async function(){
             const EPNS_ALERTER_CHANNEL = '0x0000000000000000000000000000000000000000';
             const msg = ethers.utils.toUtf8Bytes("This is notification message");
             const tx = EPNSCommV1Proxy.connect(BOBSIGNER).sendNotification(EPNS_ALERTER_CHANNEL, BOB, CHARLIE, msg);
             await expect(tx).to.be.revertedWith("EPNSCommV1::_checkNotifReq: Invalid Channel, Delegate or Subscriber");
           });

           it("Should Emit Event if Channel is 0x00.. and Caller is Admin/Governance", async function(){
             const EPNS_ALERTER_CHANNEL = '0x0000000000000000000000000000000000000000';
             const msg = ethers.utils.toUtf8Bytes("This is notification message");
             const tx_sendNotif = EPNSCommV1Proxy.connect(ADMINSIGNER).sendNotification(EPNS_ALERTER_CHANNEL, BOB, CHARLIE, msg);
             await expect(tx_sendNotif)
                  .to.emit(EPNSCommV1Proxy, 'SendNotification')
                  .withArgs(EPNS_ALERTER_CHANNEL, CHARLIE, ethers.utils.hexlify(msg));
           });

           it("Should revert if Delegate without send notification without Approval", async function(){
             const msg = ethers.utils.toUtf8Bytes("This is notification message");
             const tx = EPNSCommV1Proxy.connect(CHARLIESIGNER).sendNotification(CHANNEL_CREATOR, CHARLIE, BOB, msg);
             await expect(tx).to.be.revertedWith("EPNSCommV1::_checkNotifReq: Invalid Channel, Delegate or Subscriber");
           });

           it("Should Emit Event Allowed Delagtes Sends Notification to any Recipient", async function(){
             const isCharlieAllowed_before = await EPNSCommV1Proxy.connect(CHANNEL_CREATORSIGNER).delegatedNotificationSenders(CHANNEL_CREATOR, CHARLIE);
             await EPNSCommV1Proxy.connect(CHANNEL_CREATORSIGNER).addDelegate(CHARLIE);
             const isCharlieAllowed_after = await EPNSCommV1Proxy.connect(CHANNEL_CREATORSIGNER).delegatedNotificationSenders(CHANNEL_CREATOR, CHARLIE);

             const msg = ethers.utils.toUtf8Bytes("This is notification message");
             const tx_sendNotif = EPNSCommV1Proxy.connect(CHARLIESIGNER).sendNotification(CHANNEL_CREATOR, CHARLIE, BOB, msg);

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
