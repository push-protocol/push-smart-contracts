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
    let ROUTER;

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
        
        // get expected Token ammount after the swap
        const initialAdaiBal = await ADAI.balanceOf(EPNSCoreV1Proxy.address);
        const ammtToReceive = await ROUTER.getAmountsOut(
            initialAdaiBal,
            [
                "0xf80A32A835F79D7787E8a8ee5721D0fEaFd78108",
                "0xc778417E063141139Fce010982780140Aa0cD5Ab",
                "0xf418588522d5dd018b425E472991E52EBBeEEEEE"
            ],
        );
        const minAmmountToReceive = ammtToReceive[0];

        // Admin to swaps aDai for PUSH
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).swapADaiForPush();
        const new_push_bal = await EPNS.balanceOf(EPNSCoreV1Proxy.address);
        expect(new_push_bal).to.be.at.least(minAmmountToReceive);
        expect(new_push_bal).to.be.above(inital_push_bal);

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