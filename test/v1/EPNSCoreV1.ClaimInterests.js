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

  const referralCode = 0;
  const CHANNEL_DEACTIVATION_FEES = tokensBN(10);
  const ADD_CHANNEL_MIN_POOL_CONTRIBUTION = tokensBN(5000)
  const ADD_CHANNEL_MAX_POOL_CONTRIBUTION = tokensBN(100)
  const USER1_Token = tokensBN(2500)
  const USER2_Token = tokensBN(150000)
  const USER3_Token = tokensBN(20000)
  const DELEGATED_CONTRACT_FEES = ethers.utils.parseEther("0.1");
  const ADJUST_FOR_FLOAT = bn(10 ** 8);
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


 describe("EPNS CORE: Channel Creation Tests", function(){
   describe("Testing Interest Claiming Function of EPNSCore", function()
      {
          const CHANNEL_TYPE = 2;
          const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

           beforeEach(async function(){
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
            await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);

            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await MOCKDAI.connect(BOBSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await MOCKDAI.connect(BOBSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

            await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
            await EPNSCoreV1Proxy.connect(BOBSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

            await EPNS.connect(ADMINSIGNER).transfer(CHANNEL_CREATOR, USER1_Token);
            await EPNS.connect(ADMINSIGNER).transfer(BOB, USER2_Token);
            await EPNS.connect(ADMINSIGNER).transfer(ALICE, USER3_Token);
        });
          /**
            * "claimInterest" Function CheckPoints
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


       // it("Weight Checks", async function(){
       //   const blockNumber_before = await latestBlock()
       //   const advance = blockNumber_before.toNumber() + 40
       //
       //   const bornDate = await EPNS.born()
       //   const totalSupply = await EPNS.totalSupply();
       //   // GET THE TIME GAP BETWEEN CURRENT  BLOCK NUMBER AND BORNDATE
       //   const b = blockNumber_before.toNumber();
       //   const timeGap = b - bornDate;
       //   const totalWeight = totalSupply.mul(blockNumber_before.toNumber())
       //   // GET TOTAL RATIO
       //   const totalRatioExists = totalSupply.mul(timeGap);
       //
       //   const admin_units = await EPNS.returnHolderUnits(ADMIN, blockNumber_before.toNumber());
       //   const bob_units = await EPNS.returnHolderUnits(BOB, blockNumber_before.toNumber());
       //   const alice_units = await EPNS.returnHolderUnits(ALICE, blockNumber_before.toNumber());
       //   const channel_units = await EPNS.returnHolderUnits(CHANNEL_CREATOR, blockNumber_before.toNumber());
       //
       //   // ADJUSTING FLOAT
       //   const bob_unit = bob_units.mul(ADJUST_FOR_FLOAT);
       //   const alice_unit = alice_units.mul(ADJUST_FOR_FLOAT);
       //   const channel_unit = channel_units.mul(ADJUST_FOR_FLOAT);
       //   const admin_unit = admin_units.mul(ADJUST_FOR_FLOAT);
       //
       //   const ratioBOB = bob_unit/totalRatioExists;
       //   const ratioADMIN = admin_unit/totalRatioExists;
       //   const ratioAlice = alice_unit/totalRatioExists;
       //   const ratioChannel= channel_unit/totalRatioExists;
       //
       //   const addition = ratioBOB + ratioADMIN + ratioAlice +ratioChannel;
       //
       //            console.log(addition);
       //            console.log(totalSupply.toString())
       //
       //   console.log('-----UNITS WIEGHT-------');
       //   console.log(bob_units.toString());
       //   console.log(alice_units.toString());
       //   console.log(channel_units.toString());
       //   console.log(admin_units.toString());
       //   console.log(totalWeight.toString());
       //
       //   console.log('-----RATIO-------');
       //   console.log(ratioBOB.toString());
       //   console.log(ratioAlice.toString());
       //   console.log(ratioChannel.toString());
       //   console.log(ratioADMIN.toString());
       //   console.log(totalRatioExists.toString());
       //   // ____________________________________________________________________________________________
       //    console.log('-----AFTER INCREASING BLOCK NUMBER------');
       //   // ADVANCING TO HIGHER BLOCK
       //   await advanceBlockTo(advance);
       //   const blockNumber = await latestBlock()
       //   const forBobBlock = blockNumber.toNumber() + 2;
       //   // GET THE TIME GAP BETWEEN CURRENT  BLOCK NUMBER AND BORNDATE
       //   const b_after = blockNumber.toNumber();
       //   const timeGap_after = b - bornDate;
       //   const totalWeight_after = totalSupply.mul(blockNumber.toNumber())
       //   // GET TOTAL RATIO
       //   const totalRatioExists_after = totalSupply.mul(timeGap_after);
       //   await EPNS.connect(BOBSIGNER).resetHolderWeight(BOB);
       //   const admin_units_after = await EPNS.returnHolderUnits(ADMIN, blockNumber.toNumber());
       //   const bob_units_after = await EPNS.returnHolderUnits(BOB, forBobBlock);
       //   const alice_units_after = await EPNS.returnHolderUnits(ALICE, blockNumber.toNumber());
       //   const channel_units_after = await EPNS.returnHolderUnits(CHANNEL_CREATOR, blockNumber.toNumber());
       //
       //   // ADJUSTING FLOAT
       //   const bob_unit_after = bob_units_after.mul(ADJUST_FOR_FLOAT);
       //   const alice_unit_after = alice_units_after.mul(ADJUST_FOR_FLOAT);
       //   const channel_unit_after = channel_units_after.mul(ADJUST_FOR_FLOAT);
       //   const admin_unit_after = admin_units_after.mul(ADJUST_FOR_FLOAT);
       //
       //   const ratioBOB_after = bob_unit_after/totalRatioExists_after;
       //   const ratioADMIN_after = admin_unit_after/totalRatioExists_after;
       //   const ratioAlice_after = alice_unit_after/totalRatioExists_after;
       //   const ratioChannel_after = channel_unit_after/totalRatioExists_after;
       //
       //   const addition_after = ratioBOB + ratioADMIN + ratioAlice +ratioChannel;
       //
       //   console.log(addition_after);
       //   console.log(totalSupply.toString())
       //
       //   console.log('-----UNITS WIEGHT_after-------');
       //   console.log(bob_units_after.toString());
       //   console.log(alice_units_after.toString());
       //   console.log(channel_units_after.toString());
       //   console.log(admin_units_after.toString());
       //   console.log(totalWeight.toString());
       //
       //   console.log('-----RATIO_after-------');
       //   console.log(ratioBOB_after.toString());
       //   console.log(ratioAlice_after.toString());
       //   console.log(ratioChannel_after.toString());
       //   console.log(ratioADMIN_after.toString());
       //   console.log(totalRatioExists_after.toString());
       //
       //
       // });
       //
       // it("Initial CHECKS", async ()=>{
       //     // const blockNumber = await latestBlock()
       //     // const advance = blockNumber.toNumber() + 20
       //     // await advanceBlockTo(advance);
       //
       //     const isCoreApproved_before  = await EPNS.holderDelegation(CHANNEL_CREATOR, EPNSCoreV1Proxy.address);
       //     // await EPNS.connect(CHANNEL_CREATORSIGNER).setHolderDelegation(EPNSCoreV1Proxy.address, true);
       //     // const isCoreApproved_after  = await EPNS.holderDelegation(CHANNEL_CREATOR, EPNSCoreV1Proxy.address);
       //     console.log(isCoreApproved_before)
       //     const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).claimInterest();
       //
       // })

        // it("Should revert if User Has ZERO Interest amount to CLAIMED", async function(){
        //   const blockNumber = await latestBlock()
        //
        //   const userHolderUnits = await EPNS.returnHolderUnits(CHARLIE, blockNumber.toNumber());
        //   const tx = EPNSCoreV1Proxy.connect(CHARLIESIGNER).claimInterest();
        //
        //   await expect(userHolderUnits).to.be.equal(0)
        //   await expect(tx).to.be.revertedWith("EPNSCoreV1::claimInterest: No Claimable Rewards at the Moment");
        // });
        //
        // it("Should revert if User has not approved EPNS Core For Resetting the Holder Weights", async function(){
        //   const blockNumber = await latestBlock()
        //
        //   const userHolderUnits = await EPNS.returnHolderUnits(CHANNEL_CREATOR, blockNumber.toNumber());
        //   const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).claimInterest();
        //
        //   await expect(tx).to.be.revertedWith("Push::resetHolderWeight: unauthorized");
        // });
        //
        // it("Function should execute if User has properly approved EPNS Core For Resetting the Holder Weights", async function(){
        //   const blockNumber = await latestBlock()
        //   const advance = blockNumber.toNumber() + 90
        // //  await advanceBlockTo(advance);
        //
        //   const isCoreApproved_before  = await EPNS.holderDelegation(CHANNEL_CREATOR, EPNSCoreV1Proxy.address);
        //   await EPNS.connect(CHANNEL_CREATORSIGNER).setHolderDelegation(EPNSCoreV1Proxy.address, true);
        //   const isCoreApproved_after  = await EPNS.holderDelegation(CHANNEL_CREATOR, EPNSCoreV1Proxy.address);
        //
        //   const userHolderUnits = await EPNS.returnHolderUnits(CHANNEL_CREATOR, blockNumber.toNumber());
        //   const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).claimInterest();
        //   const totalClaimableRewards = await EPNSCoreV1Proxy.usersInterestClaimed(CHANNEL_CREATOR);
        //
        //   await expect(userHolderUnits).to.not.equal(0);
        //   await expect(isCoreApproved_before).to.be.equal(false);
        //   await expect(isCoreApproved_after).to.be.equal(true);
        //
        //   await expect(tx)
        //   .to.emit
        //   (EPNSCoreV1Proxy, 'InterestClaimed').
        //   withArgs(CHANNEL_CREATOR, totalClaimableRewards);
        // }).timeout(6000);

        it("Function should update State Variables Correctly After Execution", async function(){
          const blockNumber = await latestBlock()
          const b = blockNumber.toNumber();
          const advance = blockNumber.toNumber() + 90
          //await advanceBlockTo(advance);

          const holderWeight_before  = await EPNS.holderWeight(CHANNEL_CREATOR);

          await EPNS.connect(CHANNEL_CREATORSIGNER).setHolderDelegation(EPNSCoreV1Proxy.address, true);
          const totalClaimableRewards_before = await EPNSCoreV1Proxy.usersInterestClaimed(CHANNEL_CREATOR);

          const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).claimInterest();

          const totalClaimableRewards_after = await EPNSCoreV1Proxy.usersInterestClaimed(CHANNEL_CREATOR);

          const holderWeight_after  = await EPNS.holderWeight(CHANNEL_CREATOR);
          const totalClaimableRewardsAfter = await EPNSCoreV1Proxy.usersInterestClaimed(CHANNEL_CREATOR);

          await expect(totalClaimableRewards_before).to.be.equal(0);
          await expect(totalClaimableRewardsAfter).to.not.equal(0);
          await expect(holderWeight_after).to.be.gt(0);


        }).timeout(6000);

        it("Function should emit adequate Events", async function(){
          await EPNS.connect(CHANNEL_CREATORSIGNER).setHolderDelegation(EPNSCoreV1Proxy.address, true);
          const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).claimInterest();
          const totalClaimableRewards = await EPNSCoreV1Proxy.usersInterestClaimed(CHANNEL_CREATOR);

          await expect(tx)
            .to.emit(EPNSCoreV1Proxy, 'InterestClaimed')
            .withArgs(CHANNEL_CREATOR, totalClaimableRewards);
        }).timeout(6000);

    });

});
});
