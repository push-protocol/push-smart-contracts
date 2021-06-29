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

 
 describe("Testing Channel realted functions", function(){
        /**
     * "createChannelWithFees" Function CHECKPOINTS
     * Should revert if User is already a CHannel
     * Should revert Channel Type is not the ALLOWED TYPES
     * Should conduct the Allowance based checks for Channel Creation Fees
     * Transfer of Channel Creation Fees from User to PROXY ADDress should be ensured
     * Deposit of DAI funds to AAVE and Receiving of aDAI should be checked
     * Should update User's Subscription details in the contract
     * Should update the Channel's Subscription Details in the contract
     * Should update the FAIRSHARE COUNTS
     * AddChannel Event should be emitted
     **/

    describe("Testing the Base Create Channel Function", function()
    { 
        const CHANNEL_TYPE = 2;
        const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");
    
        beforeEach(async function(){
          await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
       });
        // Modifier Based Checks
        it("Should revert if User is already a CHANNEL", async function () {
          const CHANNEL_TYPE = 2;
          await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          const userDetails = await EPNSCoreV1Proxy.users(CHANNEL_CREATOR);

          const CHANNEL_TYPE_SECOND = 3;
          const testChannelSecond = ethers.utils.toUtf8Bytes("test-channel-hello-world-two");

          const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE_SECOND, testChannelSecond,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

          expect(userDetails.channellized).to.be.equal(true);
          await expect(tx).to.be.revertedWith("User already a Channel Owner")
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

      //  CHANNEL CREATION FEES TESTS

      it("should revert if allowance is not greater than min fees", async function(){
        const CHANNEL_TYPE = 2;

        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, tokensBN(10));
  
        const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,tokensBN(10));
  
        await expect(tx).to.be.revertedWith("Insufficient Funds or max ceiling reached")
      });

      it("should revert if allowance is greater than max fees", async function(){
        const CHANNEL_TYPE = 2;
  
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MAX_POOL_CONTRIBUTION.add(ADD_CHANNEL_MAX_POOL_CONTRIBUTION));
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MAX_POOL_CONTRIBUTION.add(ADD_CHANNEL_MAX_POOL_CONTRIBUTION));
  
        const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MAX_POOL_CONTRIBUTION.add(ADD_CHANNEL_MAX_POOL_CONTRIBUTION));
  
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

      // UPDATING CHANNEL DETAILS ON CHAIN
         it("should create a channel and set correct values", async function(){
        const CHANNEL_TYPE = 2;
      
        const channelsCountBefore = await EPNSCoreV1Proxy.channelsCount();

        const tx = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        const user = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).users(CHANNEL_CREATOR)
        const channel = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).channels(CHANNEL_CREATOR)

        const blockNumber = tx.blockNumber;
        const channelWeight = ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        const channelsCountAfter = await EPNSCoreV1Proxy.channelsCount();

        expect(user.channellized).to.equal(true);
        expect(channel.poolContribution).to.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        expect(channel.channelType).to.equal(CHANNEL_TYPE);
        expect(channel.channelStartBlock).to.equal(blockNumber);
        expect(channel.channelUpdateBlock).to.equal(blockNumber);
        expect(channel.channelWeight).to.equal(channelWeight);
        expect(await EPNSCoreV1Proxy.mapAddressChannels(channelsCountAfter.sub(1))).to.equal(CHANNEL_CREATOR);
        expect(channelsCountBefore.add(1)).to.equal(channelsCountAfter);
        expect(channel.memberCount.toNumber()).to.equal(1);
        expect(channel.deactivated).to.equal(false);
      });


      // // FS Ration Modifications should be as expected
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

      // Imperative Subscriptions while Creating Channels
    
      it("should subscribe creator to EPNS channel if new user", async function(){
        const CHANNEL_TYPE = 2;

        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
  
        const userSubscribed = await EPNSCoreV1Proxy.memberExists(CHANNEL_CREATOR, ADMIN);
        expect(userSubscribed).to.be.equal(true);

      });
  
      it("should subscribe them to EPNS Alerter as well", async function(){
        const CHANNEL_TYPE = 2;

        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
  
        const userSubscribed = await EPNSCoreV1Proxy.memberExists(CHANNEL_CREATOR, "0x0000000000000000000000000000000000000000");
        expect(userSubscribed).to.equal(true);
      });
  
      it("should subscribe creator to own channel", async function(){
        const CHANNEL_TYPE = 2;

        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
  
        const userSubscribed = await EPNSCoreV1Proxy.memberExists(CHANNEL_CREATOR, CHANNEL_CREATOR);
        expect(userSubscribed).to.equal(true);
      });

      // EVENT Related TEsts
      it("Should emit AddChannel event when creating channel", async function(){
        const CHANNEL_TYPE = 2;
  
        const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
  
        await expect(tx)
          .to.emit(EPNSCoreV1Proxy, 'AddChannel')
          .withArgs(CHANNEL_CREATOR, CHANNEL_TYPE, ethers.utils.hexlify(testChannel))
      });
    });


    /* "updateChannelMeta" Function CHECKPOINTS
     * Should only be executable by the Owner of the channel
     * Should revert if Channel is not a Activated One.
     * Channel's Member count should be exactly 1
     * Channel's channelUpdateBlock should be updated with the latest block number
     * Should emit relevant event
     **/

    describe("Testing updateChannelMeta", function(){
      const CHANNEL_TYPE = 2;
      
      beforeEach(async function(){
                  const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");


        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
      });

      it("Should only be executable by the Owner of the channel", async function () {
          const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

        const tx = EPNSCoreV1Proxy.connect(BOBSIGNER).updateChannelMeta(CHANNEL_CREATOR, testChannel);
        await expect(tx).to.be.revertedWith("Channel doesn't Exists");
      });

      it("Should revert if Channel is not a Activated One.", async function () {
               const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
        const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).updateChannelMeta(CHANNEL_CREATOR, testChannel);
        await expect(tx).to.be.revertedWith("Channel deactivated or doesn't exists");
      });

      it("should revert if Channel's Member count is more than One 1", async function () {
                const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

        await EPNSCoreV1Proxy.connect(BOBSIGNER).subscribe(CHANNEL_CREATOR);
        const channelDetails = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);
        const memberCount = channelDetails.memberCount;
        const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).updateChannelMeta(CHANNEL_CREATOR, testChannel);
        
        await expect(tx).to.be.revertedWith("Channel has external subscribers");
      });
  
      it("should update channel meta", async function () {
               const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

        const tx = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).updateChannelMeta(CHANNEL_CREATOR, testChannel);
        const channel = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).channels(CHANNEL_CREATOR);

        expect(channel.channelUpdateBlock.toNumber()).to.equal(tx.blockNumber);
      });

      it("should emit UpdateChannel if channel is updated", async function () {
                const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

        const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).updateChannelMeta(CHANNEL_CREATOR, testChannel);
  
        await expect(tx)
        .to.emit(EPNSCoreV1Proxy, 'UpdateChannel')
        .withArgs(CHANNEL_CREATOR, ethers.utils.hexlify(testChannel))
      });

    });


    /* "deactivateChannel" Function CHECKPOINTS
     * Should only be executable by the Owner of the channel
     * Should revert if Channel is not a Activated One.
     * Channel's Member count should be exactly 1
     * Channel's channelUpdateBlock should be updated with the latest block number
     * Should emit relevant event
     **/

    describe("Testing deactivateChannel", function(){
      const CHANNEL_TYPE = 2;
      
      beforeEach(async function(){
          const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");


        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
      });

      it("should revert if channel already deactivated", async function () {
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
        const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();

        await expect(tx).to.be.revertedWith("Channel deactivated or doesn't exists");
      });
  
      it("should deactivate channel", async function () {
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel();
  
        const channel = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).channels(CHANNEL_CREATOR);
        expect(channel[1]).to.equal(true);
      });
    });

    /* "createPromoterChannel" Function CHECKPOINTS
     * Should only be executable once.
     * Should create a promoter channel with right values on chain
     * Should update the FS Ratio as expected
     * Should conduct the Allowance based checks for Channel Creation Fees
     * Transfer of Channel Creation Fees from User to PROXY ADDress should be ensured
     * Deposit of DAI funds to AAVE and Receiving of aDAI should be checked
     **/

    describe("Testing createPromoterChannel", function(){

      beforeEach(async function(){
        await MOCKDAI.mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await MOCKDAI.approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
      });

      it("should create promoter channel", async function () {
        await EPNSCoreV1Proxy.createPromoterChannel({gasLimit: 2000000});

        const channel = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).channels(EPNSCoreV1Proxy.address);
        expect(channel[3].toNumber()).to.equal(1);
      });

      it("should create a promoter channel and set correct values", async function(){
        const CHANNEL_TYPE = 1;
        
        const channelsCountBefore = await EPNSCoreV1Proxy.channelsCount();

        const tx = await EPNSCoreV1Proxy.createPromoterChannel();
        const user = await EPNSCoreV1Proxy.users(EPNSCoreV1Proxy.address)
        const channel = await EPNSCoreV1Proxy.channels(EPNSCoreV1Proxy.address)

        const blockNumber = tx.blockNumber;
        const channelWeight = ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        const channelsCountAfter = await EPNSCoreV1Proxy.channelsCount();

        expect(user.channellized).to.equal(true);
        expect(channel.poolContribution).to.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        expect(channel.channelType).to.equal(CHANNEL_TYPE);
        expect(channel.channelStartBlock).to.equal(blockNumber);
        expect(channel.channelUpdateBlock).to.equal(blockNumber);
        expect(channel.channelWeight).to.equal(channelWeight);
        expect(await EPNSCoreV1Proxy.mapAddressChannels(channelsCountAfter.sub(1))).to.equal(EPNSCoreV1Proxy.address);
        expect(channelsCountBefore.add(1)).to.equal(channelsCountAfter);
        expect(channel.memberCount.toNumber()).to.equal(1);
        expect(channel.deactivated).to.equal(false);
      });

      it("should create a channel and update fair share values", async function(){
        const channelWeight = ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        const _groupFairShareCount = await EPNSCoreV1Proxy.groupFairShareCount();
        const _groupNormalizedWeight = await EPNSCoreV1Proxy.groupNormalizedWeight();
        const _groupHistoricalZ = await EPNSCoreV1Proxy.groupHistoricalZ();
        const _groupLastUpdate = await EPNSCoreV1Proxy.groupLastUpdate();

        const tx = await EPNSCoreV1Proxy.createPromoterChannel();
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
  
      it("should revert with error when creating channel twice", async function () {
        await EPNSCoreV1Proxy.createPromoterChannel({gasLimit: 2000000});
  
        const tx = EPNSCoreV1Proxy.createPromoterChannel({gasLimit: 2000000});
        await expect(tx).to.be.revertedWith("Contract has Promoter")
      });
  
      it("should revert if the allowance is not greater than minimum contribution", async function () {
        await MOCKDAI.decreaseAllowance(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        const tx = EPNSCoreV1Proxy.createPromoterChannel({gasLimit: 2000000});
        await expect(tx).to.be.revertedWith("subtraction overflow")
      });

      it("should emit AddChannel if channel is created", async function () {
        const tx = EPNSCoreV1Proxy.createPromoterChannel({gasLimit: 2000000});

        await expect(tx)
        .to.emit(EPNSCoreV1Proxy, 'AddChannel')
        .withArgs(EPNSCoreV1Proxy.address, 1, ethers.utils.hexlify(ethers.utils.toUtf8Bytes("1+QmRcewnNpdt2DWYuud3LxHTwox2RqQ8uyZWDJ6eY6iHkfn")))
      });

      it("should transfer given fees from creator account to proxy", async function(){
        const daiBalanceBefore = await MOCKDAI.balanceOf(ADMIN);

        await EPNSCoreV1Proxy.createPromoterChannel({gasLimit: 2000000});
  
        const daiBalanceAfter = await MOCKDAI.balanceOf(ADMIN);
        expect(daiBalanceBefore.sub(daiBalanceAfter)).to.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
      });

      it("should deposit funds to pool and receive aDAI", async function(){
        const poolFundsBefore = await EPNSCoreV1Proxy.poolFunds()
        const aDAIBalanceBefore = await ADAICONTRACT.balanceOf(EPNSCoreV1Proxy.address);
  
        await EPNSCoreV1Proxy.createPromoterChannel({gasLimit: 2000000});
  
        const poolFundsAfter = await EPNSCoreV1Proxy.poolFunds();
        const aDAIBalanceAfter = await ADAICONTRACT.balanceOf(EPNSCoreV1Proxy.address);

        expect(poolFundsAfter.sub(poolFundsBefore)).to.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        expect(aDAIBalanceAfter.sub(aDAIBalanceBefore)).to.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
      });
    });

    /* "createChannelWithFeesAndPublicKey" Function CHECKPOINTS
     * Should revert if User is already a CHannel
     * Should revert Channel Type is not the ALLOWED TYPES
     * Should conduct the Allowance based checks for Channel Creation Fees
     * Transfer of Channel Creation Fees from User to PROXY ADDress should be ensured
     * Deposit of DAI funds to AAVE and Receiving of aDAI should be checked
     * Should update User's Subscription details in the contract
     * Should update the Channel's Subscription Details in the contract
     * Should update the FAIRSHARE COUNTS
     * AddChannel Event should be emitted
     **/

   describe("Testing createChannelWithFeesAndPublicKey", function(){
       const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

      beforeEach(async function(){

        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
      });

      it("should revert on channel creation when User already a channel owner", async function () {
        const CHANNEL_TYPE = 2;

        const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFeesAndPublicKey(CHANNEL_TYPE, testChannel, publicKey.slice(1), ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

        const CHANNEL_TYPE_SECOND = 3;
        const testChannelSecond = ethers.utils.toUtf8Bytes("test-channel-hello-world-two");

        const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFeesAndPublicKey(CHANNEL_TYPE_SECOND, testChannelSecond, publicKey.slice(1), ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
  
        await expect(tx).to.be.revertedWith("User already a Channel Owner")
      });

      it("should revert on channel creation when user not allowed channel type", async function () {
        const CHANNEL_TYPE = 0;
        
        const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)
        const tx1 = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFeesAndPublicKey(CHANNEL_TYPE, testChannel, publicKey.slice(1), ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

        await expect(tx1).to.be.revertedWith("Channel Type Invalid")

        const CHANNEL_TYPE_SECOND = 1;
        
        const testChannelSecond = ethers.utils.toUtf8Bytes("test-channel-hello-world-two");

        const tx2 = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFeesAndPublicKey(CHANNEL_TYPE_SECOND, testChannelSecond, publicKey.slice(1), ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
  
        await expect(tx2).to.be.revertedWith("Channel Type Invalid")
      });

      it("Should broadcast user public key when creating channel", async function(){
        const CHANNEL_TYPE = 2;
        
        const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)
        const tx = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFeesAndPublicKey(CHANNEL_TYPE, testChannel, publicKey.slice(1), ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        const user = await EPNSCoreV1Proxy.users(CHANNEL_CREATOR)

        expect(user.publicKeyRegistered).to.equal(true);
      });

      it("should emit PublicKeyRegistered event when user public key is not registered", async function(){
        const CHANNEL_TYPE = 2;

        const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)
        const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFeesAndPublicKey(CHANNEL_TYPE, testChannel, publicKey.slice(1), ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

        await expect(tx)
          .to.emit(EPNSCoreV1Proxy, 'PublicKeyRegistered')
          .withArgs(CHANNEL_CREATOR, ethers.utils.hexlify(publicKey.slice(1)))
      });

      it("Should not broadcast user public key twice", async function(){
        const CHANNEL_TYPE = 2;
        
        const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)
        
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).broadcastUserPublicKey(publicKey.slice(1));

        const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFeesAndPublicKey(CHANNEL_TYPE, testChannel, publicKey.slice(1), ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

        await expect(tx)
        .to.not.emit(EPNSCoreV1Proxy, 'PublicKeyRegistered')
        .withArgs(CHANNEL_CREATOR, ethers.utils.hexlify(publicKey.slice(1)))
      });

      it("Should revert if broadcast user public does not match with sender address", async function(){
        const CHANNEL_TYPE = 2;
                
        const publicKey = await getPubKey(BOBSIGNER)
        const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFeesAndPublicKey(CHANNEL_TYPE, testChannel, publicKey.slice(1), ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

        await expect(tx).to.be.revertedWith("Public Key Validation Failed")
      });

      it("Should update relevant details after broadcast public key", async function(){
        const CHANNEL_TYPE = 2;

        const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)

        const usersCountBefore = await EPNSCoreV1Proxy.usersCount()
        const tx = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFeesAndPublicKey(CHANNEL_TYPE, testChannel, publicKey.slice(1), ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        
        const user = await EPNSCoreV1Proxy.users(CHANNEL_CREATOR);
        const usersCountAfter = await EPNSCoreV1Proxy.usersCount()

        expect(user.userStartBlock).to.equal(tx.blockNumber);
        expect(user.userActivated).to.equal(true);
        expect(usersCountBefore.add(1)).to.equal(usersCountAfter);
      });

      it("should create a channel when added to whitelist", async function(){
        const CHANNEL_TYPE = 2;

        const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFeesAndPublicKey(CHANNEL_TYPE, testChannel, publicKey.slice(1), ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

        const channel = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).channels(CHANNEL_CREATOR)
        expect(channel[3].toNumber()).to.equal(1);
      });

      it("should create a channel and set correct values", async function(){
        const CHANNEL_TYPE = 2;
        
        const channelsCountBefore = await EPNSCoreV1Proxy.channelsCount();

        const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)
        const tx = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFeesAndPublicKey(CHANNEL_TYPE, testChannel, publicKey.slice(1), ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        const user = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).users(CHANNEL_CREATOR)
        const channel = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).channels(CHANNEL_CREATOR)

        const blockNumber = tx.blockNumber;
        const channelWeight = ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        const channelsCountAfter = await EPNSCoreV1Proxy.channelsCount();

        expect(user.channellized).to.equal(true);
        expect(channel.poolContribution).to.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        expect(channel.channelType).to.equal(CHANNEL_TYPE);
        expect(channel.channelStartBlock).to.equal(blockNumber);
        expect(channel.channelUpdateBlock).to.equal(blockNumber);
        expect(channel.channelWeight).to.equal(channelWeight);
        expect(await EPNSCoreV1Proxy.mapAddressChannels(channelsCountAfter.sub(1))).to.equal(CHANNEL_CREATOR);
        expect(channelsCountBefore.add(1)).to.equal(channelsCountAfter);
        expect(channel.memberCount.toNumber()).to.equal(1);
        expect(channel.deactivated).to.equal(false);
      });

      it("should create a channel and update fair share values", async function(){
        const CHANNEL_TYPE = 2;

        const channelWeight = ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        const _groupFairShareCount = await EPNSCoreV1Proxy.groupFairShareCount();
        const _groupNormalizedWeight = await EPNSCoreV1Proxy.groupNormalizedWeight();
        const _groupHistoricalZ = await EPNSCoreV1Proxy.groupHistoricalZ();
        const _groupLastUpdate = await EPNSCoreV1Proxy.groupLastUpdate();

        const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)
        const tx = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFeesAndPublicKey(CHANNEL_TYPE, testChannel, publicKey.slice(1), ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
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

      it("should emit AddChannel event when creating channel", async function(){
        const CHANNEL_TYPE = 2;
        
        const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)
        const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFeesAndPublicKey(CHANNEL_TYPE, testChannel, publicKey.slice(1), ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
  
        await expect(tx)
          .to.emit(EPNSCoreV1Proxy, 'AddChannel')
          .withArgs(CHANNEL_CREATOR, CHANNEL_TYPE, ethers.utils.hexlify(testChannel));
      });
  
      it("should revert if allowance is not greater than min fees", async function(){
        const CHANNEL_TYPE = 2;
        
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, tokensBN(10));
  
        const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)
        const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFeesAndPublicKey(CHANNEL_TYPE, testChannel, publicKey.slice(1),  tokensBN(10));
  
        await expect(tx).to.be.revertedWith("Insufficient Funds or max ceiling reached")
      });

      it("should revert if allowance is greater than max fees", async function(){
        const CHANNEL_TYPE = 2;
  
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MAX_POOL_CONTRIBUTION.add(ADD_CHANNEL_MAX_POOL_CONTRIBUTION));
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MAX_POOL_CONTRIBUTION.add(ADD_CHANNEL_MAX_POOL_CONTRIBUTION));
  
        const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)
        const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFeesAndPublicKey(CHANNEL_TYPE, testChannel, publicKey.slice(1), ADD_CHANNEL_MAX_POOL_CONTRIBUTION.add(ADD_CHANNEL_MAX_POOL_CONTRIBUTION));
  
        await expect(tx).to.be.revertedWith("Insufficient Funds or max ceiling reached")
      });
  
      it("should transfer given fees from creator account to proxy", async function(){
        const CHANNEL_TYPE = 2;
  
        const daiBalanceBefore = await MOCKDAI.connect(CHANNEL_CREATORSIGNER).balanceOf(CHANNEL_CREATOR);
  
        const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFeesAndPublicKey(CHANNEL_TYPE, testChannel, publicKey.slice(1), ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
  
        const daiBalanceAfter = await MOCKDAI.connect(CHANNEL_CREATORSIGNER).balanceOf(CHANNEL_CREATOR);
        expect(daiBalanceBefore.sub(daiBalanceAfter)).to.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
      })
  
      it("should deposit funds to pool and receive aDAI", async function(){
        const CHANNEL_TYPE = 2;
      
        const poolFundsBefore = await EPNSCoreV1Proxy.poolFunds()
        const aDAIBalanceBefore = await ADAICONTRACT.balanceOf(EPNSCoreV1Proxy.address);
  
        const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFeesAndPublicKey(CHANNEL_TYPE, testChannel, publicKey.slice(1), ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
  
        const poolFundsAfter = await EPNSCoreV1Proxy.poolFunds();
        const aDAIBalanceAfter = await ADAICONTRACT.balanceOf(EPNSCoreV1Proxy.address);

        expect(poolFundsAfter.sub(poolFundsBefore)).to.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        expect(aDAIBalanceAfter.sub(aDAIBalanceBefore)).to.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
      });

// Functionality REMOVED from protocol

    // it("should subscribe creator to EPNS channel if new user", async function(){
    //     const CHANNEL_TYPE = 2;
    //     const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)

    //     await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
    //     await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

    //     await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFeesAndPublicKey(CHANNEL_TYPE, testChannel, publicKey.slice(1), ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
  
    //     const userSubscribed = await EPNSCoreV1Proxy.memberExists(CHANNEL_CREATOR, ADMIN);
    //     expect(userSubscribed).to.be.equal(true);

    //   });
  
      it("should subscribe them to EPNS Alerter as well", async function(){
        const CHANNEL_TYPE = 2;
        const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)

        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFeesAndPublicKey(CHANNEL_TYPE, testChannel, publicKey.slice(1), ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
  
        const userSubscribed = await EPNSCoreV1Proxy.memberExists(CHANNEL_CREATOR, "0x0000000000000000000000000000000000000000");
        expect(userSubscribed).to.equal(true);
      });
  
      it("should subscribe creator to own channel", async function(){
        const CHANNEL_TYPE = 2;
        const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)

        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFeesAndPublicKey(CHANNEL_TYPE, testChannel, publicKey.slice(1), ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
  
        const userSubscribed = await EPNSCoreV1Proxy.memberExists(CHANNEL_CREATOR, CHANNEL_CREATOR);
        expect(userSubscribed).to.equal(true);
      });

      it("should subscribe creator to own channel", async function(){
        const CHANNEL_TYPE = 2;
  
        const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFeesAndPublicKey(CHANNEL_TYPE, testChannel, publicKey.slice(1), ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
  
        const userSubscribed = await EPNSCoreV1Proxy.memberExists(CHANNEL_CREATOR, CHANNEL_CREATOR);
        expect(userSubscribed).to.equal(true);
      });
    });

});
});