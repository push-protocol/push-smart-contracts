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

describe("EPNSCoreV1 tests", function () {
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

  describe("Testing broadcastUserPublicKey", function(){
    it("Should broadcast user public key", async function(){
      const publicKey = await getPubKey(BOBSIGNER)

      const tx = await EPNSCoreV1Proxy.connect(BOBSIGNER).broadcastUserPublicKey(publicKey.slice(1));
      const user = await EPNSCoreV1Proxy.users(BOB)

      expect(user.publicKeyRegistered).to.equal(true);
    });

    it("Should emit PublicKeyRegistered when broadcast user public key", async function(){
      const publicKey = await getPubKey(BOBSIGNER)

      const tx = EPNSCoreV1Proxy.connect(BOBSIGNER).broadcastUserPublicKey(publicKey.slice(1));

      await expect(tx)
      .to.emit(EPNSCoreV1Proxy, 'PublicKeyRegistered')
      .withArgs(BOB, ethers.utils.hexlify(publicKey.slice(1)))
    });

    it("Should not broadcast user public key twice", async function(){
      const publicKey = await getPubKey(BOBSIGNER)
      await EPNSCoreV1Proxy.connect(BOBSIGNER).broadcastUserPublicKey(publicKey.slice(1));
      const tx = EPNSCoreV1Proxy.connect(BOBSIGNER).broadcastUserPublicKey(publicKey.slice(1));
      
      await expect(tx)
      .to.not.emit(EPNSCoreV1Proxy, 'PublicKeyRegistered')
      .withArgs(BOB, ethers.utils.hexlify(publicKey.slice(1)))
    });

    it("Should revert if broadcast user public does not match with sender address", async function(){
      const publicKey = await getPubKey(ALICESIGNER)
      const tx = EPNSCoreV1Proxy.connect(BOBSIGNER).broadcastUserPublicKey(publicKey.slice(1));
      
      await expect(tx).to.be.revertedWith("Public Key Validation Failed")
    });

    it("Should update relevant details after broadcast public key", async function(){
      const publicKey = await getPubKey(BOBSIGNER)

      const usersCountBefore = await EPNSCoreV1Proxy.usersCount()
      const tx = await EPNSCoreV1Proxy.connect(BOBSIGNER).broadcastUserPublicKey(publicKey.slice(1));
      
      const user = await EPNSCoreV1Proxy.users(BOB);
      const usersCountAfter = await EPNSCoreV1Proxy.usersCount()

      expect(user.userStartBlock).to.equal(tx.blockNumber);
      expect(user.userActivated).to.equal(true);

      expect(usersCountBefore.add(1)).to.equal(usersCountAfter);
    });
  });

  describe("Testing funds functions", function(){
    describe("Testing withdrawDaiFunds", function(){
      beforeEach(async function(){
        const CHANNEL_TYPE = 2;
        const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

        await EPNSCoreV1Proxy.connect(ADMINSIGNER).addToChannelizationWhitelist(CHANNEL_CREATOR, {gasLimit: 500000});
      
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel, {gasLimit: 2000000});
        
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(DELEGATED_CONTRACT_FEES);
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, DELEGATED_CONTRACT_FEES);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).subscribeDelegated(CHANNEL_CREATOR, BOB);
      });

      it("should revert if anyone other than gov calls the function", async function(){
        const tx = EPNSCoreV1Proxy.connect(CHARLIESIGNER).withdrawDaiFunds();
        await expect(tx).to.be.revertedWith("EPNSCore::onlyGov, user is not governance");
      });

      it("should withdraw dai funds and update correct values", async function(){

        const ownerDaiFundsBefore = await EPNSCoreV1Proxy.ownerDaiFunds();
        const proxyDaiBalanceBefore = await MOCKDAI.balanceOf(EPNSCoreV1Proxy.address);
        const govDaiBalanceBefore = await MOCKDAI.balanceOf(ADMIN);

        await EPNSCoreV1Proxy.withdrawDaiFunds();

        const ownerDaiFundsAfter = await EPNSCoreV1Proxy.ownerDaiFunds();
        const proxyDaiBalanceAfter = await MOCKDAI.balanceOf(EPNSCoreV1Proxy.address);
        const govDaiBalanceAfter = await MOCKDAI.balanceOf(ADMIN);

        // expect(ownerDaiFundsBefore.sub(ADD_CHANNEL_MIN_POOL_CONTRIBUTION)).to.equal(ownerDaiFundsAfter);
        expect(proxyDaiBalanceBefore.sub(DELEGATED_CONTRACT_FEES)).to.equal(proxyDaiBalanceAfter);
        expect(govDaiBalanceBefore.add(DELEGATED_CONTRACT_FEES)).to.equal(govDaiBalanceAfter);
      });

      it("should emit Withdrawal when gov calls the function", async function(){
        const tx = EPNSCoreV1Proxy.withdrawDaiFunds();
        
        await expect(tx)
          .to.emit(EPNSCoreV1Proxy, 'Withdrawal')
          .withArgs(ADMIN, MOCKDAI.address, DELEGATED_CONTRACT_FEES);
      });
    });

    describe("Testing withdrawEthFunds", function(){
      beforeEach(async function(){
        const CHANNEL_TYPE = 2;
        const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

        await EPNSCoreV1Proxy.connect(ADMINSIGNER).addToChannelizationWhitelist(CHANNEL_CREATOR, {gasLimit: 500000});
        await CHANNEL_CREATORSIGNER.sendTransaction({
          from: CHANNEL_CREATOR,
          to: EPNSCoreV1Proxy.address,
          value: ADD_CHANNEL_MIN_POOL_CONTRIBUTION
        });
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFees(CHANNEL_TYPE, testChannel, {gasLimit: 2000000});
      });

      it("should revert if anyone other than gov calls the function", async function(){
        const tx = EPNSCoreV1Proxy.connect(CHARLIESIGNER).withdrawEthFunds();
        await expect(tx).to.be.revertedWith("EPNSCore::onlyGov, user is not governance");
      });

      // it("should withdraw dai funds and update correct values", async function(){
      //   const govEthBalanceBefore = await ADMINSIGNER.getBalance();
      //   console.log("qqqwqqw",govEthBalanceBefore.toString())
      //   const tx = await EPNSCoreV1Proxy.withdrawEthFunds();
      //   console.log(tx, "tx")
      //   const txFees = tx.gasPrice.mul(tx.gasLimit);
      //   console.log(txFees.toString())
      //   console.log("ADmin", ADD_CHANNEL_MIN_POOL_CONTRIBUTION.toString());
      //   const govEthBalanceAfter = await ADMINSIGNER.getBalance();
      //   console.log("qwew",govEthBalanceAfter.toString())
      //   expect(govEthBalanceBefore.sub(txFees).add(ADD_CHANNEL_MIN_POOL_CONTRIBUTION)).to.equal(govEthBalanceAfter);
      // });

      it("should emit Withdrawal when gov calls the function", async function(){
        const tx = EPNSCoreV1Proxy.withdrawEthFunds();
        
        await expect(tx)
          .to.emit(EPNSCoreV1Proxy, 'Withdrawal')
          .withArgs(ADMINSIGNER.address, MOCKDAI.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
      });
    });
  });

  describe("Testing getter functions", function(){
    it("should return the correct address from public key", async function(){
      const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)  
      const wallet = await EPNSCoreV1Proxy.getWalletFromPublicKey(publicKey.slice(1));

      expect(wallet).to.equal(CHANNEL_CREATOR);
    });

    it("should return true if member exists", async function(){
      const CHANNEL_TYPE = 2;
      await EPNSCoreV1Proxy.connect(ADMINSIGNER).addToChannelizationWhitelist(CHANNEL_CREATOR, {gasLimit: 500000});
      
      const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");        

      await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
      await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

      const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)
      const tx = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFeesAndPublicKey(CHANNEL_TYPE, testChannel, publicKey.slice(1), {gasLimit: 2000000});
      await EPNSCoreV1Proxy.connect(BOBSIGNER).subscribe(CHANNEL_CREATOR);

      const exists = await EPNSCoreV1Proxy.memberExists(BOB, CHANNEL_CREATOR);
      expect(exists).to.equal(true);
    });

    describe("testing getChannelFSRatio", function(){
      it("should return correct values for getChannelFSRatio", async function(){
        const CHANNEL_TYPE = 2;
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).addToChannelizationWhitelist(CHANNEL_CREATOR, {gasLimit: 500000});
        const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");        

        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

        const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)
        const tx = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFeesAndPublicKey(CHANNEL_TYPE, testChannel, publicKey.slice(1), {gasLimit: 2000000});
        const subsTx = await EPNSCoreV1Proxy.connect(BOBSIGNER).subscribe(CHANNEL_CREATOR);

        const ratioContract = await EPNSCoreV1Proxy.getChannelFSRatio(CHANNEL_CREATOR, subsTx.blockNumber)

        const channel = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);
        const groupHistoricalZ = await EPNSCoreV1Proxy.groupHistoricalZ();
        const groupFairShareCount = await EPNSCoreV1Proxy.groupFairShareCount();
        const groupLastUpdate = await EPNSCoreV1Proxy.groupLastUpdate();
        const groupNormalizedWeight = await EPNSCoreV1Proxy.groupNormalizedWeight();
        const getRatioCalc = calcChannelFairShare
        (
          subsTx.blockNumber, 
          channel.channelStartBlock, 
          channel.channelWeight,
          groupHistoricalZ,
          groupFairShareCount,
          groupLastUpdate,
          groupNormalizedWeight
        )

        expect(ratioContract).to.equal(getRatioCalc);
      });

      it("randomised test cases for getChannelFSRatio", async function(){
        const CHANNEL_TYPE = 2;
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).addToChannelizationWhitelist(CHANNEL_CREATOR, {gasLimit: 500000});
        const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

        const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFeesAndPublicKey(CHANNEL_TYPE, testChannel, publicKey.slice(1), {gasLimit: 2000000});

        const randomEntrance = [
          [BOB, BOBSIGNER, bn(Math.floor(Math.random() * 100))],
          [CHARLIE, CHARLIESIGNER, bn(Math.floor(Math.random() * 100))],
        ];
        
        let currentBlock = bn((await latestBlock()).toNumber());

        for (let x = 0; x < randomEntrance.length; x++) {
          const [signerAddress, signer, blockDiff] = randomEntrance[x];

          const advanceTo = currentBlock.add(blockDiff)
          const subsTx = await EPNSCoreV1Proxy.connect(signer).subscribe(CHANNEL_CREATOR);
          await advanceBlockTo(advanceTo.toString());

          const ratioContract = await EPNSCoreV1Proxy.connect(signer).getChannelFSRatio(CHANNEL_CREATOR, subsTx.blockNumber);

          const channel = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);
          const groupHistoricalZ = await EPNSCoreV1Proxy.groupHistoricalZ();
          const groupFairShareCount = await EPNSCoreV1Proxy.groupFairShareCount();
          const groupLastUpdate = await EPNSCoreV1Proxy.groupLastUpdate();
          const groupNormalizedWeight = await EPNSCoreV1Proxy.groupNormalizedWeight();
          const getRatioCalc = calcChannelFairShare
          (
            subsTx.blockNumber, 
            channel.channelStartBlock, 
            channel.channelWeight,
            groupHistoricalZ,
            groupFairShareCount,
            groupLastUpdate,
            groupNormalizedWeight
          )

          expect(Math.floor(getRatioCalc)).to.equal(ratioContract);
        }
      });
    });

    describe("testing getSubscriberFSRatio", function(){
      it("should return correct values for getSubscriberFSRatio", async function(){
        const CHANNEL_TYPE = 2;
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).addToChannelizationWhitelist(CHANNEL_CREATOR, {gasLimit: 500000});
        
        const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");        

        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

        const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)
        const tx = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFeesAndPublicKey(CHANNEL_TYPE, testChannel, publicKey.slice(1), {gasLimit: 2000000});
        const subsTx = await EPNSCoreV1Proxy.connect(BOBSIGNER).subscribe(CHANNEL_CREATOR);

        const getRatioContract = await EPNSCoreV1Proxy.getSubscriberFSRatio(CHANNEL_CREATOR, BOB, subsTx.blockNumber)

        const channel = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);
        const getRatioCalc = calcSubscriberFairShare
        (
          subsTx.blockNumber, 
          subsTx.blockNumber, 
          channel.channelHistoricalZ,
          channel.channelLastUpdate,
          channel.channelFairShareCount,
        )

        expect(getRatioContract).to.equal(getRatioCalc);
      });

      it("randomised test cases for getSubscriberFSRatio", async function(){
        const CHANNEL_TYPE = 2;
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).addToChannelizationWhitelist(CHANNEL_CREATOR, {gasLimit: 500000});
        const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

        const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFeesAndPublicKey(CHANNEL_TYPE, testChannel, publicKey.slice(1), {gasLimit: 2000000});

        const randomEntrance = [
          [BOB, BOBSIGNER, bn(Math.floor(Math.random() * 100))],
          [CHARLIE, CHARLIESIGNER, bn(Math.floor(Math.random() * 100))],
        ];
        let currentBlock = bn((await latestBlock()).toNumber());

        for (let x = 0; x < randomEntrance.length; x++) {
          const [signerAddress, signer, blockDiff] = randomEntrance[x];

          const advanceTo = currentBlock.add(blockDiff)
          const subsTx = await EPNSCoreV1Proxy.connect(signer).subscribe(CHANNEL_CREATOR);
          await advanceBlockTo(advanceTo.toString());

          const subscriberFairShare = await EPNSCoreV1Proxy.connect(signer).getSubscriberFSRatio(
            CHANNEL_CREATOR,
            signerAddress,
            advanceTo
          );

          const channel = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);
          const getRatioCalc = calcSubscriberFairShare
          (
            advanceTo,
            subsTx.blockNumber,
            channel.channelHistoricalZ.toNumber(),
            channel.channelLastUpdate,
            channel.channelFairShareCount,
          )

          console.log(subscriberFairShare.toNumber(), getRatioCalc)

          expect(Math.floor(getRatioCalc)).to.equal(subscriberFairShare);
        }
      });
    });

    describe("testing calcSingleChannelEarnRatio", function(){
      it("should return correct values for calcSingleChannelEarnRatio", async function(){
        const CHANNEL_TYPE = 2;
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).addToChannelizationWhitelist(CHANNEL_CREATOR, {gasLimit: 500000});
        
        const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");        

        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

        const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)
        const tx = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFeesAndPublicKey(CHANNEL_TYPE, testChannel, publicKey.slice(1), {gasLimit: 2000000});
        const subsTx = await EPNSCoreV1Proxy.connect(BOBSIGNER).subscribe(CHANNEL_CREATOR);
        
        const channelFSRatio = await EPNSCoreV1Proxy.getChannelFSRatio(CHANNEL_CREATOR, subsTx.blockNumber)
        const subscriberFSRatio = await EPNSCoreV1Proxy.getSubscriberFSRatio(CHANNEL_CREATOR, BOB, subsTx.blockNumber);

        const singleChannelEarnRatio = await EPNSCoreV1Proxy.calcSingleChannelEarnRatio(CHANNEL_CREATOR, BOB, subsTx.blockNumber);

        expect(singleChannelEarnRatio).to.equal(channelFSRatio.mul(subscriberFSRatio).div(ADJUST_FOR_FLOAT));
      });
    });

    describe("testing calcAllChannelsRatio", function(){
      it("should return correct values for calcAllChannelsRatio", async function(){
        const CHANNEL_TYPE = 2;
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).addToChannelizationWhitelist(CHANNEL_CREATOR, {gasLimit: 500000});
        
        const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");        

        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await MOCKDAI.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        
        const user = await EPNSCoreV1Proxy.users(BOB);
        const subscribedCount = user.subscribedCount;
        
        const publicKey = await getPubKey(CHANNEL_CREATORSIGNER)
        const tx = await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithFeesAndPublicKey(CHANNEL_TYPE, testChannel, publicKey.slice(1), {gasLimit: 2000000});
        const subsTx = await EPNSCoreV1Proxy.connect(BOBSIGNER).subscribe(CHANNEL_CREATOR);
        
        const channelFSRatio = await EPNSCoreV1Proxy.getChannelFSRatio(CHANNEL_CREATOR, subsTx.blockNumber)
        const subscriberFSRatio = await EPNSCoreV1Proxy.getSubscriberFSRatio(CHANNEL_CREATOR, BOB, subsTx.blockNumber);

        let ratio = bn(0);
        let channels = [CHANNEL_CREATOR]

        for (var i = 0; i < subscribedCount; i++) {
          const individualChannelShare = calcSingleChannelEarnRatio(channels[i], BOB, subsTx.blockNumber);
          ratio = ratio.add(individualChannelShare);
        }

        const allChannelsRatio = await EPNSCoreV1Proxy.calcAllChannelsRatio(BOB, subsTx.blockNumber);

        expect(allChannelsRatio).to.equal(ratio);
      });
    });
  });
});