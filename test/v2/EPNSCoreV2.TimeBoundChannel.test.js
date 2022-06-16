const { ethers,waffle } = require("hardhat");

const {
  bn,
  tokensBN,
  ChannelAction,
  readjustFairShareOfChannels,
} = require("../../helpers/utils");


const {epnsContractFixture,tokenFixture} = require("../common/fixtures")
const {expect} = require("../common/expect")
const createFixtureLoader = waffle.createFixtureLoader;

describe("EPNS CoreV2 Protocol", function () {
  const ADD_CHANNEL_MIN_POOL_CONTRIBUTION = tokensBN(50)
  const CHANNEL_DEACTIVATION_FEES = tokensBN(10)
  const ADD_CHANNEL_MAX_POOL_CONTRIBUTION = tokensBN(250000 * 50)
  const ADJUST_FOR_FLOAT = bn(10 ** 7)

  let PushToken;
  let EPNSCoreV1Proxy;
  let EPNSCommV1Proxy;
  let ADMIN;
  let ALICE;
  let BOB;
  let CHARLIE;
  let CHANNEL_CREATOR;
  let ADMINSIGNER;
  let ALICESIGNER;
  let BOBSIGNER;
  let CHARLIESIGNER;
  let CHANNEL_CREATORSIGNER;


  let loadFixture;
  before(async() => {
    [wallet, other] = await ethers.getSigners()
    loadFixture = createFixtureLoader([wallet, other])
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

    
    ({
      PROXYADMIN,
      EPNSCoreV1Proxy,
      EPNSCommV1Proxy, 
      ROUTER,
      PushToken,
      EPNS_TOKEN_ADDRS,
    } = await loadFixture(epnsContractFixture)); 

    ({MOCKDAI, ADAI} = await loadFixture(tokenFixture));

  });


  describe("EPNS CORE: Channel Creation Tests", function(){
    describe("Testing the Base Create Channel Function", function(){
      const CHANNEL_TYPE = 2;
      const TIME_BOUND_CHANNEL_TYPE = 4;
      const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");
      const ONE_DAY = 3600*24;

      beforeEach(async function(){
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
        await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
        await PushToken.transfer(BOB, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await PushToken.transfer(ALICE, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await PushToken.transfer(CHANNEL_CREATOR, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10));
        await PushToken.connect(BOBSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await PushToken.connect(ALICESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await PushToken.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10));
      });

      const getFutureTIme = async (futureTime) =>{
        const blockNumber = await ethers.provider.getBlockNumber();
        const block = await ethers.provider.getBlock(blockNumber);
        return block.timestamp + futureTime;
      }
      const passTime = async(time)=>{
        await network.provider.send("evm_increaseTime", [time]);
        await network.provider.send("evm_mine");
      }

      it("Should allow  to create time bound channel", async function(){
        const expiryTime = await getFutureTIme(ONE_DAY);
        const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(TIME_BOUND_CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION,expiryTime);

        await expect(tx)
          .to.emit(EPNSCoreV1Proxy, 'AddChannel')
          .withArgs(CHANNEL_CREATOR, TIME_BOUND_CHANNEL_TYPE, ethers.utils.hexlify(testChannel));
      });

      it("Should revert on creating channel with invalid expiry", async function(){
        await expect(
          EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(TIME_BOUND_CHANNEL_TYPE,testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION,0)
        ).to.be.revertedWith("EPNSCoreV1::createChannel: Invalid channelExpiryTime");
        
        // allow with valid channel type
        const expiryTime = await getFutureTIme(ONE_DAY);
        const tx = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(TIME_BOUND_CHANNEL_TYPE,testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION,expiryTime);
        await expect(tx).to.emit(EPNSCoreV1Proxy, 'AddChannel')
      });

      it("Should set correct _channelExpiryTime value", async function(){
        const expiryTime = await getFutureTIme(ONE_DAY);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(TIME_BOUND_CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION,expiryTime);
        const channelInfo = await EPNSCoreV1Proxy.channels(CHANNEL_CREATOR);
        expect(channelInfo.expiryTime).to.equal(expiryTime);
        expect(channelInfo.channelType).to.equal(TIME_BOUND_CHANNEL_TYPE);
      });

      it("It allows creator to destroy the time bound channel", async function(){
        const expiryTime = await getFutureTIme(ONE_DAY);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(TIME_BOUND_CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION,expiryTime);
        
        await passTime(ONE_DAY);

        const txn = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).destroyTimeBoundChannel(CHANNEL_CREATOR);
        
        await expect(txn)
          .to.emit(EPNSCoreV1Proxy,"TimeBoundChannelDestroyed")
          .withArgs(CHANNEL_CREATOR, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.sub(CHANNEL_DEACTIVATION_FEES));
      });

      it("Should only allow channel destruction after time is reached", async function(){
        const expiryTime = await getFutureTIme(15*ONE_DAY);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(TIME_BOUND_CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION,expiryTime);
        const txn = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).destroyTimeBoundChannel(CHANNEL_CREATOR);
        await expect(txn)
          .to.be.revertedWith("EPNSCoreV1::destroyTimeBoundChannel: Invalid Caller or Channel has not Expired Yet");

        // after time pass channel should be able to destoryed
        await passTime(15*ONE_DAY)

        const txn2 = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).destroyTimeBoundChannel(CHANNEL_CREATOR);
        await expect(txn2)
          .to.emit(EPNSCoreV1Proxy,"TimeBoundChannelDestroyed");
      });

      it("Should allow allow admin channel destruction after time is reached + 14days", async function(){
        const expiryTime = await getFutureTIme(15*ONE_DAY);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(TIME_BOUND_CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION,expiryTime);
        const txn = EPNSCoreV1Proxy.connect(ADMINSIGNER).destroyTimeBoundChannel(CHANNEL_CREATOR);
        await expect(txn)
          .to.be.revertedWith("EPNSCoreV1::destroyTimeBoundChannel: Invalid Caller or Channel has not Expired Yet");

        // after time pass channel should be able to destoryed
        await passTime(15*ONE_DAY + 14*ONE_DAY)

        const txn2 = EPNSCoreV1Proxy.connect(ADMINSIGNER).destroyTimeBoundChannel(CHANNEL_CREATOR);
        await expect(txn2)
          .to.emit(EPNSCoreV1Proxy,"TimeBoundChannelDestroyed");
      });

      it("Should decrement channel count on channel Destroty", async function(){
        const expiryTime = await getFutureTIme(ONE_DAY);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(TIME_BOUND_CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION,expiryTime);
        const channelCountBefore = await EPNSCoreV1Proxy.channelsCount();

        await passTime(ONE_DAY);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).destroyTimeBoundChannel(CHANNEL_CREATOR);
        
        const  channelCountAfter = await EPNSCoreV1Proxy.channelsCount();
        await expect(channelCountAfter).to.equal(channelCountBefore-1);
      });

      it("Gives refunds on channel destroy", async function(){
        const expiryTime = await getFutureTIme(ONE_DAY);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(TIME_BOUND_CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION,expiryTime);
        const userBalBefore = await PushToken.balanceOf(CHANNEL_CREATOR);
        
        await passTime(ONE_DAY);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).destroyTimeBoundChannel(CHANNEL_CREATOR);

        const userBalAfter = await PushToken.balanceOf(CHANNEL_CREATOR); 
        const expectedUserBalance = userBalBefore.add(ADD_CHANNEL_MIN_POOL_CONTRIBUTION.sub(CHANNEL_DEACTIVATION_FEES));
        expect(userBalAfter).to.equal(expectedUserBalance);
      });
      
      it("Reverts on destroying others channel", async function(){
        const expiryTime = await getFutureTIme(ONE_DAY);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(TIME_BOUND_CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION,expiryTime);
        
        await passTime(ONE_DAY);
        const txn =  EPNSCoreV1Proxy.connect(BOBSIGNER).destroyTimeBoundChannel(CHANNEL_CREATOR);
        
        await expect(txn).to.be.revertedWith("EPNSCoreV1::destroyTimeBoundChannel: Invalid Caller or Channel has not Expired Yet");
      });

      it("Reverts if user destroys channel twice", async function(){
        const expiryTime = await getFutureTIme(ONE_DAY);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(TIME_BOUND_CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION,expiryTime);
        await passTime(ONE_DAY);
        
        await  EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).destroyTimeBoundChannel(CHANNEL_CREATOR);
        const txn = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).destroyTimeBoundChannel(CHANNEL_CREATOR);
        
        await expect(txn).to.be.revertedWith("EPNSCoreV1::onlyActivatedChannels: Channel Deactivated, Blocked or Does Not Exist");
      });

      it("Should revert on Destroying the Deactivated channel", async function(){
        const expiryTime = await getFutureTIme(ONE_DAY);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(TIME_BOUND_CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION,expiryTime);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel()

        await passTime(ONE_DAY);

        const txn = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).destroyTimeBoundChannel(CHANNEL_CREATOR);
        await expect(txn).to.be.revertedWith("EPNSCoreV1::onlyActivatedChannels: Channel Deactivated, Blocked or Does Not Exist");
      });

      it("Should revert on Deactivating the Destroyed channel", async function(){
        const expiryTime = await getFutureTIme(ONE_DAY);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(TIME_BOUND_CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION,expiryTime);
        
        await passTime(ONE_DAY);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).destroyTimeBoundChannel(CHANNEL_CREATOR);
        
        const txn = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).deactivateChannel()
        await expect(txn).to.be.revertedWith("EPNSCoreV1::onlyActivatedChannels: Channel Deactivated, Blocked or Does Not Exist");
      });

      it("Should allow user to create channel again after destroying", async function(){
        var expiryTime = await getFutureTIme(ONE_DAY);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(TIME_BOUND_CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION,expiryTime);
        
        await passTime(ONE_DAY);
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).destroyTimeBoundChannel(CHANNEL_CREATOR);
        
        var expiryTime = await getFutureTIme(ONE_DAY);
        const txn = EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(TIME_BOUND_CHANNEL_TYPE, testChannel,ADD_CHANNEL_MIN_POOL_CONTRIBUTION,expiryTime);
        await expect(txn).to.emit(EPNSCoreV1Proxy,"AddChannel");
      });

    });
  });
});
