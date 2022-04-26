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

  const CHAIN_NAME = 'ROPSTEN'; // MAINNET, MATIC etc.
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

    const proxyAdmin = await ethers.getContractFactory("EPNSCoreAdmin");
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
    EPNSCommunicatorV1Proxy = EPNSCommunicator.attach(EPNSCommProxy.address)

  });

  afterEach(function () {
    EPNS = null
    CORE_LOGIC = null
    TIMELOCK = null
    EPNSCoreProxy = null
    EPNSCoreV1Proxy = null
  });


 describe("EPNS COMMUNICATOR: Subscription Data Migration Tests", function(){

  describe("Testing migrateSubscribeData FUnction", function()
      {
          const CHANNEL_TYPE = 2;
          const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");


           beforeEach(async function(){
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommunicatorV1Proxy.address)
            await EPNSCommunicatorV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
         });

           /*
             * 'migrateSubscribeData' Function CHECKPOINTS
             * Should revert if Caller is Not the ADMIN of the Contracty
             * Should revert if 'isMigrationComplete' flag is TRUE
             * Should revert if Unequal Arrays are passed as Arguments
             * Should revert if Same Subscribe-To-Channel Data is passed Twice
             *
             * Function Execution BODY
             * 'addUser' function should be executed properly
             *          -> userStartBlock should be assigned with the right Block number
             *          -> userActivated should be marked TRUE
             *          -> mapAddressUsers mapping should be updated
             *          -> User's count in the protocol should be increased
             *
             * In the '_subscribe' function:
             *         -> 'isSubscribed' for user and Channel should be updated to '1'
             *         -> subscribed mapping should be updated with User's Current subscribe count
             *         -> subscribedCount variable for user should increase by 1
             *
            */

            it("Should revert if Admin is Not the Caller" , async ()=>{
                const startIndex = 0;
                const endIndex = 3;
                const userArray = [USER2, CHARLIE, USER1]
                const channelArray = [CHANNEL_CREATOR, BOB, CHARLIE]
               const tx = EPNSCommunicatorV1Proxy.connect(BOBSIGNER).migrateSubscribeData(startIndex, endIndex, channelArray, userArray);

               await expect(tx).to.be.revertedWith('EPNSCommV1::onlyPushChannelAdmin: user not pushChannelAdmin');
            })

              it("Should revert Function is being called after MIGRATION is COMPLETED" , async ()=>{
                const startIndex = 0;
                const endIndex = 3;
               const userArray = [USER2, CHARLIE, USER1]
               const channelArray = [CHANNEL_CREATOR, BOB, CHARLIE]
               const migrationCompleteFlag_before = await EPNSCommunicatorV1Proxy.isMigrationComplete();

               await EPNSCommunicatorV1Proxy.connect(ADMINSIGNER).completeMigration();

               const migrationCompleteFlag_after = await EPNSCommunicatorV1Proxy.isMigrationComplete();
               const tx = EPNSCommunicatorV1Proxy.connect(ADMINSIGNER).migrateSubscribeData(startIndex, endIndex, channelArray, userArray);

               expect(migrationCompleteFlag_before).to.equal(false);
               expect(migrationCompleteFlag_after).to.equal(true);
               await expect(tx).to.be.revertedWith('EPNSCommV1::migrateSubscribeData: Migration of Subscribe Data is Complete Already');
            })

            it("Should revert if Unequal Array of Argument is PAssed" , async ()=>{
                const startIndex = 0;
                const endIndex = 3;
                const channelArray = [CHANNEL_CREATOR, BOB, CHARLIE]
                const wrong_userArray = [USER2, CHARLIE, USER1, BOB]

                const tx =  EPNSCommunicatorV1Proxy.connect(ADMINSIGNER).migrateSubscribeData(startIndex, endIndex, channelArray, wrong_userArray);
               await expect(tx).to.be.revertedWith('EPNSCommV1::migrateSubscribeData: Unequal Arrays passed as Argument');
            })

            it("Should SKIP similar Subscribe-To-Channel Data is passed Twice" , async ()=>{
                const startIndex = 0;
                const endIndex = 3;
                const wrong_userArray = [USER2, CHARLIE, USER2]
                const wrong_channelArray = [CHANNEL_CREATOR, BOB, CHANNEL_CREATOR]

                const tx =  EPNSCommunicatorV1Proxy.connect(ADMINSIGNER).migrateSubscribeData(startIndex, endIndex, wrong_channelArray, wrong_userArray);
            })


            it("Function should Execute the 'addUser' function adequately", async() =>{
                const startIndex = 0;
                const endIndex = 3;
                const userArray = [USER2, CHARLIE, USER1]
                const channelArray = [CHANNEL_CREATOR, BOB, CHARLIE]

                const USER2Details_before = await EPNSCommunicatorV1Proxy.users(USER2);
                const CHARLIEDetails_before = await EPNSCommunicatorV1Proxy.users(CHARLIE);
                const USER1Details_before = await EPNSCommunicatorV1Proxy.users(USER1);

                const userCount_before  = await EPNSCommunicatorV1Proxy.usersCount();

                await EPNSCommunicatorV1Proxy.connect(ADMINSIGNER).migrateSubscribeData(startIndex, endIndex, channelArray, userArray);


                 const USER2Details_after = await EPNSCommunicatorV1Proxy.users(USER2);
                const CHARLIEDetails_after = await EPNSCommunicatorV1Proxy.users(CHARLIE);
                const USER1Details_after = await EPNSCommunicatorV1Proxy.users(USER1);

                const userCount_after  = await EPNSCommunicatorV1Proxy.usersCount();

                await expect(userCount_before.toNumber()).to.equal(2);
                await expect(userCount_after.toNumber()).to.equal(5);
                // USER2's DETAILS
                await expect(USER2Details_before.userActivated).to.equal(false);
                await expect(USER2Details_after.userActivated).to.equal(true);
                // Charlie's DETAILS
                await expect(CHARLIEDetails_before.userActivated).to.equal(false);
                await expect(CHARLIEDetails_after.userActivated).to.equal(true);
                // USER1's Details
                await expect(USER1Details_before.userActivated).to.equal(false);
                await expect(USER1Details_after.userActivated).to.equal(true);
             })

            it("Function should Execute and Update State Variables adequately", async() =>{
                const startIndex = 0;
                const endIndex = 3;
                const userArray = [USER2, CHARLIE, USER1]
                const channelArray = [CHANNEL_CREATOR, BOB, CHARLIE]

                const USER2Details_before = await EPNSCommunicatorV1Proxy.users(USER2);
                const CHARLIEDetails_before = await EPNSCommunicatorV1Proxy.users(CHARLIE);
                const USER1Details_before = await EPNSCommunicatorV1Proxy.users(USER1);

                const isUSER2Subscribed_before = await EPNSCommunicatorV1Proxy.isUserSubscribed(CHANNEL_CREATOR, USER2);
                const isCHARLIESubscribed_before = await EPNSCommunicatorV1Proxy.isUserSubscribed(BOB, CHARLIE);
                const isUSER1Subscribed_before = await EPNSCommunicatorV1Proxy.isUserSubscribed(CHARLIE, USER1);

                await EPNSCommunicatorV1Proxy.connect(ADMINSIGNER).migrateSubscribeData(startIndex, endIndex, channelArray, userArray);

                const USER2Details_after = await EPNSCommunicatorV1Proxy.users(USER2);
                const CHARLIEDetails_after = await EPNSCommunicatorV1Proxy.users(CHARLIE);
                const USER1Details_after = await EPNSCommunicatorV1Proxy.users(USER1);

                const isUSER2Subscribed_after = await EPNSCommunicatorV1Proxy.isUserSubscribed(CHANNEL_CREATOR, USER2);
                const isCHARLIESubscribed_after = await EPNSCommunicatorV1Proxy.isUserSubscribed(BOB, CHARLIE);
                const isUSER1Subscribed_after = await EPNSCommunicatorV1Proxy.isUserSubscribed(CHARLIE, USER1);

                // USER2's DETAILS
                await expect(isUSER2Subscribed_before).to.equal(false);
                await expect(isUSER2Subscribed_after).to.equal(true);
                await expect(USER2Details_before.subscribedCount.toNumber()).to.equal(0);
                await expect(USER2Details_after.subscribedCount.toNumber()).to.equal(1);
                // Charlie's DETAILS
                await expect(isCHARLIESubscribed_before).to.equal(false);
                await expect(isCHARLIESubscribed_after).to.equal(true);
                await expect(CHARLIEDetails_before.subscribedCount.toNumber()).to.equal(0);
                await expect(CHARLIEDetails_after.subscribedCount.toNumber()).to.equal(1);
                // USER1's Details
                await expect(isUSER1Subscribed_before).to.equal(false);
                await expect(isUSER1Subscribed_after).to.equal(true);
                await expect(USER1Details_before.subscribedCount.toNumber()).to.equal(0);
                await expect(USER1Details_after.subscribedCount.toNumber()).to.equal(1);
            })

    });


});
});
