const { ethers,waffle} = require("hardhat");
const {epnsContractFixture} = require("../common/fixtures")
const {expect} = require("../common/expect")
const createFixtureLoader = waffle.createFixtureLoader;

const {
  tokensBN,
} = require("../../helpers/utils");

describe("EPNS CoreV2 Protocol", function () {
  const FEE_AMOUNT = tokensBN(10)
  const ADJUST_FOR_FLOAT = bn(10 ** 7)
  const MIN_POOL_CONTRIBUTION = tokensBN(1)
  const ADD_CHANNEL_MIN_FEES = tokensBN(50)
  const ADD_CHANNEL_MAX_POOL_CONTRIBUTION = tokensBN(250 * 50)

  let EPNSCoreV1Proxy;
  let EPNSCommV1Proxy;
  let ALICE;
  let BOB;
  let ADMINSIGNER;
  let ALICESIGNER;
  let BOBSIGNER;


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

  });

 describe("EPNS CORE: Channel Creation Tests", function(){
   describe("Testing the Base Create Channel Function", function()
      {
          const CHANNEL_TYPE = 2;
          const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");
          const channelNewIdentity = ethers.utils.toUtf8Bytes("test-channel-hello-world");

           beforeEach(async function(){
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).setMinPoolContribution(ethers.utils.parseEther('1'));
            await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
            await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
            await PushToken.transfer(BOB, ADD_CHANNEL_MIN_FEES.mul(20));
            await PushToken.transfer(ALICE, ADD_CHANNEL_MIN_FEES.mul(20));
            await PushToken.connect(BOBSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_FEES.mul(20));
            await PushToken.connect(ALICESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_FEES.mul(20));

            await EPNSCoreV1Proxy.connect(BOBSIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel, ADD_CHANNEL_MIN_FEES,0);
            await EPNSCoreV1Proxy.connect(ALICESIGNER).createChannelWithPUSH(CHANNEL_TYPE, testChannel, ADD_CHANNEL_MIN_FEES,0);
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
            const tx = EPNSCoreV1Proxy.connect(BOBSIGNER).updateChannelMeta(BOB, channelNewIdentity, ADD_CHANNEL_MIN_FEES);
            await expect(tx).to.be.revertedWith("Pausable: paused")
          });

          it('Should revert If channel address is 0x0', async function(){
            const zeroAddress = "0x0000000000000000000000000000000000000000";
            const tx = EPNSCoreV1Proxy.connect(ALICESIGNER).updateChannelMeta(
              zeroAddress,
              channelNewIdentity,
              ADD_CHANNEL_MIN_FEES
            );
            await expect(tx).to.be.revertedWith("EPNSCoreV1_5::onlyChannelOwner: Channel not Exists or Invalid Channel Owner")
          });

          it("Should revert IF Caller is not the Channel Owner", async function(){
            const tx = EPNSCoreV1Proxy.connect(ALICESIGNER).updateChannelMeta(BOB, channelNewIdentity, ADD_CHANNEL_MIN_FEES);
            await expect(tx).to.be.revertedWith("EPNSCoreV1_5::onlyChannelOwner: Channel not Exists or Invalid Channel Owner")
          });

          it("Should revert IF Amount is 0 Push tokens", async function(){
            const LESS_AMOUNT = tokensBN(0)
            const tx = EPNSCoreV1Proxy.connect(BOBSIGNER).updateChannelMeta(BOB, channelNewIdentity, LESS_AMOUNT);
            await expect(tx).to.be.revertedWith("EPNSCoreV1_5::updateChannelMeta: Insufficient Deposit Amount")
          });

          it("Should revert IF Amount is less than Required Push tokens", async function(){
            const LESS_AMOUNT = tokensBN(20)
            const tx = EPNSCoreV1Proxy.connect(BOBSIGNER).updateChannelMeta(BOB, channelNewIdentity, LESS_AMOUNT);

            await expect(tx).to.be.revertedWith("EPNSCoreV1_5::updateChannelMeta: Insufficient Deposit Amount")
          });

          it("Updating Channel Meta should update CHANNEL_POOL_FUNDS and PROTOCOL_POOL_FEES correctly", async function(){
            const poolFunds_before  = await EPNSCoreV1Proxy.CHANNEL_POOL_FUNDS();
            const poolFees_before = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();

            const tx = await EPNSCoreV1Proxy.connect(BOBSIGNER).updateChannelMeta(BOB, channelNewIdentity, ADD_CHANNEL_MIN_FEES);

            const block_num = tx.blockNumber;
            const channel = await EPNSCoreV1Proxy.channels(BOB)
            const poolFunds_after = await EPNSCoreV1Proxy.CHANNEL_POOL_FUNDS();
            const poolFees_after = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
            const counter = await EPNSCoreV1Proxy.channelUpdateCounter(BOB);

            const expectedPoolFundsAfter = poolFunds_before;
            const expectedPoolFeesAfter = poolFees_before.add(ADD_CHANNEL_MIN_FEES);

            await expect(counter).to.equal(1);
            await expect(channel.channelUpdateBlock).to.equal(block_num);
            await expect(poolFunds_after).to.equal(expectedPoolFundsAfter);
            await expect(poolFees_after).to.equal(expectedPoolFeesAfter);

          });

          it("Contract should recieve 50 Push tokens for 1st Channel Update", async function(){
            const pushBalanceBefore_coreContract = await PushToken.balanceOf(EPNSCoreV1Proxy.address);
            await EPNSCoreV1Proxy.connect(BOBSIGNER).updateChannelMeta(BOB, channelNewIdentity, ADD_CHANNEL_MIN_FEES);
            const pushBalanceAfter_coreContract = await PushToken.balanceOf(EPNSCoreV1Proxy.address);
            expect(pushBalanceAfter_coreContract.sub(pushBalanceBefore_coreContract)).to.equal(ADD_CHANNEL_MIN_FEES);
          });

          it("2nd Channel Update should NOT execute if Fees deposited is NOT 50 * 2 Push Tokens", async function(){
            await EPNSCoreV1Proxy.connect(BOBSIGNER).updateChannelMeta(BOB, channelNewIdentity, ADD_CHANNEL_MIN_FEES);
            const counter_1 = await EPNSCoreV1Proxy.channelUpdateCounter(BOB);
            const tx_2nd = EPNSCoreV1Proxy.connect(BOBSIGNER).updateChannelMeta(BOB, channelNewIdentity, ADD_CHANNEL_MIN_FEES);

            await expect(counter_1).to.equal(1);
            await expect(tx_2nd).to.be.revertedWith("EPNSCoreV1_5::updateChannelMeta: Insufficient Deposit Amount")
          });

          it("Contract should recieve 500 Push tokens for 4th Channel Update", async function(){
            const pushBalanceBefore_coreContract = await PushToken.balanceOf(EPNSCoreV1Proxy.address);

            await EPNSCoreV1Proxy.connect(BOBSIGNER).updateChannelMeta(BOB, channelNewIdentity, ADD_CHANNEL_MIN_FEES);
            await EPNSCoreV1Proxy.connect(BOBSIGNER).updateChannelMeta(BOB, channelNewIdentity, ADD_CHANNEL_MIN_FEES.mul(2));
            await EPNSCoreV1Proxy.connect(BOBSIGNER).updateChannelMeta(BOB, channelNewIdentity, ADD_CHANNEL_MIN_FEES.mul(3));
            await EPNSCoreV1Proxy.connect(BOBSIGNER).updateChannelMeta(BOB, channelNewIdentity, ADD_CHANNEL_MIN_FEES.mul(4));

            const pushBalanceAfter_coreContract = await PushToken.balanceOf(EPNSCoreV1Proxy.address);

            expect(pushBalanceAfter_coreContract.sub(pushBalanceBefore_coreContract)).to.equal(ADD_CHANNEL_MIN_FEES.mul(10));

          });

          it("Grows the update fees linearly", async function(){
            const numUpdates = 5;

            for (let i = 1; i <= numUpdates; i++) {
              // should revert on paying same fees on lastupdate
              const feePaidOnLastUpdate = ADD_CHANNEL_MIN_FEES.mul(i-1);
              await expect(
                EPNSCoreV1Proxy.connect(BOBSIGNER).updateChannelMeta(BOB, channelNewIdentity, feePaidOnLastUpdate)
              ).to.be.revertedWith("EPNSCoreV1_5::updateChannelMeta: Insufficient Deposit Amount")

              // should pass on incresing fees linearly
              const feeToPay = ADD_CHANNEL_MIN_FEES.mul(i);
              await EPNSCoreV1Proxy.connect(BOBSIGNER).updateChannelMeta(BOB, channelNewIdentity, feeToPay)
            }

          });

          it("Should Emit right args for Update Channel Meta correctly for right Amount -> 50 PUSH Tokens", async function(){
            const tx = EPNSCoreV1Proxy.connect(BOBSIGNER).updateChannelMeta(BOB, channelNewIdentity, ADD_CHANNEL_MIN_FEES);
            await expect(tx)
              .to.emit(EPNSCoreV1Proxy, 'UpdateChannel')
              .withArgs(BOB, ethers.utils.hexlify(channelNewIdentity));
          });

          it("Should Emit right args for Update Channel Meta correctly for right Amount -> 50 PUSH Tokens", async function(){
            const tx = EPNSCoreV1Proxy.connect(BOBSIGNER).updateChannelMeta(BOB, channelNewIdentity, ADD_CHANNEL_MIN_FEES);
            await expect(tx)
              .to.emit(EPNSCoreV1Proxy, 'UpdateChannel')
              .withArgs(BOB, ethers.utils.hexlify(channelNewIdentity));
          });

          it("Only allows activate channel to be updated", async function(){
            // on channel deactivation cannnot create channel
            await  EPNSCoreV1Proxy.connect(BOBSIGNER).deactivateChannel();
            // await expect(
            //   EPNSCoreV1Proxy.connect(BOBSIGNER).updateChannelMeta(BOB, channelNewIdentity, ADD_CHANNEL_MIN_FEES)
            // ).to.be.revertedWith("EPNSCoreV1_5::onlyChannelOwner: Channel not Exists or Invalid Channel Owner");
          });
    });

});
});