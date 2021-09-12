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

describe("EPNS Core Protocol", function () {

  const DAI = "0xf80A32A835F79D7787E8a8ee5721D0fEaFd78108";
  const ADAI = "0xcB1Fe6F440c49E9290c3eb7f158534c2dC374201";
  const WETH = "0xc778417E063141139Fce010982780140Aa0cD5Ab";
  const UNISWAP_ROUTER = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
  const AAVE_LENDING_POOL = "0x1c8756FD2B28e9426CDBDcC7E3c4d64fa9A54728";

  const referralCode = 0;
  const CHANNEL_DEACTIVATION_FEES = tokensBN(10);
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

    const EPNSCore = await ethers.getContractFactory("EPNSCoreV1");
    CORE_LOGIC = await EPNSCore.deploy();

    const TimeLock = await ethers.getContractFactory("Timelock");
    TIMELOCK = await TimeLock.deploy(ADMIN, delay);

    const proxyAdmin = await ethers.getContractFactory("EPNSAdmin");
    PROXYADMIN = await proxyAdmin.deploy();
    await PROXYADMIN.transferOwnership(TIMELOCK.address);

    const EPNSCommunicator = await ethers.getContractFactory("EPNSCommV1");
    COMMUNICATOR_LOGIC = await EPNSCommunicator.deploy();

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
    EPNSCommV1Proxy = EPNSCommunicator.attach(EPNSCommProxy.address)

  });

  afterEach(function () {
    EPNS = null
    CORE_LOGIC = null
    TIMELOCK = null
    EPNSCoreProxy = null
    EPNSCoreV1Proxy = null
  });


 describe("EPNS CORE: Channel Creation Test for ADMIN", function(){
   describe("Testing the createChannelForPushChannelAdmin Function", function()
      {
          const CHANNEL_TYPE = 2;
          const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

           beforeEach(async function(){
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
            await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
         });

         it("Should revert if IF Caller is not the ADMIN", async function () {
           const tx =  EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelForPushChannelAdmin();

           expect(tx).to.be.revertedWith("EPNSCoreV1::onlyPushChannelAdmin: Caller not pushChannelAdmin");

         });

          it("Should only be Executed Once", async function () {
            const oneTimeCheck_before = await EPNSCoreV1Proxy.oneTimeCheck();
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).createChannelForPushChannelAdmin();
            const oneTimeCheck_after = await EPNSCoreV1Proxy.oneTimeCheck();

            const tx = EPNSCoreV1Proxy.connect(ADMINSIGNER).createChannelForPushChannelAdmin();

            expect(oneTimeCheck_before).to.be.equal(false);
            expect(oneTimeCheck_after).to.be.equal(true);
            expect(tx).to.be.revertedWith("EPNSCoreV1::createChannelForPushChannelAdmin: Channel for Admin is already Created");

          });

          it("Should Create a Channel for PUSH ADMIN", async function () {
            const channelDetailsForAdmin_before = await EPNSCoreV1Proxy.channels(ADMIN);
            const channelsCountBefore = await EPNSCoreV1Proxy.channelsCount();

            const tx = EPNSCoreV1Proxy.connect(ADMINSIGNER).createChannelForPushChannelAdmin();
            const channelDetailsForAdmin_after = await EPNSCoreV1Proxy.channels(ADMIN);

            const blockNumber = tx.blockNumber;
            const channelsCountAfter = await EPNSCoreV1Proxy.channelsCount();

            expect(channelsCountBefore).to.equal(0);
            expect(channelsCountAfter).to.equal(2);
            expect(channelDetailsForAdmin_before.channelState).to.equal(0);
            expect(channelDetailsForAdmin_after.channelState).to.equal(1);
            expect(channelDetailsForAdmin_after.poolContribution).to.equal(0);
            expect(channelDetailsForAdmin_after.channelType).to.equal(0);
            // expect(channelDetailsForAdmin_after.channelStartBlock).to.equal(blockNumber);
            // expect(channelDetailsForAdmin_after.channelUpdateBlock).to.equal(blockNumber);
            expect(channelDetailsForAdmin_after.channelWeight).to.equal(0);
          });

          it("Should Create a Channel for EPNS ALERTER", async function () {
            const EPNS_ALERTER = '0x0000000000000000000000000000000000000000';
            const channelDetailsForAdmin_before = await EPNSCoreV1Proxy.channels(EPNS_ALERTER);
            const channelsCountBefore = await EPNSCoreV1Proxy.channelsCount();

            const tx = EPNSCoreV1Proxy.connect(ADMINSIGNER).createChannelForPushChannelAdmin();
            const channelDetailsForAdmin_after = await EPNSCoreV1Proxy.channels(EPNS_ALERTER);

            const blockNumber = tx.blockNumber;
            const channelsCountAfter = await EPNSCoreV1Proxy.channelsCount();

            expect(channelsCountBefore).to.equal(0);
            expect(channelsCountAfter).to.equal(2);
            expect(channelDetailsForAdmin_before.channelState).to.equal(0);
            expect(channelDetailsForAdmin_after.channelState).to.equal(1);
            expect(channelDetailsForAdmin_after.poolContribution).to.equal(0);
            expect(channelDetailsForAdmin_after.channelType).to.equal(0);
            // expect(channelDetailsForAdmin_after.channelStartBlock).to.equal(blockNumber);
            // expect(channelDetailsForAdmin_after.channelUpdateBlock).to.equal(blockNumber);
            expect(channelDetailsForAdmin_after.channelWeight).to.equal(0);
          });

          it("EPNS Core Should Interact with EPNS Communcator and make the necessary Subscriptions", async function(){
            const EPNS_ALERTER = '0x0000000000000000000000000000000000000000';

            const isAdminSubscribed_before = await EPNSCommV1Proxy.isUserSubscribed(ADMIN, ADMIN);
            const isAdminSubscribedToEPNS_before = await EPNSCommV1Proxy.isUserSubscribed(EPNS_ALERTER, ADMIN);
            const isAlerterSubscribedToAlerter_before = await EPNSCommV1Proxy.isUserSubscribed(EPNS_ALERTER, EPNS_ALERTER);

            await EPNSCoreV1Proxy.connect(ADMINSIGNER).createChannelForPushChannelAdmin();
            const channel = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).channels(CHANNEL_CREATOR)

            const isAdminSubscribed_after = await EPNSCommV1Proxy.isUserSubscribed(ADMIN, ADMIN);
            const isAdminSubscribedToEPNS_after = await EPNSCommV1Proxy.isUserSubscribed(EPNS_ALERTER, ADMIN);
            const isAlerterSubscribedToAlerter_after = await EPNSCommV1Proxy.isUserSubscribed(EPNS_ALERTER, EPNS_ALERTER);

            await expect(isAdminSubscribed_before).to.equal(false);
            await expect(isAdminSubscribedToEPNS_before).to.equal(false);
            await expect(isAdminSubscribed_after).to.equal(true);
            await expect(isAdminSubscribedToEPNS_after).to.equal(true);
            await expect(isAlerterSubscribedToAlerter_before).to.equal(false);
            await expect(isAlerterSubscribedToAlerter_after).to.equal(true);

          })

    });


});
});
