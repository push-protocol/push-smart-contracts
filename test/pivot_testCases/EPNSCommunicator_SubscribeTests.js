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

describe("EPNS COMMUNCATOR Protocol", function () {
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


 describe("EPNS COMMUNICATOR: Subscribing, Unsubscribing, Send Notification Tests", function(){
    
     describe("Conducting Basic tests", function()
      {
          const CHANNEL_TYPE = 2;
          const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

           beforeEach(async function(){
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommunicatorV1Proxy.address)
            await EPNSCommunicatorV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
         });

          it("Should return the NAME of the COMMUNICATOR PROTOCOL", async () =>{
          const name = await EPNSCommunicatorV1Proxy.name()
          expect(name).to.be.equal("EPNS COMMUNICATOR");
          })

          it("Admin should be assigned correctly for EPNS COMMUNICATOR", async () =>{
          const adminAddress = await EPNSCommunicatorV1Proxy.admin()
          expect(adminAddress).to.be.equal(ADMIN);
          })

    });

    describe("Testing BASE SUbscribe FUnction", function()
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

           /**
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
            **/

            it("Should revert if Users try to Subscribe Twice" , async ()=>{
               await EPNSCommunicatorV1Proxy.connect(BOBSIGNER).subscribe(CHANNEL_CREATOR);
               const tx = EPNSCommunicatorV1Proxy.connect(BOBSIGNER).subscribe(CHANNEL_CREATOR);

               await expect(tx).to.be.revertedWith('User is Already Subscribed to this Channel');
            })

            it("Function should Execute the 'addUser' function adequately", async() =>{
                const userDetails_before = await EPNSCommunicatorV1Proxy.users(BOB);
                const userCount_before  = await EPNSCommunicatorV1Proxy.usersCount();

                const tx = EPNSCommunicatorV1Proxy.connect(BOBSIGNER).subscribe(CHANNEL_CREATOR);


                const userCount_after  = await EPNSCommunicatorV1Proxy.usersCount();
                const userDetails_after = await EPNSCommunicatorV1Proxy.users(BOB);


                await expect(userDetails_before.userActivated).to.equal(false);
                await expect(userDetails_after.userActivated).to.equal(true);
                await expect(userCount_before.toNumber()).to.equal(2);
                await expect(userCount_after.toNumber()).to.equal(3);

            })

            it("Function should Execute and Update State Variables adequately", async() =>{
                const userDetails_before = await EPNSCommunicatorV1Proxy.users(BOB);
                const isSubscribed_before = await EPNSCommunicatorV1Proxy.isUserSubscribed(CHANNEL_CREATOR, BOB);

                const tx = EPNSCommunicatorV1Proxy.connect(BOBSIGNER).subscribe(CHANNEL_CREATOR);

                const userDetails_after = await EPNSCommunicatorV1Proxy.users(BOB);
                const isSubscribed_after = await EPNSCommunicatorV1Proxy.isUserSubscribed(CHANNEL_CREATOR, BOB);

                await expect(isSubscribed_before).to.equal(false);
                await expect(isSubscribed_after).to.equal(true);
                await expect(userDetails_before.subscribedCount.toNumber()).to.equal(0);
                await expect(userDetails_after.subscribedCount.toNumber()).to.equal(1);
                
            })

            it("Function Should emit Relevant Events", async()=>{
              const tx = EPNSCommunicatorV1Proxy.connect(BOBSIGNER).subscribe(CHANNEL_CREATOR);

              await expect(tx).to.emit(EPNSCommunicatorV1Proxy,'Subscribe')
               .withArgs(CHANNEL_CREATOR, BOB)
            })

    });

});
});

