const { utils } = require("ethers");
const { ethers, waffle} = require("hardhat");

const {expect} = require("../common/expect")
const {epnsContractFixture,tokenFixture} = require("../common/fixtures_temp")
const {
    bn,
} = require("../../helpers/utils");

const createFixtureLoader = waffle.createFixtureLoader;

const ADJUST_FOR_FLOAT = bn(10 ** 7)
const FEE_AMOUNT = utils.parseEther("10");
const MIN_POOL_CONTRIBUTION = utils.parseEther("1");
const ADD_CHANNEL_MIN_FEES = utils.parseEther("50");

const CHANNEL_TYPE = 2;
const TEST_CHANNEL_CTX = ethers.utils.toUtf8Bytes("test-channel-hello-world");

describe("AdjustChannelPoolContributions Test", function () {
    let EPNSCoreV1Proxy;
    let ALICESIGNER;
    let MOCKDAI;
    let BOBSIGNER;
    let CHARLIESIGNER;
    let ABYSIGNER;
    let TempStoreContract;

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
        await MOCKDAI.connect(ALICESIGNER).mint(ADD_CHANNEL_MIN_FEES);
        await MOCKDAI.connect(ALICESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_FEES);

        await MOCKDAI.connect(BOBSIGNER).mint(ADD_CHANNEL_MIN_FEES);
        await MOCKDAI.connect(BOBSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_FEES);

        await MOCKDAI.connect(CHARLIESIGNER).mint(ADD_CHANNEL_MIN_FEES.mul(10));
        await MOCKDAI.connect(CHARLIESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_FEES.mul(10));

        await MOCKDAI.connect(ABYSIGNER).mint(ADD_CHANNEL_MIN_FEES.mul(10));
        await MOCKDAI.connect(ABYSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_FEES.mul(10));

        // create channel
        await EPNSCoreV1Proxy.connect(ALICESIGNER).createChannelWithFees(
            CHANNEL_TYPE,
            TEST_CHANNEL_CTX,
            ADD_CHANNEL_MIN_FEES
        );

        await EPNSCoreV1Proxy.connect(BOBSIGNER).createChannelWithFees(
            CHANNEL_TYPE,
            TEST_CHANNEL_CTX,
            ADD_CHANNEL_MIN_FEES
        );

        await EPNSCoreV1Proxy.connect(CHARLIESIGNER).createChannelWithFees(
            CHANNEL_TYPE,
            TEST_CHANNEL_CTX,
            ADD_CHANNEL_MIN_FEES.mul(10)
        );

        await EPNSCoreV1Proxy.connect(ABYSIGNER).createChannelWithFees(
            CHANNEL_TYPE,
            TEST_CHANNEL_CTX,
            ADD_CHANNEL_MIN_FEES.mul(6)
        );
        
        // Temp Storage Contract
        TempStoreContract = await ethers.getContractFactory("TempStorage")
                                .then((c)=>c.deploy(EPNSCoreV1Proxy.address));
    });  

    it("Updates channel poolContribution adequately",async()=>{
        // 4 channels were created .... 4 .. with contribution 50, 50, 500, 300
        const oldPoolFunds = utils.parseEther("900");
        //169103 397346680543474387
        // pause and swap
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).swapADaiForPush(0);
        
        const newPoolFunds = await EPNSCoreV1Proxy.POOL_FUNDS();

        await EPNSCoreV1Proxy.adjustChannelPoolContributions(
            TempStoreContract.address, //Temp Contract
            0, // start index
            4, // end index
            oldPoolFunds,
            newPoolFunds,
            [ALICE, BOB, CHARLIE, ABY] // chaneels addresses
        )

        const aliceExpectedContribution = ADD_CHANNEL_MIN_FEES.mul(newPoolFunds).div(oldPoolFunds).sub(FEE_AMOUNT);
        const bobExpectedContribution = ADD_CHANNEL_MIN_FEES.mul(newPoolFunds).div(oldPoolFunds).sub(FEE_AMOUNT);
        const charlieExpectedContribution = ADD_CHANNEL_MIN_FEES.mul(10).mul(newPoolFunds).div(oldPoolFunds).sub(FEE_AMOUNT);
        const abyExpectedContribution = ADD_CHANNEL_MIN_FEES.mul(6).mul(newPoolFunds).div(oldPoolFunds).sub(FEE_AMOUNT);

        const aliceChannelNewPoolContrib = await EPNSCoreV1Proxy.channels(ALICE).then(d => d.poolContribution);
        const bobChannelNewPoolContrib = await EPNSCoreV1Proxy.channels(BOB).then(d => d.poolContribution);
        const charlieChannelNewPoolContrib = await EPNSCoreV1Proxy.channels(CHARLIE).then(d => d.poolContribution);
        const abyChannelNewPoolContrib = await EPNSCoreV1Proxy.channels(ABY).then(d => d.poolContribution);

        const aliceChannelNewWeight = await EPNSCoreV1Proxy.channels(ALICE).then(d => d.channelWeight);
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
            TempStoreContract.address, //Temp Contract
            0, // start index
            4, // end index
            oldPoolFunds,
            newPoolFunds,
            [ALICE, BOB, CHARLIE, ABY] // chaneels addresses
        )

        const aliceExpectedContribution = ADD_CHANNEL_MIN_FEES.mul(newPoolFunds).div(oldPoolFunds).sub(FEE_AMOUNT);
        const bobExpectedContribution = ADD_CHANNEL_MIN_FEES.mul(newPoolFunds).div(oldPoolFunds).sub(FEE_AMOUNT);
        const charlieExpectedContribution = ADD_CHANNEL_MIN_FEES.mul(10).mul(newPoolFunds).div(oldPoolFunds).sub(FEE_AMOUNT);
        const abyExpectedContribution = ADD_CHANNEL_MIN_FEES.mul(6).mul(newPoolFunds).div(oldPoolFunds).sub(FEE_AMOUNT);

        const aliceExpectedWeight = aliceExpectedContribution.mul(ADJUST_FOR_FLOAT).div(MIN_POOL_CONTRIBUTION)
        const bobExpectedWeight = bobExpectedContribution.mul(ADJUST_FOR_FLOAT).div(MIN_POOL_CONTRIBUTION)
        const charlieExpectedWeight = charlieExpectedContribution.mul(ADJUST_FOR_FLOAT).div(MIN_POOL_CONTRIBUTION)
        const abyExpectedWeight = abyExpectedContribution.mul(ADJUST_FOR_FLOAT).div(MIN_POOL_CONTRIBUTION)

        const aliceChannelNewWeight = await EPNSCoreV1Proxy.channels(ALICE).then(d => d.channelWeight);
        const bobChannelNewWeight = await EPNSCoreV1Proxy.channels(BOB).then(d => d.channelWeight);
        const charlieChannelWeight = await EPNSCoreV1Proxy.channels(CHARLIE).then(d => d.channelWeight);
        const abyChannelWeight = await EPNSCoreV1Proxy.channels(ABY).then(d => d.channelWeight);

        expect(aliceExpectedWeight).to.be.closeTo(aliceChannelNewWeight, 100)
        expect(bobExpectedWeight).to.be.closeTo(bobChannelNewWeight, 100)
        expect(charlieExpectedWeight).to.be.closeTo(charlieChannelWeight, 100)
        expect(abyExpectedWeight).to.be.closeTo(abyChannelWeight, 100)
    })

    it("Assignes correct channelUpdateBlock value ",async()=>{
        const oldPoolFunds = utils.parseEther("900");

        // pause and swap
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).swapADaiForPush(0);

        const newPoolFunds = await EPNSCoreV1Proxy.POOL_FUNDS();
        // admin updates channel pool contribution
        const tx = await EPNSCoreV1Proxy.adjustChannelPoolContributions(
            TempStoreContract.address, //Temp Contract
            0, // start index
            4, // end index
            oldPoolFunds,
            newPoolFunds,
            [ALICE, BOB, CHARLIE, ABY] // chaneels addresses
        )

        const aliceChannelUpdateBlock = await EPNSCoreV1Proxy.channels(ALICE).then(d => d.channelUpdateBlock);
        const bobChannelUpdateBlock = await EPNSCoreV1Proxy.channels(BOB).then(d => d.channelUpdateBlock);
        const charlieChannelUpdateBlock = await EPNSCoreV1Proxy.channels(CHARLIE).then(d => d.channelUpdateBlock);
        const abyChannelUpdateBlock = await EPNSCoreV1Proxy.channels(ABY).then(d => d.channelUpdateBlock);
        const expectedChannelUpdateBlock = tx.blockNumber;

        expect(expectedChannelUpdateBlock).to.equal(aliceChannelUpdateBlock)
        expect(expectedChannelUpdateBlock).to.equal(bobChannelUpdateBlock)
        expect(expectedChannelUpdateBlock).to.equal(charlieChannelUpdateBlock)
        expect(expectedChannelUpdateBlock).to.equal(abyChannelUpdateBlock)
    })

    it("Shall fail if not paused",async()=>{
        // 4 channels were created .... 50x2
        const oldPoolFunds = utils.parseEther("900");
        const newPoolFunds_before = await EPNSCoreV1Proxy.POOL_FUNDS();
        // without pause txn will fail
        const txn1 = EPNSCoreV1Proxy.adjustChannelPoolContributions(
            TempStoreContract.address, //Temp Contract
            0, // start index
            2, // end index
            oldPoolFunds,
            newPoolFunds_before,
            [ALICE, BOB] // chaneels addresses
        )
        await expect(txn1).to.be.revertedWith("Pausable: not paused")

        // pause and swap
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).swapADaiForPush(0);

        const newPoolFunds_after = await EPNSCoreV1Proxy.POOL_FUNDS();
        // admin updates channel pool contribution
        const tx = await EPNSCoreV1Proxy.adjustChannelPoolContributions(
            TempStoreContract.address, //Temp Contract
            0, // start index
            2, // end index
            oldPoolFunds,
            newPoolFunds_after,
            [ALICE, BOB] // chaneels addresses
        )

        // do updateBlock check
        const expectedChannelUpdateBlock = tx.blockNumber;

        const aliceChannelUpdateBlock = await EPNSCoreV1Proxy.channels(ALICE).then(d => d.channelUpdateBlock);
        const bobChannelUpdateBlock = await EPNSCoreV1Proxy.channels(BOB).then(d => d.channelUpdateBlock);

        expect(expectedChannelUpdateBlock).to.equal(aliceChannelUpdateBlock)
        expect(expectedChannelUpdateBlock).to.equal(bobChannelUpdateBlock)
    })

    it("Should not update non exsting channel",async()=>{
        // 4 channels were created .... 4 .. with contribution 50, 50, 500, 300
        const oldPoolFunds = utils.parseEther("900");

        // pause and swap
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).swapADaiForPush(0);
        const newPoolFunds_after = await EPNSCoreV1Proxy.POOL_FUNDS();

        const FALSE_CHANNEL_ADDRESS = "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
        const falseChannelContribInitial = await EPNSCoreV1Proxy.channels(FALSE_CHANNEL_ADDRESS).then(d => d.poolContribution);
        expect(falseChannelContribInitial).to.equal(0)

        // Add all including ABY
        await EPNSCoreV1Proxy.adjustChannelPoolContributions(
            TempStoreContract.address, //Temp Contract
            0, // start index
            5, // end index
            oldPoolFunds,
            newPoolFunds_after,
            [ALICE, BOB, CHARLIE, ABY, FALSE_CHANNEL_ADDRESS] // chaneels addresses
        )

        const falseChannelContribFinal = await EPNSCoreV1Proxy.channels(FALSE_CHANNEL_ADDRESS).then(d => d.poolContribution);
        expect(falseChannelContribFinal).to.equal(0)
    })

    it("Shall not execute if Caller is not the PUSH Channel Admin",async()=>{
        // 4 channels were created .... 50x2
        const oldPoolFunds = utils.parseEther("900");

        // pause and swap
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).swapADaiForPush(0);
        const newPoolFunds_before = await EPNSCoreV1Proxy.POOL_FUNDS();
        // without pause txn will fail
        const txn1 = EPNSCoreV1Proxy.connect(BOBSIGNER).adjustChannelPoolContributions(
            TempStoreContract.address, //Temp Contract
            0, // start index
            2, // end index
            oldPoolFunds,
            newPoolFunds_before,
            [ALICE, BOB] // chaneels addresses
        )
        await expect(txn1).to.be.revertedWith("EPNSCoreV1::onlyPushChannelAdmin: Caller not pushChannelAdmin")

        // admin updates channel pool contribution
        const tx = await EPNSCoreV1Proxy.connect(ADMINSIGNER).adjustChannelPoolContributions(
            TempStoreContract.address, //Temp Contract
            0, // start index
            2, // end index
            oldPoolFunds,
            newPoolFunds_before,
            [ALICE, BOB] // chaneels addresses
        )

        // do channelUpdateBlock check
        const expectedChannelUpdateBlock = tx.blockNumber;

        const aliceChannelUpdateBlock = await EPNSCoreV1Proxy.channels(ALICE).then(d => d.channelUpdateBlock);
        const bobChannelUpdateBlock = await EPNSCoreV1Proxy.channels(BOB).then(d => d.channelUpdateBlock);

        expect(expectedChannelUpdateBlock).to.equal(aliceChannelUpdateBlock)
        expect(expectedChannelUpdateBlock).to.equal(bobChannelUpdateBlock)
    })

    it("Shall increase pool fees on adjust poolfees",async()=>{
        // 4 channels were created .... 50x2
        const oldPoolFunds = utils.parseEther("900");

        // pause and swap
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).swapADaiForPush(0);
        
        const newPoolFunds = await EPNSCoreV1Proxy.POOL_FUNDS();        
        const pooFees_1 = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
        
        // adjusting one channel shall increase by 10
        await EPNSCoreV1Proxy.adjustChannelPoolContributions(
            TempStoreContract.address, //Temp Contract
            0, // start index
            1, // end index
            oldPoolFunds,
            newPoolFunds,
            [ALICE] // chaneels addresses
        )
        const poolFees_2 = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
        expect(pooFees_1.add(FEE_AMOUNT)).to.equal(poolFees_2)

        
        // adjusting two channel shall increase by 20
        await EPNSCoreV1Proxy.adjustChannelPoolContributions(
            TempStoreContract.address, //Temp Contract
            0, // start index
            2, // end index
            oldPoolFunds,
            newPoolFunds,
            [BOB, CHARLIE] // chaneels addresses
        )
        const poolFees_3 = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
        expect(poolFees_2.add(FEE_AMOUNT).add(FEE_AMOUNT)).to.equal(poolFees_3)

        // adjusting to used address shall make the poolfee unchanged
        await EPNSCoreV1Proxy.adjustChannelPoolContributions(
            TempStoreContract.address, //Temp Contract
            0, // start index
            3, // end index
            oldPoolFunds,
            newPoolFunds,
            [ALICE, BOB, CHARLIE] // chaneels addresses
        )
        const poolFees_final = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();
        expect(poolFees_3).to.equal(poolFees_final)
    })

    it("Shall decrease pool funds on adjust poolfees",async()=>{
        // 4 channels were created .... 50x2
        const oldPoolFunds = utils.parseEther("900");

        // pause and swap
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).swapADaiForPush(0);
        
        const newPoolFunds = await EPNSCoreV1Proxy.POOL_FUNDS();        
        
        // adjusting one channel shall increase by 10
        await EPNSCoreV1Proxy.adjustChannelPoolContributions(
            TempStoreContract.address, //Temp Contract
            0, // start index
            1, // end index
            oldPoolFunds,
            newPoolFunds,
            [ALICE] // chaneels addresses
        )
        const poolFunds2 = await EPNSCoreV1Proxy.POOL_FUNDS();
        expect(newPoolFunds.sub(FEE_AMOUNT)).to.equal(poolFunds2)

        
        // adjusting two channel shall increase by 20
        await EPNSCoreV1Proxy.adjustChannelPoolContributions(
            TempStoreContract.address, //Temp Contract
            0, // start index
            2, // end index
            oldPoolFunds,
            newPoolFunds,
            [BOB, CHARLIE] // chaneels addresses
        )
        const poolFunds3 = await EPNSCoreV1Proxy.POOL_FUNDS();
        expect(poolFunds2.sub(FEE_AMOUNT).sub(FEE_AMOUNT)).to.equal(poolFunds3)

        // adjusting to used address shall make the poolfunds unchanged
        await EPNSCoreV1Proxy.adjustChannelPoolContributions(
            TempStoreContract.address, //Temp Contract
            0, // start index
            3, // end index
            oldPoolFunds,
            newPoolFunds,
            [ALICE, BOB, CHARLIE] // chaneels addresses
        )
        const poolFunds_final = await EPNSCoreV1Proxy.POOL_FUNDS();
        expect(poolFunds3).to.equal(poolFunds_final)
    })

    it("Shall increase fees and decrease funds in samme ammount",async()=>{
        // 4 channels were created .... 50x2
        const oldPoolFunds = utils.parseEther("900");
        const newPoolFunds = await EPNSCoreV1Proxy.POOL_FUNDS();        

        // pause and swap
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).pauseContract();
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).swapADaiForPush(0);
        
        const poolFundsBeforeAdjust = await EPNSCoreV1Proxy.POOL_FUNDS();        
        const poolFeesBeforeAdjust = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();        

        // adjusting to used address shall make the poolfunds unchanged
        await EPNSCoreV1Proxy.adjustChannelPoolContributions(
            TempStoreContract.address, //Temp Contract
            0, // start index
            3, // end index
            oldPoolFunds,
            newPoolFunds,
            [ALICE, BOB, CHARLIE] // chaneels addresses
        )

        const poolFundsAfterAdjust = await EPNSCoreV1Proxy.POOL_FUNDS();        
        const poolFeesAfterAdjust = await EPNSCoreV1Proxy.PROTOCOL_POOL_FEES();        
        
        const fees_delta = poolFeesAfterAdjust.sub(poolFeesBeforeAdjust)
        const funds_delta = poolFundsBeforeAdjust.sub(poolFundsAfterAdjust)
       
        expect(fees_delta).to.equal(funds_delta)
    }) 

    it("Shall avoid other address calling TempStorage",async()=>{
        const txn = TempStoreContract.connect(ALICESIGNER).setChannelAdjusted(BOB);
        await expect(txn).to.be.revertedWith("Can only be called via Core");
    })
})
