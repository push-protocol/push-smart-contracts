const DAI = "0x75Ab5AB1Eef154C0352Fc31D2428Cef80C7F8B33";
const ADAI = "0x31f30d9A5627eAfeC4433Ae2886Cf6cc3D25E772";
const WETH = "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6";
const AAVE_LENDING_POOL = "0x5E52dEc931FFb32f609681B8438A51c675cc232d";

const EPNS_TOKEN_ADDRS = "0xf418588522d5dd018b425E472991E52EBBeEEEEE";
const UNISWAP_ROUTER = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
const WETH_ADDRS = "0xc778417E063141139Fce010982780140Aa0cD5Ab";
const referralCode = 0;

const CHAIN_NAME = 'GOERLI'; // MAINNET, MATIC etc.

// 12222104 ---> set to just one block before @ 12222103
const PUSH_BORN_BLOCKNUM = 12222103; 

const getNumBlocksToMine = async()=>{
    const currentBlock = await ethers.provider.getBlock("latest");
    const blockToReach = PUSH_BORN_BLOCKNUM - currentBlock.number;
    const numBlockToMine = "0x"+blockToReach.toString(16)

    return numBlockToMine;
}

const epnsContractFixture = async ([adminSigner, others])=>{
    const ADMIN = await adminSigner.getAddress();
    
    ROUTER = await ethers.getContractAt("IUniswapV2Router",UNISWAP_ROUTER);     
    
    // before PUSH token deploy set the actual borndate
    const numBlocksToMine = await getNumBlocksToMine();
	await ethers.provider.send("hardhat_mine", [numBlocksToMine]);

    // deploy push token
    const EPNSTOKEN = await ethers.getContractFactory("EPNS");
    EPNS = await EPNSTOKEN.deploy(ADMIN);
    PushToken = await EPNSTOKEN.attach(EPNS.address);

	// var currentBlock = await ethers.provider.getBlock("latest");
    // console.log("Current Block",currentBlock.number);

    // const bt = await PushToken.born()
    // console.log("Born",bt);
    
    const EPNSCore = await ethers.getContractFactory("EPNSCoreV2");
    CORE_LOGIC = await EPNSCore.deploy();

    const proxyAdmin = await ethers.getContractFactory("EPNSCoreAdmin");
    PROXYADMIN = await proxyAdmin.deploy();

    const EPNSCommunicator = await ethers.getContractFactory("EPNSCommV1_5");
    COMMUNICATOR_LOGIC = await EPNSCommunicator.deploy();

    const EPNSCoreProxyContract = await ethers.getContractFactory("EPNSCoreProxy");
    EPNSCoreProxy = await EPNSCoreProxyContract.deploy(
        CORE_LOGIC.address,
        PROXYADMIN.address,
        ADMIN,
        PushToken.address,
        WETH,
        UNISWAP_ROUTER,
        AAVE_LENDING_POOL,
        DAI,
        ADAI,
        referralCode,
    );

    const EPNSCommProxyContract = await ethers.getContractFactory("EPNSCommProxy");
    EPNSCommProxy = await EPNSCommProxyContract.deploy(
        COMMUNICATOR_LOGIC.address,
        PROXYADMIN.address,
        ADMIN,
        CHAIN_NAME
    );

    EPNSCoreV1Proxy = EPNSCore.attach(EPNSCoreProxy.address)
    EPNSCommV1Proxy = EPNSCommunicator.attach(EPNSCommProxy.address)    
    await EPNSCommV1Proxy.setEPNSCoreAddress(EPNSCoreV1Proxy.address);
    await EPNSCoreV1Proxy.setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
    
    return {
        CORE_LOGIC,
        PROXYADMIN,
        COMMUNICATOR_LOGIC,
        EPNSCoreProxy,
        EPNSCoreV1Proxy, 
        EPNSCommV1Proxy,
        ROUTER,
        PushToken,
        EPNS_TOKEN_ADDRS,
    }
}

const tokenFixture = async([adminSigner,others])=>{
    const MOCKDAITOKEN = await ethers.getContractFactory("MockDAI");
    MOCKDAI = await MOCKDAITOKEN.attach(DAI);

    const ADAIContract = await ethers.getContractAt("IADai",ADAI)

    return{
        MOCKDAI,
        ADAI:ADAIContract
    }
};

module.exports = {
    epnsContractFixture,
    tokenFixture
}