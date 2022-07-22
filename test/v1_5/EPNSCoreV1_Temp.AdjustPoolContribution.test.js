const { utils } = require("ethers");
const { ethers, waffle} = require("hardhat");

const {expect} = require("../common/expect")
const {epnsContractFixture,tokenFixture} = require("../common/fixtures_temp")
const {
    bn,
} = require("../../helpers/utils");

const createFixtureLoader = waffle.createFixtureLoader;

const ADD_CHANNEL_MIN_POOL_CONTRIBUTION = utils.parseEther("50");
const ADJUST_FOR_FLOAT = bn(10 ** 7)

const CHANNEL_TYPE = 2;
const TEST_CHANNEL_CTX = ethers.utils.toUtf8Bytes("test-channel-hello-world");

describe("AdjustChannelPoolContributions Test", function () {
    let EPNSCoreV1Proxy;
    let ALICESIGNER;
    let MOCKDAI;
    let BOBSIGNER;
    let CHARLIESIGNER;
    let ABYSIGNER;

    let loadFixture;
    before(async() => {
      [wallet, other] = await ethers.getSigners()
      loadFixture = createFixtureLoader([wallet, other])

    });

    beforeEach(async function () {
        const [
          adminSigner,
          aliceSigner,
          bobSigner,
          charlieSigner,
          abySigner,
        ] = await ethers.getSigners();

        ADMINSIGNER = adminSigner;
        ALICESIGNER = aliceSigner;
        BOBSIGNER = bobSigner;
        CHARLIESIGNER = charlieSigner;
        ABYSIGNER = abySigner;

        ADMIN = await adminSigner.getAddress();
        ALICE = await aliceSigner.getAddress();
        BOB = await bobSigner.getAddress();
        CHARLIE = await charlieSigner.getAddress();
        ABY = await abySigner.getAddress();

        ({
          PROXYADMIN,
          EPNSCoreV1Proxy,
          ROUTER,
          EPNS,
          EPNS_TOKEN_ADDRS,
          WETH_ADDRS
        } = await loadFixture(epnsContractFixture));

        ({MOCKDAI, ADAI} = await loadFixture(tokenFixture));

        // Transfer  Token
        await MOCKDAI.connect(ALICESIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await MOCKDAI.connect(ALICESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

        await MOCKDAI.connect(BOBSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await MOCKDAI.connect(BOBSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

        await MOCKDAI.connect(CHARLIESIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10));
        await MOCKDAI.connect(CHARLIESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10));

        await MOCKDAI.connect(ABYSIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10));
        await MOCKDAI.connect(ABYSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10));

        // create channel
        await EPNSCoreV1Proxy.connect(ALICESIGNER).createChannelWithFees(
            CHANNEL_TYPE,
            TEST_CHANNEL_CTX,
            ADD_CHANNEL_MIN_POOL_CONTRIBUTION
        );

        await EPNSCoreV1Proxy.connect(BOBSIGNER).createChannelWithFees(
            CHANNEL_TYPE,
            TEST_CHANNEL_CTX,
            ADD_CHANNEL_MIN_POOL_CONTRIBUTION
        );

        await EPNSCoreV1Proxy.connect(CHARLIESIGNER).createChannelWithFees(
            CHANNEL_TYPE,
            TEST_CHANNEL_CTX,
            ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10)
        );

        await EPNSCoreV1Proxy.connect(ABYSIGNER).createChannelWithFees(
            CHANNEL_TYPE,
            TEST_CHANNEL_CTX,
            ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(6)
        );
    });

    it("Updates channel poolContribution properly",async()=>{
        // 4 channels were created .... 4 .. with contribution 50, 50, 500, 300
        const oldPoolFunds = utils.parseEther("900");

        // pause and swap
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).swapADaiForPush(0);

        const newPoolFunds = await EPNSCoreV1Proxy.POOL_FUNDS();
        await EPNSCoreV1Proxy.adjustChannelPoolContributions(
            0, // start index
            4, // end index
            oldPoolFunds,
            [ALICE, BOB, CHARLIE, ABY] // chaneels addresses
        )

        const aliceExpectedContribution = ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(newPoolFunds).div(oldPoolFunds)
        const bobExpectedContribution = ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(newPoolFunds).div(oldPoolFunds)
        const charlieExpectedContribution = ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10).mul(newPoolFunds).div(oldPoolFunds)
        const abyExpectedContribution = ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(6).mul(newPoolFunds).div(oldPoolFunds)

        const aliceChannelNewPoolContrib = await EPNSCoreV1Proxy.channels(ALICE).then(d => d.poolContribution);
        const bobChannelNewPoolContrib = await EPNSCoreV1Proxy.channels(BOB).then(d => d.poolContribution);
        const charlieChannelNewPoolContrib = await EPNSCoreV1Proxy.channels(CHARLIE).then(d => d.poolContribution);
        const abyChannelNewPoolContrib = await EPNSCoreV1Proxy.channels(ABY).then(d => d.poolContribution);

        expect(aliceExpectedContribution).to.be.closeTo(aliceChannelNewPoolContrib, utils.parseEther("0.00001"))
        expect(bobExpectedContribution).to.be.closeTo(bobChannelNewPoolContrib, utils.parseEther("0.00001"))
        expect(charlieExpectedContribution).to.be.closeTo(charlieChannelNewPoolContrib, utils.parseEther("0.00001"))
        expect(abyExpectedContribution).to.be.closeTo(abyChannelNewPoolContrib, utils.parseEther("0.00001"))
    })

    it("Updates channel poolWeight properly",async()=>{
        // 4 channels were created .... 4 .. with contribution 50, 50, 500, 300
        const oldPoolFunds = utils.parseEther("900");

        // pause and swap
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).swapADaiForPush(0);

        const newPoolFunds = await EPNSCoreV1Proxy.POOL_FUNDS();

        await EPNSCoreV1Proxy.adjustChannelPoolContributions(
            0, // start index
            4, // end index
            oldPoolFunds,
            [ALICE, BOB, CHARLIE, ABY] // chaneels addresses
        )
        
        const aliceExpectedContribution = ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(newPoolFunds).div(oldPoolFunds)
        const bobExpectedContribution = ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(newPoolFunds).div(oldPoolFunds)
        const charlieExpectedContribution = ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(10).mul(newPoolFunds).div(oldPoolFunds)
        const abyExpectedContribution = ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(6).mul(newPoolFunds).div(oldPoolFunds)

        const aliceExpectedWeight = aliceExpectedContribution.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION)
        const bobExpectedWeight = bobExpectedContribution.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION)
        const charlieExpectedWeight = charlieExpectedContribution.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION)
        const abyExpectedWeight = abyExpectedContribution.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION)
        
        const aliceChannelNewWeight = await EPNSCoreV1Proxy.channels(ALICE).then(d => d.channelWeight);
        const bobChannelNewWeight = await EPNSCoreV1Proxy.channels(BOB).then(d => d.channelWeight);
        const charlieChannelWeight = await EPNSCoreV1Proxy.channels(CHARLIE).then(d => d.channelWeight);
        const abyChannelWeight = await EPNSCoreV1Proxy.channels(ABY).then(d => d.channelWeight);

        expect(aliceExpectedWeight).to.be.closeTo(aliceChannelNewWeight, 1)
        expect(bobExpectedWeight).to.be.closeTo(bobChannelNewWeight, 1)
        expect(charlieExpectedWeight).to.be.closeTo(charlieChannelWeight, 1)
        expect(abyExpectedWeight).to.be.closeTo(abyChannelWeight, 1)
    })

    it("Updates channel version",async()=>{
        const oldPoolFunds = utils.parseEther("900");

        // pause and swap
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).swapADaiForPush(0);

        // admin updates channel pool contribution
        await EPNSCoreV1Proxy.adjustChannelPoolContributions(
            0, // start index
            4, // end index
            oldPoolFunds,
            [ALICE, BOB, CHARLIE, ABY] // chaneels addresses
        )

        const aliceChannelVersion = await EPNSCoreV1Proxy.channels(ALICE).then(d => d.channelVersion);
        const bobChannelVersion = await EPNSCoreV1Proxy.channels(BOB).then(d => d.channelVersion);
        const charlieChannelVersion = await EPNSCoreV1Proxy.channels(CHARLIE).then(d => d.channelVersion);
        const abyChannelVersion = await EPNSCoreV1Proxy.channels(ABY).then(d => d.channelVersion);
        const expectedChannelVersion = 2;

        expect(expectedChannelVersion).to.equal(aliceChannelVersion)
        expect(expectedChannelVersion).to.equal(bobChannelVersion)
        expect(expectedChannelVersion).to.equal(charlieChannelVersion)
        expect(expectedChannelVersion).to.equal(abyChannelVersion)
    })

    it("Shall fall if not paused",async()=>{
        // 4 channels were created .... 50x2
        const oldPoolFunds = utils.parseEther("900");

        // without pause txn will fail
        const txn1 = EPNSCoreV1Proxy.adjustChannelPoolContributions(
            0, // start index
            2, // end index
            oldPoolFunds,
            [ALICE, BOB] // chaneels addresses
        )
        await expect(txn1).to.be.revertedWith("Pausable: not paused")

        // pause and swap
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).swapADaiForPush(0);

        // admin updates channel pool contribution
        await EPNSCoreV1Proxy.adjustChannelPoolContributions(
            0, // start index
            2, // end index
            oldPoolFunds,
            [ALICE, BOB] // chaneels addresses
        )

        // do version check
        const aliceChannelVersion = await EPNSCoreV1Proxy.channels(ALICE).then(d => d.channelVersion);
        const bobChannelVersion = await EPNSCoreV1Proxy.channels(BOB).then(d => d.channelVersion);
        const expectedChannelVersion = 2;
        expect(expectedChannelVersion).to.equal(aliceChannelVersion)
        expect(expectedChannelVersion).to.equal(bobChannelVersion)
    })

    it("Shall update the channel weights & pool contributio once",async()=>{
        // 4 channels were created .... 4 .. with contribution 50, 50, 500, 300
        const oldPoolFunds = utils.parseEther("900");

        // pause and swap
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).swapADaiForPush(0);

        // Add all instead ABY
        await EPNSCoreV1Proxy.adjustChannelPoolContributions(
            0, // start index
            3, // end index
            oldPoolFunds,
            [ALICE, BOB, CHARLIE] // chaneels addresses
        )

        const aliceChannelPoolContribInitial = await EPNSCoreV1Proxy.channels(ALICE).then(d => d.poolContribution);
        const bobChannelPoolContribInitial = await EPNSCoreV1Proxy.channels(BOB).then(d => d.poolContribution);
        const charlieChannelPoolContribInitial = await EPNSCoreV1Proxy.channels(CHARLIE).then(d => d.poolContribution);
        const abyChannelPoolContribInitial = await EPNSCoreV1Proxy.channels(ABY).then(d => d.poolContribution);


        // Add all including ABY
        await EPNSCoreV1Proxy.adjustChannelPoolContributions(
            0, // start index
            4, // end index
            oldPoolFunds,
            [ALICE, BOB, CHARLIE, ABY] // chaneels addresses
        )

        const aliceChannelPoolContribFinal = await EPNSCoreV1Proxy.channels(ALICE).then(d => d.poolContribution);
        const bobChannelPoolContribFinal = await EPNSCoreV1Proxy.channels(BOB).then(d => d.poolContribution);
        const charlieChannelPoolContribFinal = await EPNSCoreV1Proxy.channels(CHARLIE).then(d => d.poolContribution);
        const abyChannelPoolContribFinal = await EPNSCoreV1Proxy.channels(ABY).then(d => d.poolContribution);

        expect(aliceChannelPoolContribInitial).to.equal(aliceChannelPoolContribFinal)
        expect(bobChannelPoolContribInitial).to.equal(bobChannelPoolContribFinal);
        expect(charlieChannelPoolContribInitial).to.equal(charlieChannelPoolContribFinal);
        expect(abyChannelPoolContribInitial).to.not.equal(abyChannelPoolContribFinal);
    })

    it("Should not update non exsting channel",async()=>{
        // 4 channels were created .... 4 .. with contribution 50, 50, 500, 300
        const oldPoolFunds = utils.parseEther("900");
        
        // pause and swap
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).swapADaiForPush(0);

        const FALSE_CHANNEL_ADDRESS = "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
        const falseChannelContribInitial = await EPNSCoreV1Proxy.channels(FALSE_CHANNEL_ADDRESS).then(d => d.poolContribution);
        const falseChannelVersionInitial = await EPNSCoreV1Proxy.channels(FALSE_CHANNEL_ADDRESS).then(d => d.channelVersion);
        expect(falseChannelContribInitial).to.equal(0)
        expect(falseChannelVersionInitial).to.equal(0)

        // Add all including ABY
        await EPNSCoreV1Proxy.adjustChannelPoolContributions(
            0, // start index
            5, // end index
            oldPoolFunds,
            [ALICE, BOB, CHARLIE, ABY, FALSE_CHANNEL_ADDRESS] // chaneels addresses
        )

        const falseChannelContribFinal = await EPNSCoreV1Proxy.channels(FALSE_CHANNEL_ADDRESS).then(d => d.poolContribution);
        const falseChannelVersionFinal = await EPNSCoreV1Proxy.channels(FALSE_CHANNEL_ADDRESS).then(d => d.channelVersion);
        expect(falseChannelContribFinal).to.equal(0)
        expect(falseChannelVersionFinal).to.equal(0)
    })
})
