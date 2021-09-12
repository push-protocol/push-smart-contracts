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
// Ropsten DAI - 0xaD6D458402F60fD3Bd25163575031ACDce07538D
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


 describe("EPNS CORE: Channel Deactivation & Reactivation Tests", function(){

   describe("Testing Deactivation and Reactivation of Channels", function()
    {
        this.timeout(150000);
        const CHANNEL_TYPE = 2;
        const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

         beforeEach(async function(){
          await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
          await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
          await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
          await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
          await MOCKDAI.connect(BOBSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          await MOCKDAI.connect(BOBSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
       });
        /**
          * "deactivateChannel" Function CheckPoints
          * REVERT CHECKS
          * Should revert if Channel Is NOT Activated Yet
          *
          * Function EXECUTION CheckPoints
          * Channel State should be update to '2'
          * Pool Funds Value should decrease
          * aDai must get Swapped to DAI -> DAI balance increase in contract, aDai balance decrease in Contract
          * Channel's Weight should be updated to new weight
          * Readjustment of FS Ratio should be updated as expected.
          * Channel Owner should be able to Recieve PUSH Tokens
          *
         **/
         it("Printing Balance Differences", async function () {
           await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
           const POOL_FUNDSBefore = await EPNSCoreV1Proxy.POOL_FUNDS()
           const aDAIBalanceBefore = await ADAICONTRACT.balanceOf(EPNSCoreV1Proxy.address);
           const daiBalanceBefore = await MOCKDAI.connect(CHANNEL_CREATORSIGNER).balanceOf(EPNSCoreV1Proxy.address);
           await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();

           const POOL_FUNDSAfter = await EPNSCoreV1Proxy.POOL_FUNDS();
           const aDAIBalanceAfter = await ADAICONTRACT.balanceOf(EPNSCoreV1Proxy.address);
           const daiBalanceAfter = await MOCKDAI.connect(CHANNEL_CREATORSIGNER).balanceOf(EPNSCoreV1Proxy.address);

           await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).reactivateChannel(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
           const aDAIBalanceAfterReactivation = await ADAICONTRACT.balanceOf(EPNSCoreV1Proxy.address);
           const daiBalanceAfterReactivation = await MOCKDAI.connect(CHANNEL_CREATORSIGNER).balanceOf(EPNSCoreV1Proxy.address);


           console.log('POOL FUNDS')
           console.log(`Pool Balance Before Deactivation- ${POOL_FUNDSBefore.toString()}`)
           console.log(`Pool Balance After Deactivation- ${POOL_FUNDSAfter.toString()}`)

           console.log('---------------------')
           console.log('ADAI BALANCE')
           console.log(`ADAI Balance Before Deactivation- ${aDAIBalanceBefore.toString()}`)
           console.log(`ADAI Balance After Deactivation- ${aDAIBalanceAfter.toString()}`)
           console.log(`ADAI Balance After Reactivation- ${aDAIBalanceAfterReactivation.toString()}`)

           console.log('---------------------')
           console.log('DAI BALANCE')
           console.log(`DAI Balance Before Deactivation- ${daiBalanceBefore.toString()}`)
           console.log(`DAI Balance After Deactivation- ${daiBalanceAfter.toString()}`)
           console.log(`DAI Balance After Reactivation- ${daiBalanceAfterReactivation.toString()}`)

         });

        it("Should Revert if Channel is Inactiave", async function () {
          const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
          await expect(tx).to.be.revertedWith("EPNSCoreV1::onlyActivatedChannels: Channel Deactivated, Blocked or Does Not Exist");
        });

        it("Function execution should update the Channel State to '2' ", async function() {
            const channelState_before = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

            await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            const channelState_afterCreation = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

            await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
            const channelState_afterDeactivation = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

            await expect(channelState_before.channelState).to.be.equal(0);
            await expect(channelState_afterCreation.channelState).to.be.equal(1);
            await expect(channelState_afterDeactivation.channelState).to.be.equal(2);
        })

        it("Pool balance should decrease on Channel Deactivation", async function() {
           const POOL_FUNDSBeforeChannelCreation = await EPNSCoreV1Proxy.POOL_FUNDS()

           await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
           const POOL_FUNDSAfterChannelCreation = await EPNSCoreV1Proxy.POOL_FUNDS()

           await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
           const POOL_FUNDSAfterChannelDeactivation = await EPNSCoreV1Proxy.POOL_FUNDS()

           await expect(POOL_FUNDSBeforeChannelCreation).to.be.equal(0);
           await expect(POOL_FUNDSAfterChannelCreation).to.be.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
           await expect(POOL_FUNDSAfterChannelDeactivation).to.be.equal(CHANNEL_DEACTIVATION_FEES);

        });

        it("DAI should increase & ADAI should decrease after Deactivation", async function() {
          const aDAIBalanceBeforeChannelCreation = await ADAICONTRACT.balanceOf(EPNSCoreV1Proxy.address);
          const daiBalanceBeforeChannelCreation = await MOCKDAI.connect(CHANNEL_CREATORSIGNER).balanceOf(EPNSCoreV1Proxy.address);

           await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
           const aDAIBalanceAfterChannelCreation = await ADAICONTRACT.balanceOf(EPNSCoreV1Proxy.address);
           const daiBalanceAfterChannelCreation = await MOCKDAI.connect(CHANNEL_CREATORSIGNER).balanceOf(EPNSCoreV1Proxy.address);

           await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
           const POOL_FUNDSAfterChannelDeactivation = await EPNSCoreV1Proxy.POOL_FUNDS()
           const aDAIBalanceAfterChannelDeactivation = await ADAICONTRACT.balanceOf(EPNSCoreV1Proxy.address);
           const daiBalanceAfterChannelDeactivation = await MOCKDAI.connect(CHANNEL_CREATORSIGNER).balanceOf(EPNSCoreV1Proxy.address);

           await expect(aDAIBalanceBeforeChannelCreation).to.be.equal(0);
           await expect(daiBalanceBeforeChannelCreation).to.be.equal(0);
           await expect(aDAIBalanceAfterChannelCreation).to.be.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
           await expect(daiBalanceAfterChannelCreation).to.be.equal(0);
           //await expect(aDAIBalanceAfterChannelDeactivation.toString()).to.be.equal('10000001039236351664');
           await expect(aDAIBalanceAfterChannelCreation.sub(POOL_FUNDSAfterChannelDeactivation)).to.be.equal(daiBalanceAfterChannelDeactivation);

        });

        it("Function execution should update the Channel Weight Correctly", async function() {
            const channelState_before = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

            await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            const channelState_afterCreation = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

            await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
            const channelState_afterDeactivation = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

            const channelWeihght_OLD = ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            const channelWeight_NEW = CHANNEL_DEACTIVATION_FEES.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

            await expect(channelState_before.channelWeight).to.be.equal(0);
            await expect(channelState_afterCreation.channelWeight).to.be.equal(channelWeihght_OLD);
            await expect(channelState_afterDeactivation.channelWeight).to.be.equal(channelWeight_NEW);
        })

        it("Deactivation of Channel Should Readjust the FS Values Correctly", async function(){
         const CHANNEL_TYPE = 2;
         await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

         const channelWeihght_OLD = ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
         const channelWeight_NEW = CHANNEL_DEACTIVATION_FEES.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

         const _groupFairShareCount = await EPNSCoreV1Proxy.groupFairShareCount();
         const _groupHistoricalZ = await EPNSCoreV1Proxy.groupHistoricalZ();
         const _groupLastUpdate = await EPNSCoreV1Proxy.groupLastUpdate();
         const _groupNormalizedWeightAfterChannelCreation = await EPNSCoreV1Proxy.groupNormalizedWeight();

         const tx = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();

         const blockNumber = tx.blockNumber;

         const {
           groupNewCount,
           groupNewNormalizedWeight,
           groupNewHistoricalZ,
           groupNewLastUpdate
         } = readjustFairShareOfChannels(ChannelAction.ChannelUpdated, channelWeight_NEW, _groupFairShareCount, _groupNormalizedWeightAfterChannelCreation, _groupHistoricalZ, _groupLastUpdate, bn(blockNumber));

         const _groupFairShareCountNew = await EPNSCoreV1Proxy.groupFairShareCount();
         const _groupNormalizedWeightAfterChannelDeactivation = await EPNSCoreV1Proxy.groupNormalizedWeight();
         const _groupHistoricalZNew = await EPNSCoreV1Proxy.groupHistoricalZ();
         const _groupLastUpdateNew = await EPNSCoreV1Proxy.groupLastUpdate();

         expect(_groupFairShareCountNew).to.equal(groupNewCount);
         expect(_groupHistoricalZNew).to.equal(groupNewHistoricalZ);
         expect(_groupLastUpdateNew).to.equal(groupNewLastUpdate);
         expect(_groupNormalizedWeightAfterChannelCreation).to.equal(channelWeihght_OLD);
         expect(_groupNormalizedWeightAfterChannelDeactivation).to.equal(channelWeight_NEW);
       });

  });

  describe("Testing Reactivation of Channels", function()
   {
       this.timeout(150000);
       const CHANNEL_TYPE = 2;
       const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

        beforeEach(async function(){
         await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
         await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
         await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
         await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
      });
       /**
         * "reactivateChannel" Function CheckPoints
         * REVERT CHECKS
         * Should revert if EPNSCoreV1::onlyDeactivatedChannels: Channel is not Deactivated Yet
         * Should revert if Amount being deposited for Reactivation of Channel is Less than Min amount
         *
         * Function EXECUTION CheckPoints
         * Channel State should be update to '1'
         * Should transfer DAI from USer and Deposit to AAVE_LENDING_POOL
         * Channel's Weight should be updated to new weight
         * Readjustment of FS Ratio should be updated as expected.
         *
        **/


       it("Should Execute if Channel Deactivated before Calling reactivateChannel function", async function () {
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
         await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
         const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).reactivateChannel(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
         await expect(tx)
           .to.emit(EPNSCoreV1Proxy, 'ReactivateChannel')
           .withArgs(CHANNEL_CREATOR, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
       });


      it("Should Revert if Minimum Required Amount is not passed while Reactivating Channel", async function () {
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
        const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).reactivateChannel(CHANNEL_DEACTIVATION_FEES);
        await expect(tx).to.be.revertedWith("EPNSCoreV1::reactivateChannel: Insufficient Funds Passed for Channel Reactivation");
      });

       it("Function execution should update the Channel State to '1' ", async function() {
           const channelState_before = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

           await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
           const channelState_afterCreation = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

           await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
           const channelState_afterDeactivation = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

           await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).reactivateChannel(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
           const channelState_afterReactivation= await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

           await expect(channelState_before.channelState).to.be.equal(0);
           await expect(channelState_afterCreation.channelState).to.be.equal(1);
           await expect(channelState_afterDeactivation.channelState).to.be.equal(2);
           await expect(channelState_afterReactivation.channelState).to.be.equal(1);
       })

       it("Function execution should update the Channel Weight Correctly", async function() {
           const channelState_before = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

           await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
           const channelState_afterCreation = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

           await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
           const channelState_afterDeactivation = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

           await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).reactivateChannel(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
           const channelState_afterReactivation = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

           const channelWeihght_OLD = ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
           const channelWeight_NEW = CHANNEL_DEACTIVATION_FEES.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

           await expect(channelState_before.channelWeight).to.be.equal(0);
           await expect(channelState_afterCreation.channelWeight).to.be.equal(channelWeihght_OLD);
           await expect(channelState_afterDeactivation.channelWeight).to.be.equal(channelWeight_NEW);
           await expect(channelState_afterReactivation.channelWeight).to.be.equal(channelWeihght_OLD);
       })
       it("Function execution should update the Channel Weight Correctly State to '2' ", async function() {
           const channelState_before = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

           await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
           const channelState_afterCreation = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

           await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
           const channelState_afterDeactivation = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);

           const channelWeihght_OLD = ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
           const channelWeight_NEW = CHANNEL_DEACTIVATION_FEES.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

           await expect(channelState_before.channelWeight).to.be.equal(0);
           await expect(channelState_afterCreation.channelWeight).to.be.equal(channelWeihght_OLD);
           await expect(channelState_afterDeactivation.channelWeight).to.be.equal(channelWeight_NEW);
       })

        it("Pool balance should UPdate Correctly on Channel Reactivation", async function() {
           const POOL_FUNDSBeforeChannelCreation = await EPNSCoreV1Proxy.POOL_FUNDS()

           await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
           const POOL_FUNDSAfterChannelCreation = await EPNSCoreV1Proxy.POOL_FUNDS()

           await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
           const POOL_FUNDSAfterChannelDeactivation = await EPNSCoreV1Proxy.POOL_FUNDS()

           await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).reactivateChannel(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
           const POOL_FUNDSAfterChannelReactivation = await EPNSCoreV1Proxy.POOL_FUNDS()

           await expect(POOL_FUNDSBeforeChannelCreation).to.be.equal(0);
           await expect(POOL_FUNDSAfterChannelCreation).to.be.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
           await expect(POOL_FUNDSAfterChannelDeactivation).to.be.equal(CHANNEL_DEACTIVATION_FEES);
           await expect(POOL_FUNDSAfterChannelReactivation).to.be.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION.add(CHANNEL_DEACTIVATION_FEES));

        });

       it("Reactivation of Channel Should Readjust the FS Values Correctly", async function(){
        const CHANNEL_TYPE = 2;
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        const _groupNormalizedWeightAfterChannelCreation = await EPNSCoreV1Proxy.groupNormalizedWeight();
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();

        const channelWeihght_OLD = ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        const channelWeight_NEW = CHANNEL_DEACTIVATION_FEES.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

        const _groupFairShareCount = await EPNSCoreV1Proxy.groupFairShareCount();
        const _groupHistoricalZ = await EPNSCoreV1Proxy.groupHistoricalZ();
        const _groupLastUpdate = await EPNSCoreV1Proxy.groupLastUpdate();
        const _groupNormalizedWeightAfterDeactivation = await EPNSCoreV1Proxy.groupNormalizedWeight();


        const tx = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).reactivateChannel(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

        const blockNumber = tx.blockNumber;

        const {
          groupNewCount,
          groupNewNormalizedWeight,
          groupNewHistoricalZ,
          groupNewLastUpdate
        } = readjustFairShareOfChannels(ChannelAction.ChannelUpdated, channelWeihght_OLD, _groupFairShareCount, _groupNormalizedWeightAfterDeactivation, _groupHistoricalZ, _groupLastUpdate, bn(blockNumber));

        const _groupFairShareCountNew = await EPNSCoreV1Proxy.groupFairShareCount();
        const _groupHistoricalZNew = await EPNSCoreV1Proxy.groupHistoricalZ();
        const _groupLastUpdateNew = await EPNSCoreV1Proxy.groupLastUpdate();
        const _groupNormalizedWeightAfterChannelReactivation = await EPNSCoreV1Proxy.groupNormalizedWeight();


        expect(_groupFairShareCountNew).to.equal(groupNewCount);
        expect(_groupHistoricalZNew).to.equal(groupNewHistoricalZ);
        expect(_groupLastUpdateNew).to.equal(groupNewLastUpdate);
        expect(_groupNormalizedWeightAfterChannelCreation).to.equal(channelWeihght_OLD);
        expect(_groupNormalizedWeightAfterDeactivation).to.equal(channelWeight_NEW);
        expect(_groupNormalizedWeightAfterChannelReactivation).to.equal(channelWeihght_OLD);
      });

 });

});
});
