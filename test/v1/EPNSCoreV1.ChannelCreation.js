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
    //await PROXYADMIN.transferOwnership(TIMELOCK.address);

    const EPNSCommunicator = await ethers.getContractFactory("EPNSCommV1");
    COMMUNICATOR_LOGIC = await EPNSCommunicator.deploy();

    const EPNSCoreProxyContract = await ethers.getContractFactory("EPNSCoreProxy");
    EPNSCoreProxy = await EPNSCoreProxyContract.deploy(
      CORE_LOGIC.address,
      PROXYADMIN.address,
      ADMINSIGNER.address,
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
      ADMINSIGNER.address
    );

    EPNSCoreV1Proxy = EPNSCore.attach(EPNSCoreProxy.address)
    EPNSCommV1Proxy = EPNSCommunicator.attach(EPNSCommProxy.address)

  });

  afterEach(function () {
    EPNS = null
    CORE_LOGIC = null
    TIMELOCK = null
    EPNSCoreProxy = null
    EPNSCoreV1Proxy = null
  });


 describe("EPNS CORE: Channel Creation Tests", function(){
   describe("Testing the Base Create Channel Function", function()
      {
          const CHANNEL_TYPE = 2;
          const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

           beforeEach(async function(){
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
            await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
         });
          /**
            * "createChannelWithFees" Function CheckPoints
            * REVERT CHECKS
            * Should revert IF EPNSCoreV1::onlyInactiveChannels: Channel already Activated
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

          it("Should revert if IF EPNSCoreV1::onlyInactiveChannels: Channel already Activated ", async function () {
            const CHANNEL_TYPE = 2;
            await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

            const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

            await expect(tx).to.be.revertedWith("EPNSCoreV1::onlyInactiveChannels: Channel already Activated")
          });

          it("Should revert Channel Type is not the ALLOWED TYPES", async function () {
            const CHANNEL_TYPE = 0;
            const tx1 = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

            await expect(tx1).to.be.revertedWith("EPNSCoreV1::onlyUserAllowedChannelType: Channel Type Invalid")

            const CHANNEL_TYPE_SECOND = 1;
            const testChannelSecond = ethers.utils.toUtf8Bytes("test-channel-hello-world-two");

            const tx2 = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE_SECOND, testChannelSecond,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

            await expect(tx2).to.be.revertedWith("EPNSCoreV1::onlyUserAllowedChannelType: Channel Type Invalid")
          });

          it("should revert if allowance is not greater than min fees", async function(){
            const CHANNEL_TYPE = 2;

            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, tokensBN(10));

            const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,tokensBN(10));

            await expect(tx).to.be.revertedWith("EPNSCoreV1::_createChannelWithFees: Insufficient Funds")
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

            const POOL_FUNDSBefore = await EPNSCoreV1Proxy.POOL_FUNDS()
            const aDAIBalanceBefore = await ADAICONTRACT.balanceOf(EPNSCoreV1Proxy.address);

            await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

            const POOL_FUNDSAfter = await EPNSCoreV1Proxy.POOL_FUNDS();
            const aDAIBalanceAfter = await ADAICONTRACT.balanceOf(EPNSCoreV1Proxy.address);

            expect(POOL_FUNDSAfter.sub(POOL_FUNDSBefore)).to.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            expect(aDAIBalanceAfter.sub(aDAIBalanceBefore)).to.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          });

          it("EPNS Core Should create Channel and Update Relevant State variables accordingly", async function(){
          const channelsCountBefore = await EPNSCoreV1Proxy.channelsCount();

          const tx = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          const channel = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).channels(CHANNEL_CREATOR)

          const blockNumber = tx.blockNumber;
          const channelWeight = ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          const channelsCountAfter = await EPNSCoreV1Proxy.channelsCount();

          expect(channel.channelState).to.equal(1);
          expect(channel.poolContribution).to.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          expect(channel.channelType).to.equal(CHANNEL_TYPE);
          expect(channel.channelStartBlock).to.equal(blockNumber);
          expect(channel.channelUpdateBlock).to.equal(blockNumber);
          expect(channel.channelWeight).to.equal(channelWeight);
          expect(await EPNSCoreV1Proxy.mapAddressChannels(channelsCountAfter.sub(1))).to.equal(CHANNEL_CREATOR);
          expect(channelsCountBefore.add(1)).to.equal(channelsCountAfter);
        }).timeout(10000);

        it("EPNS Core Should Interact with EPNS Communcator and make the necessary Subscriptions", async function(){
          const EPNS_ALERTER = '0x0000000000000000000000000000000000000000';

          const isChannelOwnerSubscribed_before = await EPNSCommV1Proxy.isUserSubscribed(CHANNEL_CREATOR, CHANNEL_CREATOR);
          const isChannelSubscribedToEPNS_before = await EPNSCommV1Proxy.isUserSubscribed(EPNS_ALERTER, CHANNEL_CREATOR);
          const isAdminSubscribedToChannel_before = await EPNSCommV1Proxy.isUserSubscribed(CHANNEL_CREATOR, ADMIN);

          await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
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

   describe("Testing the BLOCK CHANNEL Function", function()
      {
          const CHANNEL_TYPE = 2;
          const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

           beforeEach(async function(){
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
            await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await MOCKDAI.connect(BOBSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await MOCKDAI.connect(BOBSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await EPNSCoreV1Proxy.connect(BOBSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
         });
          /**
            * "blockChannel" Function CheckPoints
            * REVERT CHECKS
            * Should revert IF Caller is NOT Admin
            * Should revert if Target Channel is NOT ACTIVATED YET
            * Should revert if Target Channel is NOT BLOCKED ALREADY
            *
            * FUNCTION Execution CHECKS
            *   Updates channel's state to BLOCKED ('3')
            *   Updates Channel's Pool Contribution to ZERO
            *   Updates Channel's Weight to ZERO
            *   Increases the Protocol Fee Pool
            *   Decreases the Channel Count
            *   Readjusts the FS Ratio
            *   Emit 'ChannelBlocked' Event
           **/

          it("Should revert if if Caller is NOT ADMIN", async function () {
            const CHANNEL_TYPE = 2;
            await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

            const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).blockChannel(CHANNEL_CREATOR);

            await expect(tx).to.be.revertedWith("EPNSCoreV1::onlyPushChannelAdmin: Caller not pushChannelAdmin")
          });

          it("Should revert if Target Channel is NOT ACTIVATED YET", async function () {
            const CHANNEL_TYPE = 2;
            const tx1 = EPNSCoreV1Proxy.connect(ADMINSIGNER).blockChannel(CHANNEL_CREATOR);

            await expect(tx1).to.be.revertedWith("EPNSCoreV1::onlyUnblockedChannels: Channel is BLOCKED Already or Not Activated Yet")
          });

          it("Should revert if Target Channel is NOT BLOCKED ALREADY", async function () {
            const CHANNEL_TYPE = 2;
            await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).blockChannel(CHANNEL_CREATOR);

            const tx1 = EPNSCoreV1Proxy.connect(ADMINSIGNER).blockChannel(CHANNEL_CREATOR);

            await expect(tx1).to.be.revertedWith("EPNSCoreV1::onlyUnblockedChannels: Channel is BLOCKED Already or Not Activated Yet")
          });


        it("Should update Channel's Details Correctly", async function(){
            const CHANNEL_TYPE = 2;
            const channelWeight_AfterChannelBlock = CHANNEL_DEACTIVATION_FEES.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

            const protocolFeeBefore = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
            const channelsCountBefore = await EPNSCoreV1Proxy.channelsCount();
            const channelDetailsBefore = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR)


            await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

            const protocolFeeAfterChannelCreation = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
            const channelDetailsAfter = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR)
            const channelsCountAfterChannelCreation = await EPNSCoreV1Proxy.channelsCount();

            await EPNSCoreV1Proxy.connect(ADMINSIGNER).blockChannel(CHANNEL_CREATOR);
            const channelDetailsAfterBlocked = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR)
            const channelsCountAfterBlocked = await EPNSCoreV1Proxy.channelsCount();
            const protocolFeeAfterChannelBlocked = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();

            await expect(channelsCountBefore).to.be.equal(1);
            await expect(channelsCountAfterBlocked).to.be.equal(1);
            await expect(channelsCountAfterChannelCreation).to.be.equal(2);

            await expect(protocolFeeBefore).to.be.equal(0);
            await expect(protocolFeeAfterChannelCreation).to.be.equal(0);
            await expect(protocolFeeAfterChannelBlocked).to.be.equal(channelDetailsAfter.poolContribution.sub(CHANNEL_DEACTIVATION_FEES));

            await expect(channelDetailsAfterBlocked.channelState).to.be.equal(3);
            await expect(channelDetailsAfterBlocked.channelWeight).to.be.equal(channelWeight_AfterChannelBlock);
            await expect(channelDetailsAfterBlocked.poolContribution).to.be.equal(CHANNEL_DEACTIVATION_FEES);

          });


         it("Blocking a Channel should update Fair Share Ratios adequately", async function(){
          const CHANNEL_TYPE = 2;

          await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          const channelWeight_AfterChannelCreation = ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          const channelWeight_AfterChannelBlock = CHANNEL_DEACTIVATION_FEES.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

          const _groupFairShareCount = await EPNSCoreV1Proxy.groupFairShareCount();
          const _groupNormalizedWeight = await EPNSCoreV1Proxy.groupNormalizedWeight();
          const _groupHistoricalZ = await EPNSCoreV1Proxy.groupHistoricalZ();
          const _groupLastUpdate = await EPNSCoreV1Proxy.groupLastUpdate();

          const tx = await EPNSCoreV1Proxy.connect(ADMINSIGNER).blockChannel(CHANNEL_CREATOR);
          const blockNumber = tx.blockNumber;

          const {
            groupNewCount,
            groupNewNormalizedWeight,
            groupNewHistoricalZ,
            groupNewLastUpdate
          } = readjustFairShareOfChannels(ChannelAction.ChannelRemoved, channelWeight_AfterChannelBlock, _groupFairShareCount, _groupNormalizedWeight, _groupHistoricalZ, _groupLastUpdate, bn(blockNumber));

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
          await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          const tx = EPNSCoreV1Proxy.connect(ADMINSIGNER).blockChannel(CHANNEL_CREATOR);

          await expect(tx)
            .to.emit(EPNSCoreV1Proxy, 'ChannelBlocked')
            .withArgs(CHANNEL_CREATOR);
        });

    });

});
});
