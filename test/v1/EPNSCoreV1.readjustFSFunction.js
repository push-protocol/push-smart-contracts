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

  const CHAIN_NAME = 'ROPSTEN'; // MAINNET, MATIC etc.
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
      ADMINSIGNER.address,
      CHAIN_NAME
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
            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MAX_POOL_CONTRIBUTION);

            await MOCKDAI.connect(BOBSIGNER).mint(ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
            await MOCKDAI.connect(BOBSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
            await MOCKDAI.connect(ALICESIGNER).mint(ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
            await MOCKDAI.connect(ALICESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
            await MOCKDAI.connect(CHARLIESIGNER).mint(ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
            await MOCKDAI.connect(CHARLIESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
         });

         it("Adjust of FS Variables of 4 Channels after channel addition (50 DAI each)", async function(){
            const Ch_1_amount = tokensBN(50);
            const Ch_2_amount = tokensBN(50);
            const Ch_3_amount = tokensBN(50);
            const Ch_4_amount = tokensBN(50);

            await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,Ch_1_amount);
            await EPNSCoreV1Proxy.connect(BOBSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,Ch_2_amount);
            await EPNSCoreV1Proxy.connect(ALICESIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,Ch_3_amount);

            const _groupFairShareCount = await EPNSCoreV1Proxy.groupFairShareCount();
            const _groupNormalizedWeight = await EPNSCoreV1Proxy.groupNormalizedWeight();
            const _groupHistoricalZ = await EPNSCoreV1Proxy.groupHistoricalZ();
            const _groupLastUpdate = await EPNSCoreV1Proxy.groupLastUpdate();

            const tx = await EPNSCoreV1Proxy.connect(CHARLIESIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,Ch_4_amount);
            const _oldChannelWeight = 0;
            const newChannelWeight = ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            const blockNumber = tx.blockNumber;

            const {
              groupNewCount,
              groupNewNormalizedWeight,
              groupNewHistoricalZ,
              groupNewLastUpdate
            } = readjustFairShareOfChannels(ChannelAction.ChannelAdded, newChannelWeight, _oldChannelWeight, _groupFairShareCount, _groupNormalizedWeight, _groupHistoricalZ, _groupLastUpdate, bn(blockNumber));

            const _groupFairShareCountNew = await EPNSCoreV1Proxy.groupFairShareCount();
            const _groupNormalizedWeightNew = await EPNSCoreV1Proxy.groupNormalizedWeight();
            const _groupHistoricalZNew = await EPNSCoreV1Proxy.groupHistoricalZ();
            const _groupLastUpdateNew = await EPNSCoreV1Proxy.groupLastUpdate();

            expect(_groupFairShareCountNew).to.equal(groupNewCount);
            expect(_groupNormalizedWeightNew).to.equal(groupNewNormalizedWeight);
            expect(_groupHistoricalZNew).to.equal(groupNewHistoricalZ);
            expect(_groupLastUpdateNew).to.equal(groupNewLastUpdate);
        });

    it("Adjust of FS Variables of 4 Channels after 1 channel DeActivation (50 DAI each)", async function(){
      const Ch_1_amount = tokensBN(50);
      const Ch_2_amount = tokensBN(50);
      const Ch_3_amount = tokensBN(50);
      const Ch_4_amount = tokensBN(50);
      await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,Ch_1_amount);
      await EPNSCoreV1Proxy.connect(BOBSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,Ch_2_amount);
      await EPNSCoreV1Proxy.connect(ALICESIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,Ch_3_amount);
      await EPNSCoreV1Proxy.connect(CHARLIESIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,Ch_4_amount);

      const _groupFairShareCount = await EPNSCoreV1Proxy.groupFairShareCount();
      const _groupNormalizedWeight = await EPNSCoreV1Proxy.groupNormalizedWeight();
      const _groupHistoricalZ = await EPNSCoreV1Proxy.groupHistoricalZ();
      const _groupLastUpdate = await EPNSCoreV1Proxy.groupLastUpdate();

      const tx = await EPNSCoreV1Proxy.connect(CHARLIESIGNER).deactivateChannel();
      const _oldChannelWeight = Ch_4_amount.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
      const newChannelWeight = CHANNEL_DEACTIVATION_FEES.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
      const blockNumber = tx.blockNumber;

      const {
        groupNewCount,
        groupNewNormalizedWeight,
        groupNewHistoricalZ,
        groupNewLastUpdate
      } = readjustFairShareOfChannels(ChannelAction.ChannelUpdated, newChannelWeight, _oldChannelWeight, _groupFairShareCount, _groupNormalizedWeight, _groupHistoricalZ, _groupLastUpdate, bn(blockNumber));

      const _groupFairShareCountNew = await EPNSCoreV1Proxy.groupFairShareCount();
      const _groupNormalizedWeightNew = await EPNSCoreV1Proxy.groupNormalizedWeight();
      const _groupHistoricalZNew = await EPNSCoreV1Proxy.groupHistoricalZ();
      const _groupLastUpdateNew = await EPNSCoreV1Proxy.groupLastUpdate();

      expect(_groupFairShareCountNew).to.equal(groupNewCount);
      expect(_groupNormalizedWeightNew).to.equal(groupNewNormalizedWeight);
      expect(_groupHistoricalZNew).to.equal(groupNewHistoricalZ);
      expect(_groupLastUpdateNew).to.equal(groupNewLastUpdate);
  });

  it("Adjust of FS Variables of 4 Channels after 1 channel DeActivation and Reactivation (50 DAI each)", async function(){
     const Ch_1_amount = tokensBN(50);
     const Ch_2_amount = tokensBN(50);
     const Ch_3_amount = tokensBN(50);
     const Ch_4_amount = tokensBN(50);

     await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,Ch_1_amount);
     await EPNSCoreV1Proxy.connect(BOBSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,Ch_2_amount);
     await EPNSCoreV1Proxy.connect(ALICESIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,Ch_3_amount);
     await EPNSCoreV1Proxy.connect(CHARLIESIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,Ch_4_amount);
     await EPNSCoreV1Proxy.connect(CHARLIESIGNER).deactivateChannel();

     const _groupFairShareCount = await EPNSCoreV1Proxy.groupFairShareCount();
     const _groupNormalizedWeight = await EPNSCoreV1Proxy.groupNormalizedWeight();
     const _groupHistoricalZ = await EPNSCoreV1Proxy.groupHistoricalZ();
     const _groupLastUpdate = await EPNSCoreV1Proxy.groupLastUpdate();

     const tx = await EPNSCoreV1Proxy.connect(CHARLIESIGNER).reactivateChannel(Ch_4_amount);
     const _oldChannelWeight = CHANNEL_DEACTIVATION_FEES.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
     const newPoolContribution = Ch_4_amount.add(CHANNEL_DEACTIVATION_FEES);
     const newChannelWeight = newPoolContribution.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
     const blockNumber = tx.blockNumber;

     const {
       groupNewCount,
       groupNewNormalizedWeight,
       groupNewHistoricalZ,
       groupNewLastUpdate
     } = readjustFairShareOfChannels(ChannelAction.ChannelUpdated, newChannelWeight, _oldChannelWeight, _groupFairShareCount, _groupNormalizedWeight, _groupHistoricalZ, _groupLastUpdate, bn(blockNumber));


     const _groupFairShareCountNew = await EPNSCoreV1Proxy.groupFairShareCount();
     const _groupNormalizedWeightNew = await EPNSCoreV1Proxy.groupNormalizedWeight();
     const _groupHistoricalZNew = await EPNSCoreV1Proxy.groupHistoricalZ();
     const _groupLastUpdateNew = await EPNSCoreV1Proxy.groupLastUpdate();

     expect(_groupFairShareCountNew).to.equal(groupNewCount);
     expect(_groupNormalizedWeightNew).to.equal(groupNewNormalizedWeight);
     expect(_groupHistoricalZNew).to.equal(groupNewHistoricalZ);
     expect(_groupLastUpdateNew).to.equal(groupNewLastUpdate);

   });

   it("Adjust of FS Variables of 4 Channels after Deactivation->Reactivation->Blocking of a Channel (50 DAI each)", async function(){
    const Ch_1_amount = tokensBN(50);
    const Ch_2_amount = tokensBN(50);
    const Ch_3_amount = tokensBN(50);
    const Ch_4_amount = tokensBN(50);

    await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,Ch_1_amount);
    await EPNSCoreV1Proxy.connect(BOBSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,Ch_2_amount);
    await EPNSCoreV1Proxy.connect(ALICESIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,Ch_3_amount);
    await EPNSCoreV1Proxy.connect(CHARLIESIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,Ch_4_amount);
    await EPNSCoreV1Proxy.connect(CHARLIESIGNER).deactivateChannel();
    await EPNSCoreV1Proxy.connect(CHARLIESIGNER).reactivateChannel(Ch_4_amount);

    const _groupFairShareCount = await EPNSCoreV1Proxy.groupFairShareCount();
    const _groupNormalizedWeight = await EPNSCoreV1Proxy.groupNormalizedWeight();
    const _groupHistoricalZ = await EPNSCoreV1Proxy.groupHistoricalZ();
    const _groupLastUpdate = await EPNSCoreV1Proxy.groupLastUpdate();

    const tx = await EPNSCoreV1Proxy.connect(ADMINSIGNER).blockChannel(CHARLIE);
    const newPoolContribution = Ch_4_amount.add(CHANNEL_DEACTIVATION_FEES);
    const _oldChannelWeight = newPoolContribution.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
    const newChannelWeight = CHANNEL_DEACTIVATION_FEES.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
    const blockNumber = tx.blockNumber;

    const {
      groupNewCount,
      groupNewNormalizedWeight,
      groupNewHistoricalZ,
      groupNewLastUpdate
    } = readjustFairShareOfChannels(ChannelAction.ChannelRemoved, newChannelWeight, _oldChannelWeight, _groupFairShareCount, _groupNormalizedWeight, _groupHistoricalZ, _groupLastUpdate, bn(blockNumber));


    const _groupFairShareCountNew = await EPNSCoreV1Proxy.groupFairShareCount();
    const _groupNormalizedWeightNew = await EPNSCoreV1Proxy.groupNormalizedWeight();
    const _groupHistoricalZNew = await EPNSCoreV1Proxy.groupHistoricalZ();
    const _groupLastUpdateNew = await EPNSCoreV1Proxy.groupLastUpdate();

    expect(_groupFairShareCountNew).to.equal(groupNewCount);
    expect(_groupNormalizedWeightNew).to.equal(groupNewNormalizedWeight);
    expect(_groupHistoricalZNew).to.equal(groupNewHistoricalZ);
    expect(_groupLastUpdateNew).to.equal(groupNewLastUpdate);

});



   it("Adjust of FS Variables of 4 Channels after 1 channel DeActivation and Reactivation (with 150, 200, 250 DAI each)", async function(){
    // Sepcial CASE of 30, 40, 50 -> Suggested by Auditor
      const Ch_1_amount = tokensBN(150);
      const Ch_2_amount = tokensBN(200);
      const Ch_4_amount = tokensBN(250);

      const new_Amount_For_reactivation = tokensBN(290);

      await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,Ch_1_amount);
      await EPNSCoreV1Proxy.connect(BOBSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,Ch_2_amount);
      await EPNSCoreV1Proxy.connect(CHARLIESIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,Ch_4_amount);
      await EPNSCoreV1Proxy.connect(CHARLIESIGNER).deactivateChannel();

      const _groupFairShareCount = await EPNSCoreV1Proxy.groupFairShareCount();
      const _groupNormalizedWeight = await EPNSCoreV1Proxy.groupNormalizedWeight();
      const _groupHistoricalZ = await EPNSCoreV1Proxy.groupHistoricalZ();
      const _groupLastUpdate = await EPNSCoreV1Proxy.groupLastUpdate();

      const tx = await EPNSCoreV1Proxy.connect(CHARLIESIGNER).reactivateChannel(new_Amount_For_reactivation);
      const _oldChannelWeight = CHANNEL_DEACTIVATION_FEES.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
      const newPoolContribution = new_Amount_For_reactivation.add(CHANNEL_DEACTIVATION_FEES);
      const newChannelWeight = newPoolContribution.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
      const blockNumber = tx.blockNumber;

      const {
        groupNewCount,
        groupNewNormalizedWeight,
        groupNewHistoricalZ,
        groupNewLastUpdate
      } = readjustFairShareOfChannels(ChannelAction.ChannelUpdated, newChannelWeight, _oldChannelWeight, _groupFairShareCount, _groupNormalizedWeight, _groupHistoricalZ, _groupLastUpdate, bn(blockNumber));


      const _groupFairShareCountNew = await EPNSCoreV1Proxy.groupFairShareCount();
      const _groupNormalizedWeightNew = await EPNSCoreV1Proxy.groupNormalizedWeight();
      const _groupHistoricalZNew = await EPNSCoreV1Proxy.groupHistoricalZ();
      const _groupLastUpdateNew = await EPNSCoreV1Proxy.groupLastUpdate();

      expect(_groupFairShareCountNew).to.equal(groupNewCount);
      expect(_groupNormalizedWeightNew).to.equal(groupNewNormalizedWeight);
      expect(_groupHistoricalZNew).to.equal(groupNewHistoricalZ);
      expect(_groupLastUpdateNew).to.equal(groupNewLastUpdate);

  });



  });
});
});
