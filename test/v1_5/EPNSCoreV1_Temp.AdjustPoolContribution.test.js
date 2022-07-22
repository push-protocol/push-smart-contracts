const { utils } = require("ethers");
const { ethers, waffle} = require("hardhat");

const {expect} = require("../common/expect")
const {epnsContractFixture,tokenFixture} = require("../common/fixtures_temp")
const createFixtureLoader = waffle.createFixtureLoader;

const ADD_CHANNEL_MIN_POOL_CONTRIBUTION = utils.parseEther("50");
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
        CHARLIESIGNER = await charlieSigner.getAddress();
        ABYSIGNER = await abySigner.getAddress();

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
        // two channels were created .... 4 .. with contribution 50, 50, 500, 300
        const oldPoolFunds = utils.parseEther("900");

        // pause and swap
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).swapADaiForPush(0);

        const newPoolFunds = await EPNSCoreV1Proxy.POOL_FUNDS();
        console.log(newPoolFunds.toString());
        // admin updates channel pool contribution

        // const aliceChannelPoolContrib = await EPNSCoreV1Proxy.channels(ALICE).then(d => d.poolContribution);
        // const aliceChannelweight = await EPNSCoreV1Proxy.channels(ALICE).then(d => d.channelWeight);
        // console.log(`old Pool ${aliceChannelPoolContrib.toString()}`);
        // console.log(`old  Weight ${aliceChannelweight.toString()}`);

        await EPNSCoreV1Proxy.adjustChannelPoolContributions(
            0, // start index
            2, // end index
            oldPoolFunds,
            [ALICE, BOB] // chaneels addresses
        )


        const expectedPoolContribution = ADJUST_FOR_FLOAT.mul(newPoolFunds).div(oldPoolFunds)

        const aliceChannelNewPoolContrib = await EPNSCoreV1Proxy.channels(ALICE).then(d => d.poolContribution);
        const aliceChannelNewWeight = await EPNSCoreV1Proxy.channels(ALICE).then(d => d.channelWeight);

        // console.log(`New Pool ${aliceChannelNewPoolContrib.toString()}`);
        // console.log(`New Weight ${aliceChannelNewWeight.toString()}`);

        const bobChannelNewPoolContrib = await EPNSCoreV1Proxy.channels(BOB).then(d => d.poolContribution);

        expect(expectedPoolContribution).to.be.closeTo(aliceChannelNewPoolContrib, utils.parseEther("0.00001"))
        expect(expectedPoolContribution).to.be.closeTo(bobChannelNewPoolContrib, utils.parseEther("0.00001"))
    })

    it("Updates channel version",async()=>{
        // two channels were created .... 50x2
        const oldPoolFunds = utils.parseEther("100");

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

        const aliceChannelVersion = await EPNSCoreV1Proxy.channels(ALICE).then(d => d.channelVersion);
        const bobChannelVersion = await EPNSCoreV1Proxy.channels(BOB).then(d => d.channelVersion);
        const expectedChannelVersion = 2;

        expect(expectedChannelVersion).to.equal(aliceChannelVersion)
        expect(expectedChannelVersion).to.equal(bobChannelVersion)
    })

    it("Shall fall if not paused",async()=>{
        // two channels were created .... 50x2
        const oldPoolFunds = utils.parseEther("100");

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
})
