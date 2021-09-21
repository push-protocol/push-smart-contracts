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

describe("EPNS CORE Protocol ", function () {

  const DAI = "0xf80A32A835F79D7787E8a8ee5721D0fEaFd78108";
  const ADAI = "0xcB1Fe6F440c49E9290c3eb7f158534c2dC374201";
  const WETH = "0xc778417E063141139Fce010982780140Aa0cD5Ab";
  const UNISWAP_ROUTER = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
  const AAVE_LENDING_POOL = "0x1c8756FD2B28e9426CDBDcC7E3c4d64fa9A54728";

  const referralCode = 0;
  const ADD_CHANNEL_MIN_POOL_CONTRIBUTION = tokensBN(50)
  const ADD_CHANNEL_MAX_POOL_CONTRIBUTION = tokensBN(2500)
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


 describe("EPNS CORE: Channel Data Migration Tests", function(){

    // SUBSCRIBE RELATED TESTS
  describe("Testing migrateChannelData FUnction", function()
      {
          const CHANNEL_TYPE = 2;
          const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");


           beforeEach(async function(){
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
            await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
            await MOCKDAI.connect(ADMINSIGNER).mint(ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
            await MOCKDAI.connect(ADMINSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MAX_POOL_CONTRIBUTION);
         });

           /*
             * 'migrateChannelData' Function CHECKPOINTS
             * Should revert if Caller is Not the ADMIN of the Contracty
             * Should revert if 'isMigrationComplete' flag is TRUE
             * Should revert if Unequal Arrays are passed as Arguments
             *
             * Function Execution BODY
             * -> Dai should be deposited by the ADMIN Itself
             * -> Accurate amount of DAI should be deposited from ADMIN to the EPNSCore Proxy for the Channel Owners
             * ->_depositFundsToPool' function should be executed as expected.
             * -> Channel should be created for the Channel owners with the Correct inputs
             *
            */

            it("Should revert if Admin is Not the Caller" , async ()=>{
                const startIndex = 0;
                const endIndex = 4;
                const channelTypeArray = [2,2,2,2];
                const channelArray = [CHANNEL_CREATOR, BOB, CHARLIE, USER1];
                const identityArray = [testChannel, testChannel, testChannel, testChannel]
                const amountArray = [ADD_CHANNEL_MIN_POOL_CONTRIBUTION, ADD_CHANNEL_MIN_POOL_CONTRIBUTION, ADD_CHANNEL_MIN_POOL_CONTRIBUTION, ADD_CHANNEL_MIN_POOL_CONTRIBUTION]

               const tx = EPNSCoreV1Proxy.connect(BOBSIGNER).migrateChannelData(startIndex, endIndex, channelArray, channelTypeArray, identityArray, amountArray);

               await expect(tx).to.be.revertedWith('EPNSCoreV1::onlyPushChannelAdmin: Caller not pushChannelAdmin');
            })

            it("Should revert  if 'isMigrationComplete' flag is TRUE " , async ()=>{
                const startIndex = 0;
                const endIndex = 4;
                const channelTypeArray = [2,2,2,2];
                const channelArray = [CHANNEL_CREATOR, BOB, CHARLIE, USER1];
                const identityArray = [testChannel, testChannel, testChannel, testChannel]
                const amountArray = [ADD_CHANNEL_MIN_POOL_CONTRIBUTION, ADD_CHANNEL_MIN_POOL_CONTRIBUTION, ADD_CHANNEL_MIN_POOL_CONTRIBUTION, ADD_CHANNEL_MIN_POOL_CONTRIBUTION]

                const isMigrationComplete_before = await EPNSCoreV1Proxy.isMigrationComplete();
                await EPNSCoreV1Proxy.connect(ADMINSIGNER).setMigrationComplete();
                const isMigrationComplete_after = await EPNSCoreV1Proxy.isMigrationComplete();

               const tx = EPNSCoreV1Proxy.connect(ADMINSIGNER).migrateChannelData(startIndex, endIndex, channelArray, channelTypeArray, identityArray, amountArray);

               expect(isMigrationComplete_before).to.equal(false);
               expect(isMigrationComplete_after).to.equal(true);
               await expect(tx).to.be.revertedWith('EPNSCoreV1::migrateChannelData: Migration is already done');
            })


            it("Should revert  if Unequal Arrays are passed as an Argument" , async ()=>{
                const startIndex = 0;
                const endIndex = 4;
                const channelTypeArray = [2, 2, 2];
                const channelArray = [CHANNEL_CREATOR, BOB, CHARLIE, USER1, USER2];
                const identityArray = [testChannel, testChannel, testChannel, testChannel]
                const amountArray = [ADD_CHANNEL_MIN_POOL_CONTRIBUTION, ADD_CHANNEL_MIN_POOL_CONTRIBUTION, ADD_CHANNEL_MIN_POOL_CONTRIBUTION, ADD_CHANNEL_MIN_POOL_CONTRIBUTION]


               const tx = EPNSCoreV1Proxy.connect(ADMINSIGNER).migrateChannelData(startIndex, endIndex, channelArray, channelTypeArray, identityArray, amountArray);

               await expect(tx).to.be.revertedWith('EPNSCoreV1::migrateChannelData: Unequal Arrays passed as Argument');
            })

          it("Migration should transfer the Right Amount of DAI to EPNS PROXY from ADMIN's Balance", async function(){
             const startIndex = 0;
             const endIndex = 4;
             const channelTypeArray = [2,2,2,2];
             const channelArray = [CHANNEL_CREATOR, BOB, CHARLIE, USER1];
             const identityArray = [testChannel, testChannel, testChannel, testChannel]
             const amountArray = [ADD_CHANNEL_MIN_POOL_CONTRIBUTION, ADD_CHANNEL_MIN_POOL_CONTRIBUTION, ADD_CHANNEL_MIN_POOL_CONTRIBUTION, ADD_CHANNEL_MIN_POOL_CONTRIBUTION]
             const totalDaiDepsitedByAdmin = tokensBN(200);

            const daiBalanceBefore = await MOCKDAI.connect(ADMINSIGNER).balanceOf(ADMIN);

            await EPNSCoreV1Proxy.connect(ADMINSIGNER).migrateChannelData(startIndex, endIndex, channelArray, channelTypeArray, identityArray, amountArray);

            const daiBalanceAfter = await MOCKDAI.connect(ADMINSIGNER).balanceOf(ADMIN);
            expect(daiBalanceBefore.sub(daiBalanceAfter)).to.equal(totalDaiDepsitedByAdmin);
          }).timeout(5000);

          it("Migration function should deposit funds to pool and receive aDAI", async function(){
             const startIndex = 0;
             const endIndex = 4;
             const channelTypeArray = [2,2,2,2];
             const channelArray = [CHANNEL_CREATOR, BOB, CHARLIE, USER1];
             const identityArray = [testChannel, testChannel, testChannel, testChannel]
             const amountArray = [ADD_CHANNEL_MIN_POOL_CONTRIBUTION, ADD_CHANNEL_MIN_POOL_CONTRIBUTION, ADD_CHANNEL_MIN_POOL_CONTRIBUTION, ADD_CHANNEL_MIN_POOL_CONTRIBUTION]
             const totalDaiDepsitedByAdmin = tokensBN(200);

            const POOL_FUNDSBefore = await EPNSCoreV1Proxy.POOL_FUNDS()
            const aDAIBalanceBefore = await ADAICONTRACT.balanceOf(EPNSCoreV1Proxy.address);

            await EPNSCoreV1Proxy.connect(ADMINSIGNER).migrateChannelData(startIndex, endIndex, channelArray, channelTypeArray, identityArray, amountArray);

            const POOL_FUNDSAfter = await EPNSCoreV1Proxy.POOL_FUNDS();
            const aDAIBalanceAfter = await ADAICONTRACT.balanceOf(EPNSCoreV1Proxy.address);

            expect(POOL_FUNDSAfter.sub(POOL_FUNDSBefore)).to.equal(totalDaiDepsitedByAdmin);
            expect(aDAIBalanceAfter.sub(aDAIBalanceBefore)).to.equal(totalDaiDepsitedByAdmin);
          });

        it("EPNS Core Should create Channel and Update Relevant State variables accordingly", async function(){
            const startIndex = 0;
            const endIndex = 4;
            const channelTypeArray = [2,2,2,2];
            const channelArray = [CHANNEL_CREATOR, BOB, CHARLIE, USER1];
            const identityArray = [testChannel, testChannel, testChannel, testChannel]
            const amountArray = [ADD_CHANNEL_MIN_POOL_CONTRIBUTION, ADD_CHANNEL_MIN_POOL_CONTRIBUTION, ADD_CHANNEL_MIN_POOL_CONTRIBUTION, ADD_CHANNEL_MIN_POOL_CONTRIBUTION]

          const channelsCountBefore = await EPNSCoreV1Proxy.channelsCount();

          const tx = await EPNSCoreV1Proxy.connect(ADMINSIGNER).migrateChannelData(startIndex, endIndex, channelArray, channelTypeArray, identityArray, amountArray);

          const channelForBOB = await EPNSCoreV1Proxy.channels(BOB)
          const channelForUSER1 = await EPNSCoreV1Proxy.channels(USER1)
          const channelForCHARLIE = await EPNSCoreV1Proxy.channels(CHARLIE)
          const channelForChannelCreator = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR)

          const blockNumber = tx.blockNumber;
          const channelWeight = ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          const channelsCountAfter = await EPNSCoreV1Proxy.channelsCount();

          //BOB's DETAILS
          expect(channelForBOB.channelState).to.equal(1);
          expect(channelForBOB.poolContribution).to.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          expect(channelForBOB.channelType).to.equal(CHANNEL_TYPE);
          expect(channelForBOB.channelStartBlock).to.equal(blockNumber);
          expect(channelForBOB.channelUpdateBlock).to.equal(blockNumber);
          expect(channelForBOB.channelWeight).to.equal(channelWeight);

          // USER1 DETAILS
          expect(channelForUSER1.channelState).to.equal(1);
          expect(channelForUSER1.poolContribution).to.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          expect(channelForUSER1.channelType).to.equal(CHANNEL_TYPE);
          expect(channelForUSER1.channelStartBlock).to.equal(blockNumber);
          expect(channelForUSER1.channelUpdateBlock).to.equal(blockNumber);
          expect(channelForUSER1.channelWeight).to.equal(channelWeight);

          // CHARLIE's DETAILS
          expect(channelForCHARLIE.channelState).to.equal(1);
          expect(channelForCHARLIE.poolContribution).to.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          expect(channelForCHARLIE.channelType).to.equal(CHANNEL_TYPE);
          expect(channelForCHARLIE.channelStartBlock).to.equal(blockNumber);
          expect(channelForCHARLIE.channelUpdateBlock).to.equal(blockNumber);
          expect(channelForCHARLIE.channelWeight).to.equal(channelWeight);

          // CHARLIE's DETAILS
          expect(channelForChannelCreator.channelState).to.equal(1);
          expect(channelForChannelCreator.poolContribution).to.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          expect(channelForChannelCreator.channelType).to.equal(CHANNEL_TYPE);
          expect(channelForChannelCreator.channelStartBlock).to.equal(blockNumber);
          expect(channelForChannelCreator.channelUpdateBlock).to.equal(blockNumber);
          expect(channelForChannelCreator.channelWeight).to.equal(channelWeight);

          expect(channelsCountBefore).to.equal(0)
          expect(channelsCountAfter).to.equal(4)
        }).timeout(10000);

        it("EPNS Core Should Interact with EPNS Communcator and make the necessary Subscriptions", async function(){
          const startIndex = 0;
          const endIndex = 4;
          const EPNS_ALERTER = '0x0000000000000000000000000000000000000000';

          const channelTypeArray = [2,2,2,2];
          const channelArray = [CHANNEL_CREATOR, BOB, CHARLIE, USER1];
          const identityArray = [testChannel, testChannel, testChannel, testChannel]
          const amountArray = [ADD_CHANNEL_MIN_POOL_CONTRIBUTION, ADD_CHANNEL_MIN_POOL_CONTRIBUTION, ADD_CHANNEL_MIN_POOL_CONTRIBUTION, ADD_CHANNEL_MIN_POOL_CONTRIBUTION]

          const isChannelOwnerSubscribed_before = await EPNSCommV1Proxy.isUserSubscribed(CHANNEL_CREATOR, CHANNEL_CREATOR);
          const isChannelSubscribedToEPNS_before = await EPNSCommV1Proxy.isUserSubscribed(EPNS_ALERTER, CHANNEL_CREATOR);
          const isAdminSubscribedToChannel_before = await EPNSCommV1Proxy.isUserSubscribed(CHANNEL_CREATOR, ADMIN);

          const isBOBSubscribed_before = await EPNSCommV1Proxy.isUserSubscribed(BOB, BOB);
          const isBOBSubscribedToEPNS_before = await EPNSCommV1Proxy.isUserSubscribed(EPNS_ALERTER, BOB);
          const isAdminSubscribedToBOB_before = await EPNSCommV1Proxy.isUserSubscribed(BOB, ADMIN);

          const isCHARLIESubscribed_before = await EPNSCommV1Proxy.isUserSubscribed(CHARLIE, CHARLIE);
          const isCHARLIESubscribedToEPNS_before = await EPNSCommV1Proxy.isUserSubscribed(EPNS_ALERTER, CHARLIE);
          const isAdminSubscribedToCHARLIE_before = await EPNSCommV1Proxy.isUserSubscribed(CHARLIE, ADMIN);

          const isUSER1Subscribed_before = await EPNSCommV1Proxy.isUserSubscribed(USER1, USER1);
          const isUSER1SubscribedToEPNS_before = await EPNSCommV1Proxy.isUserSubscribed(EPNS_ALERTER, USER1);
          const isAdminSubscribedToUSER1_before = await EPNSCommV1Proxy.isUserSubscribed(USER1, ADMIN);

          await EPNSCoreV1Proxy.connect(ADMINSIGNER).migrateChannelData(startIndex, endIndex, channelArray, channelTypeArray, identityArray, amountArray);

          const isChannelOwnerSubscribed_after = await EPNSCommV1Proxy.isUserSubscribed(CHANNEL_CREATOR, CHANNEL_CREATOR);
          const isChannelSubscribedToEPNS_after = await EPNSCommV1Proxy.isUserSubscribed(EPNS_ALERTER, CHANNEL_CREATOR);
          const isAdminSubscribedToChannel_after = await EPNSCommV1Proxy.isUserSubscribed(CHANNEL_CREATOR, ADMIN);

          const isBOBSubscribed_after = await EPNSCommV1Proxy.isUserSubscribed(BOB, BOB);
          const isBOBSubscribedToEPNS_after = await EPNSCommV1Proxy.isUserSubscribed(EPNS_ALERTER, BOB);
          const isAdminSubscribedToBOB_after = await EPNSCommV1Proxy.isUserSubscribed(BOB, ADMIN);

          const isCHARLIESubscribed_after = await EPNSCommV1Proxy.isUserSubscribed(CHARLIE, CHARLIE);
          const isCHARLIESubscribedToEPNS_after = await EPNSCommV1Proxy.isUserSubscribed(EPNS_ALERTER, CHARLIE);
          const isAdminSubscribedToCHARLIE_after = await EPNSCommV1Proxy.isUserSubscribed(CHARLIE, ADMIN);

          const isUSER1Subscribed_after = await EPNSCommV1Proxy.isUserSubscribed(USER1, USER1);
          const isUSER1SubscribedToEPNS_after = await EPNSCommV1Proxy.isUserSubscribed(EPNS_ALERTER, USER1);
          const isAdminSubscribedToUSER1_after = await EPNSCommV1Proxy.isUserSubscribed(USER1, ADMIN);


          //USER1's Details
          await expect(isUSER1Subscribed_before).to.equal(false);
          await expect(isUSER1SubscribedToEPNS_before).to.equal(false);
          await expect(isAdminSubscribedToUSER1_before).to.equal(false);

          await expect(isUSER1Subscribed_after).to.equal(true);
          await expect(isUSER1SubscribedToEPNS_after).to.equal(true);
          await expect(isAdminSubscribedToUSER1_after).to.equal(true);

          //CHARLIE's Details
          await expect(isCHARLIESubscribed_before).to.equal(false);
          await expect(isCHARLIESubscribedToEPNS_before).to.equal(false);
          await expect(isAdminSubscribedToCHARLIE_before).to.equal(false);

          await expect(isCHARLIESubscribed_after).to.equal(true);
          await expect(isCHARLIESubscribedToEPNS_after).to.equal(true);
          await expect(isAdminSubscribedToCHARLIE_after).to.equal(true);

          //Channel Creator's Details
          await expect(isChannelOwnerSubscribed_before).to.equal(false);
          await expect(isChannelSubscribedToEPNS_before).to.equal(false);
          await expect(isAdminSubscribedToChannel_before).to.equal(false);
          await expect(isChannelOwnerSubscribed_after).to.equal(true);
          await expect(isChannelSubscribedToEPNS_after).to.equal(true);
          await expect(isAdminSubscribedToChannel_after).to.equal(true);

            //BOB's Details
          await expect(isBOBSubscribed_before).to.equal(false);
          await expect(isBOBSubscribedToEPNS_before).to.equal(false);
          await expect(isAdminSubscribedToBOB_before).to.equal(false);
          await expect(isBOBSubscribed_after).to.equal(true);
          await expect(isBOBSubscribedToEPNS_after).to.equal(true);
          await expect(isAdminSubscribedToBOB_after).to.equal(true);

        }).timeout(10000);

         it("should create a channel and update fair share values", async function(){
          const startIndex = 0;
          const endIndex = 4;
          const channelTypeArray = [2,2,2,2];
          const channelArray = [CHANNEL_CREATOR, BOB, CHARLIE, USER1];
          const identityArray = [testChannel, testChannel, testChannel, testChannel]
          const amountArray = [ADD_CHANNEL_MIN_POOL_CONTRIBUTION, ADD_CHANNEL_MIN_POOL_CONTRIBUTION, ADD_CHANNEL_MIN_POOL_CONTRIBUTION, ADD_CHANNEL_MIN_POOL_CONTRIBUTION]

          const channelWeight = ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
          const _groupFairShareCount = await EPNSCoreV1Proxy.groupFairShareCount();
          const _groupNormalizedWeight = await EPNSCoreV1Proxy.groupNormalizedWeight();
          const _groupHistoricalZ = await EPNSCoreV1Proxy.groupHistoricalZ();
          const _groupLastUpdate = await EPNSCoreV1Proxy.groupLastUpdate();

          const tx = await EPNSCoreV1Proxy.connect(ADMINSIGNER).migrateChannelData(startIndex, endIndex, channelArray, channelTypeArray, identityArray, amountArray);
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

          expect(_groupFairShareCountNew).to.equal(4);
          expect(_groupNormalizedWeightNew).to.equal(groupNewNormalizedWeight);
          expect(_groupHistoricalZNew).to.equal(groupNewHistoricalZ);
          expect(_groupLastUpdateNew).to.equal(groupNewLastUpdate);
        });

    });

});
});
