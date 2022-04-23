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

    const EPNSCore = await ethers.getContractFactory("EPNSCoreV2");
    CORE_LOGIC = await EPNSCore.deploy();

    const TimeLock = await ethers.getContractFactory("Timelock");
    TIMELOCK = await TimeLock.deploy(ADMIN, delay);

    const proxyCoreAdmin = await ethers.getContractFactory("EPNSCoreAdmin");
    PROXYCOREADMIN = await proxyCoreAdmin.deploy();

    const proxyCommAdmin = await ethers.getContractFactory("EPNSCommAdmin");
    PROXYCOMMADMIN = await proxyCommAdmin.deploy();
    //await PROXYADMIN.transferOwnership(TIMELOCK.address);

    const EPNSCommunicator = await ethers.getContractFactory("EPNSCommV1");
    COMMUNICATOR_LOGIC = await EPNSCommunicator.deploy();

    const EPNSCoreProxyContract = await ethers.getContractFactory("EPNSCoreProxy");
    EPNSCoreProxy = await EPNSCoreProxyContract.deploy(
      CORE_LOGIC.address,
      PROXYCOREADMIN.address,
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
      PROXYCOMMADMIN.address,
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

          // Pauseable Tests
          it("Contract should only be Paused via GOVERNANCE", async function(){
            const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).pauseContract();

            await expect(tx).to.be.revertedWith('EPNSCoreV1::onlyGovernance: Caller not Governance')
          });

          it("Contract should only be UnPaused via GOVERNANCE", async function(){
            const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).unPauseContract();

            await expect(tx).to.be.revertedWith('EPNSCoreV1::onlyGovernance: Caller not Governance')
          });

          it("Channel Creation Should not be executed if Contract is Paused", async function(){
            const CHANNEL_TYPE = 2;

            await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
            const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MAX_POOL_CONTRIBUTION);

            await expect(tx).to.be.revertedWith("Pausable: paused")
          });

          it("Channel Creation Should execute after UNPAUSE", async function(){
            const CHANNEL_TYPE = 2;

            await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
            const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MAX_POOL_CONTRIBUTION);

            await expect(tx).to.be.revertedWith("Pausable: paused");
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).unPauseContract();
            const tx_2 = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

            await expect(tx_2)
              .to.emit(EPNSCoreV1Proxy, 'AddChannel')
              .withArgs(CHANNEL_CREATOR, CHANNEL_TYPE, ethers.utils.hexlify(testChannel));

          });

          it("Channel Deactivation Should not be executed if Contract is Paused", async function(){
            const CHANNEL_TYPE = 2;

            await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
            const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel(CHANNEL_TYPE);

            await expect(tx).to.be.revertedWith("Pausable: paused")
          });

          it("Channel Reactivation Should not be executed if Contract is Paused", async function(){
            const CHANNEL_TYPE = 2;

            await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
            const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).reactivateChannel(CHANNEL_TYPE);

            await expect(tx).to.be.revertedWith("Pausable: paused")
          });

          it("Channel Blocking Should not be executed if Contract is Paused", async function(){
            const CHANNEL_TYPE = 2;

            await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
            const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).blockChannel(CHANNEL_CREATOR);

            await expect(tx).to.be.revertedWith("Pausable: paused")
          });
    });

});
});
