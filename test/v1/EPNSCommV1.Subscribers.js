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

    const EPNSCommV1 = await ethers.getContractFactory("EPNSCommV1");
    COMMUNICATOR_LOGIC = await EPNSCommV1.deploy();

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
    EPNSCommV1Proxy = EPNSCommV1.attach(EPNSCommProxy.address)

  });

  afterEach(function () {
    EPNS = null
    CORE_LOGIC = null
    TIMELOCK = null
    EPNSCoreProxy = null
    EPNSCoreV1Proxy = null
  });


 describe("EPNS COMMUNICATOR: Subscribing, Unsubscribing, Send Notification Tests", function(){

    // SUBSCRIBE RELATED TESTS
  describe("Testing BASE SUbscribe FUnction", function()
      {
          const CHANNEL_TYPE = 2;
          const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

           beforeEach(async function(){
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
            await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
         });

           /*
             * 'subscribe' Function CHECKPOINTS
             * Should revert if User is already subscribed to a Particular Channel
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

            it("Should revert if Users try to Subscribe Twice" , async ()=>{
               await EPNSCommV1Proxy.connect(BOBSIGNER).subscribe(CHANNEL_CREATOR);
               const tx = EPNSCommV1Proxy.connect(BOBSIGNER).subscribe(CHANNEL_CREATOR);

               await expect(tx).to.be.revertedWith('EPNSCommV1::_subscribe: User already Subscribed');
            })

            it("Function should Execute the 'addUser' function adequately", async() =>{
                const userDetails_before = await EPNSCommV1Proxy.users(BOB);
                const userCount_before  = await EPNSCommV1Proxy.usersCount();

                const tx = EPNSCommV1Proxy.connect(BOBSIGNER).subscribe(CHANNEL_CREATOR);


                const userCount_after  = await EPNSCommV1Proxy.usersCount();
                const userDetails_after = await EPNSCommV1Proxy.users(BOB);


                await expect(userDetails_before.userActivated).to.equal(false);
                await expect(userDetails_after.userActivated).to.equal(true);
                await expect(userCount_before.toNumber()).to.equal(2);
                await expect(userCount_after.toNumber()).to.equal(3);

            })

            it("Function should Execute and Update State Variables adequately", async() =>{
                const userDetails_before = await EPNSCommV1Proxy.users(BOB);
                const isSubscribed_before = await EPNSCommV1Proxy.isUserSubscribed(CHANNEL_CREATOR, BOB);

                const tx = EPNSCommV1Proxy.connect(BOBSIGNER).subscribe(CHANNEL_CREATOR);

                const userDetails_after = await EPNSCommV1Proxy.users(BOB);
                const isSubscribed_after = await EPNSCommV1Proxy.isUserSubscribed(CHANNEL_CREATOR, BOB);

                await expect(isSubscribed_before).to.equal(false);
                await expect(isSubscribed_after).to.equal(true);
                await expect(userDetails_before.subscribedCount.toNumber()).to.equal(0);
                await expect(userDetails_after.subscribedCount.toNumber()).to.equal(1);

            })

            it("Function Should emit Relevant Events", async()=>{
              const tx = EPNSCommV1Proxy.connect(BOBSIGNER).subscribe(CHANNEL_CREATOR);

              await expect(tx).to.emit(EPNSCommV1Proxy,'Subscribe')
               .withArgs(CHANNEL_CREATOR, BOB)
            })

    });


  // // BATCH SUBSCRIBE SUBSCRIBE RELATED TESTS
  // describe("Testing BATCH SUbscribe Function", function()
  //     {
  //         const CHANNEL_TYPE = 2;
  //         const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");
  //
  //          beforeEach(async function(){
  //           await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
  //           await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
  //           await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
  //           await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
  //           await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
  //        });
  //
  //
  //
  //           it("Function should Execute and Update State Variables adequately", async() =>{
  //               const channelArray = [USER2, CHARLIE, USER1]
  //
  //               const userDetails_before = await EPNSCommV1Proxy.users(BOB);
  //
  //               const isSubscribed_before_USER2 = await EPNSCommV1Proxy.isUserSubscribed(USER2, BOB);
  //               const isSubscribed_before_CHARLIE = await EPNSCommV1Proxy.isUserSubscribed(CHARLIE, BOB);
  //               const isSubscribed_before_USER1 = await EPNSCommV1Proxy.isUserSubscribed(USER1, BOB);
  //
  //
  //               const tx = EPNSCommV1Proxy.connect(BOBSIGNER).batchSubscribe(channelArray);
  //
  //               const userDetails_after = await EPNSCommV1Proxy.users(BOB);
  //
  //               const isSubscribed_after_USER2 = await EPNSCommV1Proxy.isUserSubscribed(USER2, BOB);
  //               const isSubscribed_after_CHARLIE = await EPNSCommV1Proxy.isUserSubscribed(CHARLIE, BOB);
  //               const isSubscribed_after_USER1 = await EPNSCommV1Proxy.isUserSubscribed(USER1, BOB);
  //
  //               // BOB DETAILS VERIFICATION
  //               await expect(isSubscribed_before_USER2).to.equal(false);
  //               await expect(isSubscribed_before_CHARLIE).to.equal(false);
  //               await expect(isSubscribed_before_USER1).to.equal(false);
  //
  //               await expect(isSubscribed_after_USER2).to.equal(true);
  //               await expect(isSubscribed_after_CHARLIE).to.equal(true);
  //               await expect(isSubscribed_after_USER1).to.equal(true);
  //
  //               await expect(userDetails_before.subscribedCount.toNumber()).to.equal(0);
  //               await expect(userDetails_after.subscribedCount.toNumber()).to.equal(3);
  //           })
  //
  //   });
  //
  //   // UNSUBSCRIBE RELATED TESTS
  // describe("Testing BASE UNSUBSCRIBE FUnction", function()
  //     {
  //         const CHANNEL_TYPE = 2;
  //         const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");
  //
  //          beforeEach(async function(){
  //           await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
  //           await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
  //           await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
  //           await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
  //           await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
  //        });
  //
  //          /*
  //            * '_unsubscribe' Function CHECKPOINTS
  //            * Should revert if User is not subscribed to the Channel
  //            *
  //            * Function Execution BODY
  //            *         -> 'isSubscribed' for user and Channel should be updated to '0'
  //            *         -> subscribed mapping should be updated with User's Current subscribe count
  //            *         -> subscribedCount variable for user should decrease by 1
  //            *
  //           */
  //
  //           it("Should revert if Users try to Unsubscribe a Channel Before Subscribing Twice" , async ()=>{
  //              const tx = EPNSCommV1Proxy.connect(BOBSIGNER).unsubscribe(CHANNEL_CREATOR);
  //
  //              await expect(tx).to.be.revertedWith('EPNSCommV1::_unsubscribe: User not subscribed to channel');
  //           })
  //
  //           it("Function should Execute and Update State Variables adequately", async() =>{
  //               await EPNSCommV1Proxy.connect(BOBSIGNER).subscribe(CHANNEL_CREATOR)
  //
  //               const userDetails_before = await EPNSCommV1Proxy.users(BOB);
  //               const isSubscribed_before = await EPNSCommV1Proxy.isUserSubscribed(CHANNEL_CREATOR, BOB);
  //
  //               const tx = EPNSCommV1Proxy.connect(BOBSIGNER).unsubscribe(CHANNEL_CREATOR);
  //
  //               const userDetails_after = await EPNSCommV1Proxy.users(BOB);
  //               const isSubscribed_after = await EPNSCommV1Proxy.isUserSubscribed(CHANNEL_CREATOR, BOB);
  //
  //               await expect(isSubscribed_before).to.equal(true);
  //               await expect(isSubscribed_after).to.equal(false);
  //               await expect(userDetails_before.subscribedCount.toNumber()).to.equal(1);
  //               await expect(userDetails_after.subscribedCount.toNumber()).to.equal(0);
  //
  //           })
  //
  //           it("Function Should emit Relevant Events", async()=>{
  //             await EPNSCommV1Proxy.connect(BOBSIGNER).subscribe(CHANNEL_CREATOR)
  //             const tx = EPNSCommV1Proxy.connect(BOBSIGNER).unsubscribe(CHANNEL_CREATOR);
  //
  //             await expect(tx).to.emit(EPNSCommV1Proxy, 'Unsubscribe')
  //              .withArgs(CHANNEL_CREATOR, BOB)
  //           })
  //
  //   });
  //
  //
  //   // BATCH Unsubscribe SUBSCRIBE RELATED TESTS
  // describe("Testing BATCH Unsubscribe Function", function()
  //     {
  //         const CHANNEL_TYPE = 2;
  //         const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");
  //
  //          beforeEach(async function(){
  //           await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
  //           await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
  //           await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
  //           await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
  //           await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
  //        });
  //
  //
  //
  //         it("Function should Execute and Update State Variables adequately", async() =>{
  //             const channelArray = [USER2, CHARLIE, USER1]
  //
  //             await EPNSCommV1Proxy.connect(BOBSIGNER).batchSubscribe(channelArray);
  //
  //             const userDetails_before = await EPNSCommV1Proxy.users(BOB);
  //
  //             const isSubscribed_before_USER2 = await EPNSCommV1Proxy.isUserSubscribed(USER2, BOB);
  //             const isSubscribed_before_CHARLIE = await EPNSCommV1Proxy.isUserSubscribed(CHARLIE, BOB);
  //             const isSubscribed_before_USER1 = await EPNSCommV1Proxy.isUserSubscribed(USER1, BOB);
  //
  //
  //             await EPNSCommV1Proxy.connect(BOBSIGNER).batchUnsubscribe(channelArray);
  //
  //             const userDetails_after = await EPNSCommV1Proxy.users(BOB);
  //
  //             const isSubscribed_after_USER2 = await EPNSCommV1Proxy.isUserSubscribed(USER2, BOB);
  //             const isSubscribed_after_CHARLIE = await EPNSCommV1Proxy.isUserSubscribed(CHARLIE, BOB);
  //             const isSubscribed_after_USER1 = await EPNSCommV1Proxy.isUserSubscribed(USER1, BOB);
  //
  //             // BOB DETAILS VERIFICATION
  //             await expect(isSubscribed_before_USER2).to.equal(true);
  //             await expect(isSubscribed_before_CHARLIE).to.equal(true);
  //             await expect(isSubscribed_before_USER1).to.equal(true);
  //
  //             await expect(isSubscribed_after_USER2).to.equal(false);
  //             await expect(isSubscribed_after_CHARLIE).to.equal(false);
  //             await expect(isSubscribed_after_USER1).to.equal(false);
  //
  //             await expect(userDetails_before.subscribedCount.toNumber()).to.equal(3);
  //             await expect(userDetails_after.subscribedCount.toNumber()).to.equal(0);
  //         })
  //
  //   });


  // USER NOTIF SETTING FUNCTION TESTS

   // describe("Testing BASE SUbscribe FUnction", function()
   //    {
   //        const CHANNEL_TYPE = 2;
   //        const user_notifSettings = "1-1+2-40+3-0+4-98";
   //        const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");
   //
   //         beforeEach(async function(){
   //          await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
   //          await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
   //          await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
   //          await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
   //          await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
   //       });
   //
   //
   //      it("Should revert if User is NOT a SUBSCRIBER Of the Channel", async function () {
   //        const notif_Id = 3;
   //        const tx =  EPNSCommV1Proxy.connect(BOBSIGNER).changeUserChannelSettings(CHANNEL_CREATOR, notif_Id, user_notifSettings);
   //
   //         await expect(tx).to.be.revertedWith("EPNSCommV1::changeUserChannelSettings: User not Subscribed to Channel")
   //      });
   //
   //      it("Should update the userToChannelNotifs mapping with the right DATA", async function () {
   //        const notif_Id = 3;
   //        const notifSettings_final = "3+1-1+2-40+3-0+4-98";
   //        const userDetails_before = await EPNSCommV1Proxy.users(BOB);
   //        await EPNSCommV1Proxy.connect(BOBSIGNER).subscribe(CHANNEL_CREATOR);
   //        const userDetails_after = await EPNSCommV1Proxy.users(BOB);
   //
   //        await EPNSCommV1Proxy.connect(BOBSIGNER).changeUserChannelSettings(CHANNEL_CREATOR, notif_Id, user_notifSettings);
   //        const userNotifMapping = await EPNSCommV1Proxy.userToChannelNotifs(BOB,CHANNEL_CREATOR);
   //
   //        expect(userNotifMapping).to.be.equal(notifSettings_final)
   //        expect(userDetails_before.userActivated).to.be.equal(false);
   //        expect(userDetails_after.userActivated).to.be.equal(true);
   //      });
   //
   //      it("Should Emit out the EVENTS with the right Parameters", async function (){
   //        const CHANNEL_TYPE = 2;
   //        const notif_Id = 3;
   //        await EPNSCommV1Proxy.connect(BOBSIGNER).subscribe(CHANNEL_CREATOR);
   //        const tx =  EPNSCommV1Proxy.connect(BOBSIGNER).changeUserChannelSettings(CHANNEL_CREATOR,notif_Id,user_notifSettings);
   //        const userNotifMapping = await EPNSCommV1Proxy.userToChannelNotifs(BOB,CHANNEL_CREATOR);
   //
   //       await expect(tx).to.emit(EPNSCommV1Proxy,'UserNotifcationSettingsAdded').withArgs(CHANNEL_CREATOR, BOB, notif_Id, userNotifMapping);
   //
   //      })
   //
   //  });
   // // BROADCASTING THE PUBLIC KEY
   //
   // describe("Testing PUBLIC KEY BROADCASTING FUNCTION", function()
   //    {
   //        const CHANNEL_TYPE = 2;
   //        const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");
   //
   //         beforeEach(async function(){
   //          await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
   //          await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
   //          await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
   //          await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
   //          await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
   //       });
   //
   //
   //      it("Should Be able to broadcast user public key", async function(){
   //      const publicKey = await getPubKey(BOBSIGNER)
   //
   //      const userDetails_before = await EPNSCommV1Proxy.users(BOB);
   //
   //      await EPNSCommV1Proxy.connect(BOBSIGNER).broadcastUserPublicKey(publicKey.slice(1));
   //
   //      const userDetails_after = await EPNSCommV1Proxy.users(BOB);
   //
   //      await expect(userDetails_before.publicKeyRegistered).to.equal(false);
   //      await expect(userDetails_after.publicKeyRegistered).to.equal(true);
   //    });
   //
   //    it("Should not broadcast user public key twice", async function(){
   //      const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)
   //
   //      await EPNSCommV1Proxy.connect(CHANNEL_CREATORSIGNER).broadcastUserPublicKey(publicKey.slice(1));
   //
   //      const tx = EPNSCommV1Proxy.connect(CHANNEL_CREATORSIGNER).broadcastUserPublicKey(publicKey.slice(1));
   //
   //      await expect(tx)
   //      .to.not.emit(EPNSCommV1Proxy, 'PublicKeyRegistered')
   //      .withArgs(CHANNEL_CREATOR, ethers.utils.hexlify(publicKey.slice(1)))
   //    });
   //
   //    it("Should REVERT IF CALLER IS Different than the PUBLIC KEY Provided", async function(){
   //      const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)
   //
   //      const tx = EPNSCommV1Proxy.connect(BOBSIGNER).broadcastUserPublicKey(publicKey.slice(1));
   //
   //      await expect(tx).to.be.revertedWith('Public Key Validation Failed');
   //
   //    });
   //
   //    it("Should EMIT RELEVANT EVENTS", async function(){
   //      const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)
   //
   //      const tx = EPNSCommV1Proxy.connect(CHANNEL_CREATORSIGNER).broadcastUserPublicKey(publicKey.slice(1));
   //
   //      await expect(tx)
   //      .to.emit(EPNSCommV1Proxy, 'PublicKeyRegistered')
   //      .withArgs(CHANNEL_CREATOR, ethers.utils.hexlify(publicKey.slice(1)))
   //    });
   //
   //
   //  });


});
});
