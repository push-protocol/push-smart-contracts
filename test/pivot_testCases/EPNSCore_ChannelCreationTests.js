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


 describe("EPNS CORE: Channel Creation, Deactivation & Reactivation Tests", function(){


    describe("Testing the Base Create Channel Function", function()
      {
          const CHANNEL_TYPE = 2;
          const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

           beforeEach(async function(){
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommunicatorV1Proxy.address)
            await EPNSCommunicatorV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
         });
          /**
            * "createChannelWithFees" Function CheckPoints
            * REVERT CHECKS
            * Should revert IF Channel is already activated 
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

          it("Should revert if IF Channel is already activated ", async function () {
            const CHANNEL_TYPE = 2;
            await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

            const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

            await expect(tx).to.be.revertedWith("Channel is already activated")
          });

          it("Should revert Channel Type is not the ALLOWED TYPES", async function () {
            const CHANNEL_TYPE = 0;
            const tx1 = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

            await expect(tx1).to.be.revertedWith("Channel Type Invalid")

            const CHANNEL_TYPE_SECOND = 1;
            const testChannelSecond = ethers.utils.toUtf8Bytes("test-channel-hello-world-two");

            const tx2 = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE_SECOND, testChannelSecond,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

            await expect(tx2).to.be.revertedWith("Channel Type Invalid")
          });

          it("should revert if allowance is not greater than min fees", async function(){
            const CHANNEL_TYPE = 2;

            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, tokensBN(10));

            const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,tokensBN(10));

            await expect(tx).to.be.revertedWith("Insufficient Funds or max ceiling reached")
          });

            it("should revert if amount being transferred is greater than actually approved", async function(){
            const CHANNEL_TYPE = 2;

            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address,ADD_CHANNEL_MIN_POOL_CONTRIBUTION );

            const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MAX_POOL_CONTRIBUTION);

            await expect(tx).to.be.revertedWith("subtraction overflow")
          });
      

          it("should transfer given fees from creator account to proxy", async function(){
            const CHANNEL_TYPE = 2;

            const daiBalanceBefore = await MOCKDAI.connect(CHANNEL_CREATORSIGNER).balanceOf(CHANNEL_CREATOR);

            await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

            const daiBalanceAfter = await MOCKDAI.connect(CHANNEL_CREATORSIGNER).balanceOf(CHANNEL_CREATOR);

            expect(daiBalanceBefore.sub(daiBalanceAfter)).to.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          });

          it("should deposit funds to pool and receive aDAI", async function(){
            const CHANNEL_TYPE = 2;

            const poolFundsBefore = await EPNSCoreV1Proxy.poolFunds()
            const aDAIBalanceBefore = await ADAICONTRACT.balanceOf(EPNSCoreV1Proxy.address);

            await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

            const poolFundsAfter = await EPNSCoreV1Proxy.poolFunds();
            const aDAIBalanceAfter = await ADAICONTRACT.balanceOf(EPNSCoreV1Proxy.address);

            expect(poolFundsAfter.sub(poolFundsBefore)).to.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            expect(aDAIBalanceAfter.sub(aDAIBalanceBefore)).to.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          });

        //   it("EPNS Core Should create Channel and Update Relevant State variables accordingly", async function(){
        //   const channelsCountBefore = await EPNSCoreV1Proxy.channelsCount();

        //   const tx = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        //   const channel = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).channels(CHANNEL_CREATOR)

        //   const blockNumber = tx.blockNumber;
        //   const channelWeight = ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        //   const channelsCountAfter = await EPNSCoreV1Proxy.channelsCount();

        //   expect(channel.channelState).to.equal(1);
        //   expect(channel.poolContribution).to.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        //   expect(channel.channelType).to.equal(CHANNEL_TYPE);
        //   expect(channel.channelStartBlock).to.equal(blockNumber);
        //   expect(channel.channelUpdateBlock).to.equal(blockNumber);
        //   expect(channel.channelWeight).to.equal(channelWeight);
        //   expect(await EPNSCoreV1Proxy.mapAddressChannels(channelsCountAfter.sub(1))).to.equal(CHANNEL_CREATOR);
        //   expect(channelsCountBefore.add(1)).to.equal(channelsCountAfter);
        // }).timeout(10000);

        // it("EPNS Core Should Interact with EPNS Communcator and make the necessary Subscriptions", async function(){
        //   const EPNS_ALERTER = '0x0000000000000000000000000000000000000000';

        //   const isChannelOwnerSubscribed_before = await EPNSCommunicatorV1Proxy.isUserSubscribed(CHANNEL_CREATOR, CHANNEL_CREATOR);
        //   const isChannelSubscribedToEPNS_before = await EPNSCommunicatorV1Proxy.isUserSubscribed(EPNS_ALERTER, CHANNEL_CREATOR);
        //   const isAdminSubscribedToChannel_before = await EPNSCommunicatorV1Proxy.isUserSubscribed(CHANNEL_CREATOR, ADMIN);

        //   await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        //   const channel = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).channels(CHANNEL_CREATOR)

        //   const isChannelOwnerSubscribed_after = await EPNSCommunicatorV1Proxy.isUserSubscribed(CHANNEL_CREATOR, CHANNEL_CREATOR);
        //   const isChannelSubscribedToEPNS_after = await EPNSCommunicatorV1Proxy.isUserSubscribed(EPNS_ALERTER, CHANNEL_CREATOR);
        //   const isAdminSubscribedToChannel_after = await EPNSCommunicatorV1Proxy.isUserSubscribed(CHANNEL_CREATOR, ADMIN);

        //   await expect(isChannelOwnerSubscribed_before).to.equal(false);
        //   await expect(isChannelSubscribedToEPNS_before).to.equal(false);
        //   await expect(isAdminSubscribedToChannel_before).to.equal(false);
        //   await expect(isChannelOwnerSubscribed_after).to.equal(true);
        //   await expect(isChannelSubscribedToEPNS_after).to.equal(true);
        //   await expect(isAdminSubscribedToChannel_after).to.equal(true);

        // }).timeout(10000);

        // FS Ration Modifications should be as expected
         it("should create a channel and update fair share values", async function(){
          const CHANNEL_TYPE = 2;

          const channelWeight = ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          const _groupFairShareCount = await EPNSCoreV1Proxy.groupFairShareCount();
          const _groupNormalizedWeight = await EPNSCoreV1Proxy.groupNormalizedWeight();
          const _groupHistoricalZ = await EPNSCoreV1Proxy.groupHistoricalZ();
          const _groupLastUpdate = await EPNSCoreV1Proxy.groupLastUpdate();

          const tx = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          const blockNumber = tx.blockNumber;

          const {
            groupNewCount,
            groupNewNormalizedWeight,
            groupNewHistoricalZ,
            groupNewLastUpdate
          } = readjustFairShareOfChannels(ChannelAction.ChannelAdded, channelWeight, _groupFairShareCount, _groupNormalizedWeight, _groupHistoricalZ, _groupLastUpdate, bn(blockNumber));

          const _groupFairShareCountNew = await EPNSCoreV1Proxy.groupFairShareCount();
          const _groupNormalizedWeightNew = await EPNSCoreV1Proxy.groupNormalizedWeight();
          const _groupHistoricalZNew = await EPNSCoreV1Proxy.groupHistoricalZ();
          const _groupLastUpdateNew = await EPNSCoreV1Proxy.groupLastUpdate();

          expect(_groupFairShareCountNew).to.equal(groupNewCount);
          expect(_groupNormalizedWeightNew).to.equal(groupNewNormalizedWeight);
          expect(_groupHistoricalZNew).to.equal(groupNewHistoricalZ);
          expect(_groupLastUpdateNew).to.equal(groupNewLastUpdate);
        });

        it("Function Should emit Relevant Events", async function(){
          const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

          await expect(tx)
            .to.emit(EPNSCoreV1Proxy, 'AddChannel')
            .withArgs(CHANNEL_CREATOR, CHANNEL_TYPE, ethers.utils.hexlify(testChannel));
        });

    });

    describe("Testing Deactivation and Reactivation of Channels", function()
      {
          const CHANNEL_TYPE = 2;
          const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

           beforeEach(async function(){
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommunicatorV1Proxy.address)
            await EPNSCommunicatorV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
         });
          /**
            * "deactivateChannel" Function CheckPoints
            * REVERT CHECKS
            * Should revert if Channel Is NOT Activated Yet
            * 
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
           // TBD -> FAILING with Invalid Opcode
          it("Should Execuet First of all", async function () {
            await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();

            await expect(tx).to.be.revertedWith("Channel is already activated")
          }).timeout(15000);

    });

});
});

