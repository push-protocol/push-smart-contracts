const { utils } = require("ethers");
const { ethers, waffle} = require("hardhat");

const {expect} = require("../common/expect")
const {epnsContractFixture,tokenFixture} = require("../common/fixtures")
const createFixtureLoader = waffle.createFixtureLoader;

const ADD_CHANNEL_MIN_POOL_CONTRIBUTION = utils.parseEther("50");



describe("Swap aDai with PUSH", function () {
    let EPNS;
    let EPNSCoreV1Proxy;
    let ALICESIGNER;
    let MOCKDAI
    let ADAI;

    const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");
    let loadFixture;
    before(async() => {
      [wallet, other] = await ethers.getSigners()
      loadFixture = createFixtureLoader([wallet, other])

    });

    beforeEach(async function () {
        const [
          adminSigner,
          aliceSigner,
        ] = await ethers.getSigners();
    
        ADMINSIGNER = adminSigner;
        ALICESIGNER = aliceSigner;
    
        ADMIN = await adminSigner.getAddress();
        ALICE = await aliceSigner.getAddress();
    
        ({
          PROXYADMIN,
          EPNSCoreV1Proxy, 
          ROUTER,
          EPNS,
          EPNS_TOKEN_ADDRS,
        } = await loadFixture(epnsContractFixture)); 

        ({MOCKDAI, ADAI} = await loadFixture(tokenFixture));

        // DAI Token
        await MOCKDAI.connect(ALICESIGNER).mint(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await MOCKDAI.connect(ALICESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
  
    });
    

    it("allows admin to swap with aDai wit PUSH",async()=>{
        // contract PUSH prev bal
        const inital_push_bal = await EPNS.balanceOf(EPNSCoreV1Proxy.address);
        
        // Creating a channel so that contract has some aDAI
        const CHANNEL_TYPE = 2;
        await EPNSCoreV1Proxy.connect(ALICESIGNER).createChannelWithFees(
            CHANNEL_TYPE,
            testChannel,
            ADD_CHANNEL_MIN_POOL_CONTRIBUTION
        );

        // Allow admin to swap aDai with Eth
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).swapADaiForPush()
        const new_push_bal = await EPNS.balanceOf(EPNSCoreV1Proxy.address);
        expect(new_push_bal > inital_push_bal).to.equal(true);

        // After swap aDai and Dai balance should be zero
        const adaiBal = await ADAI.balanceOf(EPNSCoreV1Proxy.address)
        expect(adaiBal).to.equal(0)
        
        const daiBal = await MOCKDAI.balanceOf(EPNSCoreV1Proxy.address)
        expect(daiBal).to.equal(0)
    })

    it("allows only push admin to swap",async()=>{
        // Allow admin to swap aDai with Eth
        await expect(
            EPNSCoreV1Proxy.connect(ALICESIGNER).swapADaiForPush()
        ).to.be.revertedWith("EPNSCoreV1::onlyPushChannelAdmin: Caller not pushChannelAdmin");
    })

    it("reverts if aDai balace is zero",async()=>{
        await expect(
            EPNSCoreV1Proxy.connect(ADMINSIGNER).swapADaiForPush()
        ).to.be.revertedWith("EPNSCoreV1::swapADaiForPush: Contract ADai balance is zero");
    })
})