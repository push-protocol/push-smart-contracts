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
  const AAVE_LENDING_POOL = "0x1c8756FD2B28e9426CDBDcC7E3c4d64fa9A54728";
  const DAI = "0xf80A32A835F79D7787E8a8ee5721D0fEaFd78108";
  const ADAI = "0xcB1Fe6F440c49E9290c3eb7f158534c2dC374201";
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
      EPNS.address,
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


 describe("EPNS CORE: Channel Creation Tests", function(){
   describe("Testing Interest Claiming Function of EPNSCore", function()
      {
          const CHANNEL_TYPE = 2;
          const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

           beforeEach(async function(){
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommunicatorV1Proxy.address)
            await EPNSCommunicatorV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);

            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await MOCKDAI.connect(BOBSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await MOCKDAI.connect(BOBSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

            await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await EPNSCoreV1Proxy.connect(BOBSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

            await EPNS.connect(ADMINSIGNER).transfer(CHANNEL_CREATOR, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await EPNS.connect(ADMINSIGNER).transfer(BOB, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        });
          /**
            * "claimInterests" Function CheckPoints
            * REVERT CHECKS
            * Should Revert if User has not approved EPNS Core address ResetHolderWeight Delegate
            * Should revert if totalClaimableRewards is ZERO
            *
            * FUNCTION Execution CHECKS
            * Should calculate the Total ADaI interest correctly.
            * Should calculate the user's Holder weight correctly.
            * Should reset the User's HOLDER Weight on PUSH Token Contract.
            * Should update Variables accurately.
            * Should SWAP and Transfer PUSH Token to the USER.
            * Should emit Relevant Events
           **/

          it("Should revert if User Has ZERO Interest amount to CLAIMED", async function(){
            const blockNumber = await latestBlock()
            const advance = blockNumber.toNumber() + 9000
            await advanceBlockTo(advance);

            const userHolderUnits = await EPNS.returnHolderUnits(CHARLIE, blockNumber.toNumber());
            const tx = EPNSCoreV1Proxy.connect(CHARLIESIGNER).claimInterests();

            await expect(userHolderUnits).to.be.equal(0)
            await expect(tx).to.be.revertedWith("No Claimable Rewards at the Moment");
          });

        it("Should revert if User has not approved EPNS Core For Resetting the Holder Weights", async function(){
          const blockNumber = await latestBlock()
          const advance = blockNumber.toNumber() + 9000
          await advanceBlockTo(advance);

          const userHolderUnits = await EPNS.returnHolderUnits(CHANNEL_CREATOR, blockNumber.toNumber());
          const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).claimInterests();

          await expect(tx).to.be.revertedWith("Push::resetHolderWeight: unauthorized");
        });

        it("Function should execute if User has properly approved EPNS Core For Resetting the Holder Weights", async function(){
          const blockNumber = await latestBlock()
          const advance = blockNumber.toNumber() + 90
          await advanceBlockTo(advance);

          const isCoreApproved_before  = await EPNS.holderDelegation(CHANNEL_CREATOR, EPNSCoreV1Proxy.address);
          await EPNS.connect(CHANNEL_CREATORSIGNER).setHolderDelegation(EPNSCoreV1Proxy.address, true);
          const isCoreApproved_after  = await EPNS.holderDelegation(CHANNEL_CREATOR, EPNSCoreV1Proxy.address);

          const userHolderUnits = await EPNS.returnHolderUnits(CHANNEL_CREATOR, blockNumber.toNumber());
          const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).claimInterests();
          const totalClaimableRewards = await EPNSCoreV1Proxy.usersInterestClaimed(CHANNEL_CREATOR);

          await expect(userHolderUnits).to.not.equal(0);
          await expect(isCoreApproved_before).to.be.equal(false);
          await expect(isCoreApproved_after).to.be.equal(true);

          await expect(tx)
          .to.emit
          (EPNSCoreV1Proxy, 'InterestClaimed').
          withArgs(CHANNEL_CREATOR, totalClaimableRewards);
        });

        it("Function should update State Variables Correctly After Execution", async function(){
          const blockNumber = await latestBlock()
          const b = blockNumber.toNumber();
          const advance = blockNumber.toNumber() + 90
          await advanceBlockTo(advance);

          const holderWeight_before  = await EPNS.holderWeight(CHANNEL_CREATOR);

          await EPNS.connect(CHANNEL_CREATORSIGNER).setHolderDelegation(EPNSCoreV1Proxy.address, true);
          const totalClaimableRewards_before = await EPNSCoreV1Proxy.usersInterestClaimed(CHANNEL_CREATOR);

          const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).claimInterests();

          const totalClaimableRewards_after = await EPNSCoreV1Proxy.usersInterestClaimed(CHANNEL_CREATOR);

          const holderWeight_after  = await EPNS.holderWeight(CHANNEL_CREATOR);
          const totalClaimableRewardsAfter = await EPNSCoreV1Proxy.usersInterestClaimed(CHANNEL_CREATOR);

          await expect(totalClaimableRewards_before).to.be.equal(0);
          await expect(totalClaimableRewardsAfter).to.not.equal(0);
          await expect(holderWeight_after).to.be.gt(holderWeight_before);


        });

        it("Function should emit adequate Events", async function(){
          await EPNS.connect(CHANNEL_CREATORSIGNER).setHolderDelegation(EPNSCoreV1Proxy.address, true);
          const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).claimInterests();
          const totalClaimableRewards = await EPNSCoreV1Proxy.usersInterestClaimed(CHANNEL_CREATOR);

          await expect(tx)
            .to.emit(EPNSCoreV1Proxy, 'InterestClaimed')
            .withArgs(CHANNEL_CREATOR, totalClaimableRewards);
        });

    });

});
});
