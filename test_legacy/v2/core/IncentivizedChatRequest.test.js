const { ethers, waffle } = require("hardhat");

const { bn, tokensBN } = require("../../../helpers/utils");

const { epnsContractFixture } = require("../../common/fixturesV2");
const { expect } = require("../../common/expect");
const createFixtureLoader = waffle.createFixtureLoader;

describe("Incentivized chats", function () {
  const ADD_CHANNEL_MIN_POOL_CONTRIBUTION = tokensBN(50);

  let PushToken;
  let EPNSCoreV1Proxy;
  let EPNSCommV1Proxy;
  let ALICE;
  let BOB;
  let CHANNEL_CREATOR;
  let ADMINSIGNER;
  let ALICESIGNER;
  let BOBSIGNER;
  let CHARLIESIGNER;
  let CHANNEL_CREATORSIGNER;

  let loadFixture;
  before(async () => {
    [wallet, other] = await ethers.getSigners();
    loadFixture = createFixtureLoader([wallet, other]);
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
      
      EPNSCoreV1Proxy,
      EPNSCommV1Proxy,
      ROUTER,
      PushToken,
      EPNS_TOKEN_ADDRS,
    } = await loadFixture(epnsContractFixture));
    await EPNSCommV1Proxy.setPushTokenAddress(PushToken.address);
    // await EPNSCoreV1Proxy.setFeeAmount(10);

    await PushToken.transfer(BOB, ethers.utils.parseEther("10000"));
    await PushToken.transfer(ALICE, ethers.utils.parseEther("10000"));
    await PushToken.transfer(CHARLIE, ethers.utils.parseEther("10000"));
    await PushToken.transfer(CHANNEL_CREATOR, ethers.utils.parseEther("10000"));
    await PushToken.connect(BOBSIGNER).approve(
      EPNSCommV1Proxy.address,
      ethers.utils.parseEther("10000")
    );
    await PushToken.connect(ALICESIGNER).approve(
      EPNSCommV1Proxy.address,
      ethers.utils.parseEther("10000")
    );
    await PushToken.connect(CHARLIESIGNER).approve(
      EPNSCommV1Proxy.address,
      ethers.utils.parseEther("10000")
    );
    await PushToken.connect(CHANNEL_CREATORSIGNER).approve(
      EPNSCommV1Proxy.address,
      ethers.utils.parseEther("10000")
    );
  });

  it("should transfer tokens to core", async () => {
    const BobBalanceBefore = await PushToken.balanceOf(BOB);
    const CoreBalanceBefore = await PushToken.balanceOf(
      EPNSCoreV1Proxy.address
    );
    await EPNSCommV1Proxy.connect(BOBSIGNER).createIncentivizeChatRequest(
      ALICE,
      ethers.utils.parseEther("100")
    );
    const BobBalanceAfter = await PushToken.balanceOf(BOB);
    const CoreBalanceAfter = await PushToken.balanceOf(EPNSCoreV1Proxy.address);
    expect(BobBalanceAfter).to.be.equal(ethers.utils.parseEther("9900"));
    expect(CoreBalanceAfter).to.be.equal(ethers.utils.parseEther("100"));
  });
  it("should update the struct", async () => {
    await EPNSCommV1Proxy.connect(BOBSIGNER).createIncentivizeChatRequest(
      ALICE,
      ethers.utils.parseEther("100")
    );
    blockTimestamp = (await ethers.provider.getBlock("latest")).timestamp;

    const chatData = await EPNSCommV1Proxy.userChatData(BOB);

    expect(chatData.requestSender).to.be.equal(BOB);

    expect(chatData.timestamp).to.be.equal(blockTimestamp);

    expect(chatData.amountDeposited).to.be.equal(
      ethers.utils.parseEther("100")
    );
  });

  it("should call handleChatRequest in core and it should fail if caller is not Comm ", async () => {
    await expect(
      EPNSCoreV1Proxy.createIncentivizedChatRequest(
        BOB,
        ALICE,
        ethers.utils.parseEther("100")
      )
    ).to.be.revertedWith(
      "UnauthorizedCaller"
    );
    const beforeCelebFunds = await EPNSCoreV1Proxy.celebUserFunds(ALICE);
    const beforePoolFees = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
    await EPNSCommV1Proxy.connect(BOBSIGNER).createIncentivizeChatRequest(
      ALICE,
      ethers.utils.parseEther("100")
    );
    const expectedCelebFunds = beforeCelebFunds + ethers.utils.parseEther("90");
    const expectedPoolFees = beforeCelebFunds + ethers.utils.parseEther("10");
    expect(await EPNSCoreV1Proxy.celebUserFunds(ALICE)).to.be.equal(
      expectedCelebFunds
    );
    expect(await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES()).to.be.equal(
      expectedPoolFees
    );
  });

  it("should emit events in both contracts ", async () => {
    const txn = await EPNSCommV1Proxy.connect(
      BOBSIGNER
    ).createIncentivizeChatRequest(ALICE, ethers.utils.parseEther("100"));

    await expect(txn)
      .to.emit(EPNSCommV1Proxy, "IncentivizeChatReqInitiated")
      .withArgs(
        BOB,
        ALICE,
        ethers.utils.parseEther("100"),
        (
          await ethers.provider.getBlock("latest")
        ).timestamp
      );

    await expect(txn)
      .to.emit(EPNSCoreV1Proxy, "IncentivizeChatReqReceived")
      .withArgs(
        BOB,
        ALICE,
        ethers.utils.parseEther("90"),
        await EPNSCoreV1Proxy.FEE_AMOUNT(),
        (
          await ethers.provider.getBlock("latest")
        ).timestamp
      );
  });

  it("celeb should be able to claim the funds", async () => {
    await EPNSCommV1Proxy.connect(BOBSIGNER).createIncentivizeChatRequest(
      ALICE,
      ethers.utils.parseEther("100")
    );
    const beforeBalance = await PushToken.balanceOf(ALICE);
    const avaialbleToClaim = await EPNSCoreV1Proxy.celebUserFunds(ALICE);
    const claim = avaialbleToClaim.toString();
    await EPNSCoreV1Proxy.connect(ALICESIGNER).claimChatIncentives(claim);

    const expectedBalance = beforeBalance.add(avaialbleToClaim);
    expect(await PushToken.balanceOf(ALICE)).to.be.equal(expectedBalance);
  });

  describe("Multiple celebs", async () => {

    beforeEach(async()=>{
      await EPNSCommV1Proxy.connect(BOBSIGNER).createIncentivizeChatRequest(
        ALICE,
        ethers.utils.parseEther("100")
      );
      await EPNSCommV1Proxy.connect(BOBSIGNER).createIncentivizeChatRequest(
        CHARLIE,
        ethers.utils.parseEther("100")
      );
    })
    it("Should update the struct", async () => {
      
      blockTimestamp = (await ethers.provider.getBlock("latest")).timestamp;

      const chatData = await EPNSCommV1Proxy.userChatData(BOB);

      expect(chatData.requestSender).to.be.equal(BOB);
      expect(chatData.timestamp).to.be.equal(blockTimestamp);
      expect(chatData.amountDeposited).to.be.equal(
        ethers.utils.parseEther("200")
      );
    });
    it("ALICE should be able to withdraw funds",async()=>{
      const beforeBalance = await PushToken.balanceOf(ALICE);
    const avaialbleToClaim = await EPNSCoreV1Proxy.celebUserFunds(ALICE);
    const claim = avaialbleToClaim.toString();
    expect(claim).to.be.equal(ethers.utils.parseEther("90"))
    await EPNSCoreV1Proxy.connect(ALICESIGNER).claimChatIncentives(claim);

    const expectedBalance = beforeBalance.add(avaialbleToClaim);
    expect(await PushToken.balanceOf(ALICE)).to.be.equal(expectedBalance);
    })
    it("CHARLIE should be able to withdraw funds",async()=>{
      const beforeBalance = await PushToken.balanceOf(CHARLIE);
    const avaialbleToClaim = await EPNSCoreV1Proxy.celebUserFunds(CHARLIE);
    const claim = avaialbleToClaim.toString();
    expect(claim).to.be.equal(ethers.utils.parseEther("90"))
    await EPNSCoreV1Proxy.connect(CHARLIESIGNER).claimChatIncentives(claim);

    const expectedBalance = beforeBalance.add(avaialbleToClaim);
    expect(await PushToken.balanceOf(CHARLIE)).to.be.equal(expectedBalance);
    })
  });
});
