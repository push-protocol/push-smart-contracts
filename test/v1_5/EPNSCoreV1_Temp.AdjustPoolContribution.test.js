const { utils } = require("ethers");
const { ethers, waffle} = require("hardhat");

const {expect} = require("../common/expect")
const {epnsContractFixture,tokenFixture} = require("../common/fixtures_temp")
const createFixtureLoader = waffle.createFixtureLoader;

const ADD_CHANNEL_MIN_POOL_CONTRIBUTION = utils.parseEther("50");
const CHANNEL_TYPE = 2;
const TEST_CHANNEL_CTX = ethers.utils.toUtf8Bytes("test-channel-hello-world");

describe("AdjustChannelPoolContributions Test", function () {
    let EPNS;
    let EPNSCoreV1Proxy;
    let ALICESIGNER;
    let MOCKDAI
    let ADAI;
    let WETH_ADDRS;
    let ROUTER;
    let EPNS_TOKEN_ADDRS;

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
        ] = await ethers.getSigners();

        ADMINSIGNER = adminSigner;
        ALICESIGNER = aliceSigner;
        BOBSIGNER = bobSigner;

        ADMIN = await adminSigner.getAddress();
        ALICE = await aliceSigner.getAddress();
        BOB = await bobSigner.getAddress();

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
    });

    it("Updates channel poolContribution properly",async()=>{
        // two channels were created .... 50x2
        const oldPoolFunds = utils.parseEther("100"); 

        // pause and swap
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).swapADaiForPush(0);

        const newPoolFunds = await EPNSCoreV1Proxy.POOL_FUNDS();
        
        // admin updates channel pool contribution
        await EPNSCoreV1Proxy.adjustChannelPoolContributions(
            0, // start index
            2, // end index
            oldPoolFunds,
            [ALICE, BOB] // chaneels addresses 
        )
        
        const expectedPoolContribution = ADD_CHANNEL_MIN_POOL_CONTRIBUTION.mul(newPoolFunds).div(oldPoolFunds)
        
        const aliceChannelNewPoolContrib = await EPNSCoreV1Proxy.channels(ALICE).then(d => d.poolContribution);
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
})
