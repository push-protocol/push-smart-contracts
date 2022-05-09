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

describe("EPNS CoreV2 Protocol", function () {

  const DAI = "0xf80A32A835F79D7787E8a8ee5721D0fEaFd78108";
  const ADAI = "0xcB1Fe6F440c49E9290c3eb7f158534c2dC374201";
  const WETH = "0xc778417E063141139Fce010982780140Aa0cD5Ab";
  const UNISWAP_ROUTER = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
  const EPNS_TOKEN_ADDRS = "0xf418588522d5dd018b425E472991E52EBBeEEEEE";
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

    const EPNSCore = await ethers.getContractFactory("EPNSCoreV2");
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

    PushToken = EPNSTOKEN.attach(EPNS.address)
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
          const channelNewIdentity = ethers.utils.toUtf8Bytes("test-channel-hello-world");

           beforeEach(async function(){
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
            await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
            await PushToken.transfer(BOB, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(20));
            await PushToken.transfer(ALICE, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(20));
            await PushToken.connect(BOBSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(20));
            await PushToken.connect(ALICESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(20));

            await EPNSCoreV1Proxy.connect(BOBSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await EPNSCoreV1Proxy.connect(ALICESIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
         });
          /**
            * "updateChannelMeta" Function CheckPoints
            * REVERT CHECKS
            * Should revert IF Contract is Paused
            * Should revert if Caller is not the Channel Owner
            * If Channel Creator is Updating Channel Meta for first time:
            *   => Fee Amount should be at least 50 PUSH Tokens, else Revert
            *
            * If Channel Creator is Updating Channel Meta for N time:
            *   => Fee Amount should be at least (50 * N) PUSH Tokens, else Revert
            *
            * FUNCTION Execution CHECKS
            * Should charge 50 PUSH Tokens for first time update
            * Should charge 100, 150, 200 PUSH Tokens for 2nd, 3rd or 4th time update.
            * Should update the PROTOCOL_POOL_FEES state variable
            * Should increase the channel's update counter by 1
            * Should update the update block number for the channel
            * Should transfer the PUSH Tokens from User to Channel
            * Should emit the event with right args
           **/

           // Pauseable Tests
           it("Should revert IF Contract is Paused", async function(){
             await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();

             const tx = EPNSCoreV1Proxy.connect(BOBSIGNER).updateChannelMeta(BOB, channelNewIdentity, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
             await expect(tx).to.be.revertedWith("Pausable: paused")
           });

           it("Should revert IF Caller is not the Channel Owner", async function(){

             const tx = EPNSCoreV1Proxy.connect(ALICESIGNER).updateChannelMeta(BOB, channelNewIdentity, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
             await expect(tx).to.be.revertedWith("EPNSCoreV1::onlyChannelOwner: Channel not Exists or Invalid Channel Owner")
           });

           it("Should revert IF Amount is less than Required Push tokens", async function(){
              const LESS_AMOUNT = tokensBN(20)
              const tx = EPNSCoreV1Proxy.connect(BOBSIGNER).updateChannelMeta(BOB, channelNewIdentity, LESS_AMOUNT);

              await expect(tx).to.be.revertedWith("EPNSCoreV2::updateChannelMeta: Insufficient Deposit Amount")

           });

           it("Should update Channel Meta Details correctly for right Amount -> 50 PUSH Tokens", async function(){

              const tx = await EPNSCoreV1Proxy.connect(BOBSIGNER).updateChannelMeta(BOB, channelNewIdentity, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

              const block_num = tx.blockNumber;
              const channel = await EPNSCoreV1Proxy.channels(BOB)
              const pool_fees = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
              const counter = await EPNSCoreV1Proxy.channelUpdateCounter(BOB);

              await expect(channel.channelUpdateBlock).to.equal(block_num);
              await expect(pool_fees).to.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
              await expect(counter).to.equal(1);

           });

           it("Contract should recieve 50 Push tokens for 1st Channel Update", async function(){
             const pushBalanceBefore_coreContract = await PushToken.balanceOf(EPNSCoreV1Proxy.address);

             await EPNSCoreV1Proxy.connect(BOBSIGNER).updateChannelMeta(BOB, channelNewIdentity, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

             const pushBalanceAfter_coreContract = await PushToken.balanceOf(EPNSCoreV1Proxy.address);

             expect(pushBalanceAfter_coreContract.sub(pushBalanceBefore_coreContract)).to.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

           });

           it("2nd Channel Update should NOT execute if Fees deposited is NOT 50 * 2 Push Tokens", async function(){
             await EPNSCoreV1Proxy.connect(BOBSIGNER).updateChannelMeta(BOB, channelNewIdentity, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
             const counter_1 = await EPNSCoreV1Proxy.channelUpdateCounter(BOB);

             const tx_2nd = EPNSCoreV1Proxy.connect(BOBSIGNER).updateChannelMeta(BOB, channelNewIdentity, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

             await expect(counter_1).to.equal(1);
             await expect(tx_2nd).to.be.revertedWith("EPNSCoreV2::updateChannelMeta: Insufficient Deposit Amount")

           });

           it("Contract should recieve 500 Push tokens for 4th Channel Update", async function(){
             const pushBalanceBefore_coreContract = await PushToken.balanceOf(EPNSCoreV1Proxy.address);

             await EPNSCoreV1Proxy.connect(BOBSIGNER).updateChannelMeta(BOB, channelNewIdentity, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
             await EPNSCoreV1Proxy.connect(BOBSIGNER).updateChannelMeta(BOB, channelNewIdentity, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(2));
             await EPNSCoreV1Proxy.connect(BOBSIGNER).updateChannelMeta(BOB, channelNewIdentity, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(3));
             await EPNSCoreV1Proxy.connect(BOBSIGNER).updateChannelMeta(BOB, channelNewIdentity, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(4));

             const pushBalanceAfter_coreContract = await PushToken.balanceOf(EPNSCoreV1Proxy.address);
             const pool_fees = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES()

             await expect(pool_fees).to.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10));
             expect(pushBalanceAfter_coreContract.sub(pushBalanceBefore_coreContract)).to.equal(ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10));

           });


           it("Should Emit right args for Update Channel Meta correctly for right Amount -> 50 PUSH Tokens", async function(){

              const tx = EPNSCoreV1Proxy.connect(BOBSIGNER).updateChannelMeta(BOB, channelNewIdentity, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

              await expect(tx)
            .to.emit(EPNSCoreV1Proxy, 'UpdateChannel')
            .withArgs(BOB, ethers.utils.hexlify(channelNewIdentity));

           });


    });

});
});
