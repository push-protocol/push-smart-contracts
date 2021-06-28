
const hre = require("hardhat");

const fs = require("fs");
const chalk = require("chalk");
const { config, ethers } = require("hardhat");

const { expect } = require("chai")

const {
  advanceBlockTo,
  latestBlock,
  advanceBlock,
  increase,
  increaseTo,
  latest,
} = require("../time");
const { calcChannelFairShare, calcSubscriberFairShare, getPubKey, bn, tokens, tokensBN, bnToInt, ChannelAction, readjustFairShareOfChannels, SubscriberAction, readjustFairShareOfSubscribers } = require("../../helpers/utils");

describe("EPNSCoreV1 tests", function () {
  const AAVE_LENDING_POOL = "0x24a42fD28C976A61Df5D00D0599C34c4f90748c8"; // Mainnet Lending pool of AAVE, will work with mainnet fork only
  const DAI = "0x6b175474e89094c44da98b954eedeac495271d0f"; // Mainnet DAI Address, will work with mainnet fork only
  const DAI_WHALE = '0x47ac0fb4f2d84898e4d9e7b4dab3c24507a6d503'; // Mainnet DAI Whale address
  const ADAI = "0xfC1E690f61EFd961294b3e1Ce3313fBD8aa4f85d"; // Mainnet aDAI Address, will work with mainnet fork only
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

    MOCKDAI = await ethers.getContractAt("MockDAI", DAI)
    ADAICONTRACT = await ethers.getContractAt("MockDAI", ADAI)

    // Connect and transfer DAI from DAI Whale
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [DAI_WHALE]}
    )

    const signer = await ethers.provider.getSigner(DAI_WHALE)

    const balance = await MOCKDAI.balanceOf(DAI_WHALE)
    console.log(chalk.gray(`    Transferring ${balance.toString()} DAI from ${DAI_WHALE} to ${ADMIN}`))

    await MOCKDAI.connect(signer).transfer(ADMIN, balance)
    const admin_balance = await MOCKDAI.balanceOf(ADMIN)

    console.log(chalk.gray(`    New Balance of ${ADMIN} is ${admin_balance}`))
  });

  beforeEach(async function () {
    const EPNSTOKEN = await ethers.getContractFactory("EPNS", {gasLimit: 15000000});
    EPNS = await EPNSTOKEN.deploy();

    const EPNSCoreV1 = await ethers.getContractFactory("EPNSCoreV1", {gasLimit: 15000000});
    LOGIC = await EPNSCoreV1.deploy();

    const TimeLock = await ethers.getContractFactory("Timelock");
    TIMELOCK = await TimeLock.deploy(ADMIN, delay);

    const proxyAdmin = await ethers.getContractFactory("EPNSAdmin");
    PROXYADMIN = await proxyAdmin.deploy({gasLimit: 5000000});
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

  after(async function () {
    await hre.network.provider.request({
      method: "hardhat_stopImpersonatingAccount",
      params: [DAI_WHALE]}
    )
  });

  describe("Testing send Notification related functions", function(){
    describe("Testing sendNotification", function(){
      beforeEach(async function(){
        const CHANNEL_TYPE = 2;
        const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

        await EPNSCoreV1Proxy.connect(ADMINSIGNER).addToChannelizationWhitelist(CHANNEL_CREATOR, {gasLimit: 500000});

        await MOCKDAI.connect(ADMINSIGNER).transfer(CHANNEL_CREATOR, ADD_CHANNEL_MIN_POOL_CONTRIBUTION)
        const balance = await MOCKDAI.balanceOf(CHANNEL_CREATOR)
        //console.log(chalk.gray(`        New Balance of ${CHANNEL_CREATOR} is ${balance}`))

        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel, {gasLimit: 5000000});
      });

      it("should revert if anyone other than owner calls the function", async function(){
        const msg = ethers.utils.toUtf8Bytes("This is notification message");
        await expect(EPNSCoreV1Proxy.connect(CHARLIESIGNER).sendNotification(BOB, msg))
          .to.be.revertedWith("Channel doesn't Exists");
      });

      it("should emit SendNotification when owner calls", async function(){
        const msg = ethers.utils.toUtf8Bytes("This is notification message");
        const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).sendNotification(BOB, msg);

        await expect(tx)
          .to.emit(EPNSCoreV1Proxy, 'SendNotification')
          .withArgs(CHANNEL_CREATOR, BOB, ethers.utils.hexlify(msg));
      });
    });

    /**
     * Test Objectives
     * No address should be able to access sendNotificationAsDelegate unless added as a Delegate by Channel Owner
     * Channel Owner should be able to Add/Revoke Delegate to send notifications on behalf of a particular channel.
     * Only Owner should be able to call the Add/Revoke functionalities
     * Address added as Delegate should be able to send notification for the channel.
     * Address whose Delegate notification sending permission is revoked, shouldn't be able to send any notifications
    */

    // describe("Testing sendNotificationAsDelegate function", function(){
    //   beforeEach(async function(){
    //     const CHANNEL_TYPE = 2;
    //     const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");
    //
    //     await EPNSCoreV1Proxy.connect(ADMINSIGNER).addToChannelizationWhitelist(CHANNEL_CREATOR, {gasLimit: 500000});
    //
    //     await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
    //     await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
    //     await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel, {gasLimit: 2000000});
    //   });
    //
    //   it("No one except a Delegate should be able to send notification on behalf of a Channel", async function(){
    //     const msg = ethers.utils.toUtf8Bytes("This is DELAGATED notification message");
    //     const tx =  EPNSCoreV1Proxy.connect(BOBSIGNER).sendNotificationAsDelegate(CHANNEL_CREATOR,BOB,msg);
    //     await expect(tx).to.be.revertedWith("Not authorised to send messages");
    //   });
    //
    //   it("BOB Should be able to Send Delegated Notification once Allowed", async function(){
    //     // Adding BOB As Delate Notification Seder
    //     const tx_addDelegate =  await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).addDelegate(BOB);
    //     const isBobAllowed = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).delegated_NotificationSenders(CHANNEL_CREATOR,BOB);
    //
    //     // BOB Sending Delegated Notification
    //     const msg = ethers.utils.toUtf8Bytes("This is DELAGATED notification message");
    //     const tx_sendNotif =  await EPNSCoreV1Proxy.connect(BOBSIGNER).sendNotificationAsDelegate(CHANNEL_CREATOR,ALICE,msg);
    //
    //     await expect(tx_sendNotif)
    //       .to.emit(EPNSCoreV1Proxy, 'SendNotification')
    //       .withArgs(CHANNEL_CREATOR, ALICE, ethers.utils.hexlify(msg));
    //     await expect(isBobAllowed).to.be.equal(true);
    //     await expect(tx_addDelegate)
    //       .to.emit(EPNSCoreV1Proxy, 'AddDelegate')
    //       .withArgs(CHANNEL_CREATOR, BOB);
    //   })
    //
    //    it("BOB Should NOT be able to Send Delegated Notification once Permission is Revoked", async function(){
    //     // Revoking Permission from BOB
    //     const tx_removeDelegate =  EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).removeDelegate(BOB);
    //     const isBobAllowed = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).delegated_NotificationSenders(CHANNEL_CREATOR,BOB);
    //
    //     // BOB Sending Delegated Notification
    //      const msg = ethers.utils.toUtf8Bytes("This is DELAGATED notification message");
    //     const tx_sendNotif =  EPNSCoreV1Proxy.connect(BOBSIGNER).sendNotificationAsDelegate(CHANNEL_CREATOR,BOB,msg);
    //
    //
    //     await expect(tx_sendNotif).to.be.revertedWith("Not authorised to send messages");
    //     await expect(isBobAllowed).to.be.equal(false);
    //       await expect(tx_removeDelegate)
    //       .to.emit(EPNSCoreV1Proxy, 'RemoveDelegate')
    //       .withArgs(CHANNEL_CREATOR, BOB);
    //   })
    // });
  });
});
