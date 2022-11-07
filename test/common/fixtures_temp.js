const DAI = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
const ADAI = "0xfC1E690f61EFd961294b3e1Ce3313fBD8aa4f85d";
const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const AAVE_LENDING_POOL = "0x24a42fD28C976A61Df5D00D0599C34c4f90748c8";

const EPNS_TOKEN_ADDRS = "0xf418588522d5dd018b425E472991E52EBBeEEEEE";
const UNISWAP_ROUTER = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
const WETH_ADDRS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const referralCode = 0;

const CHAIN_NAME = "Mainnet"; // MAINNET, MATIC etc.

const epnsContractFixture = async ([adminSigner, others]) => {
  const ADMIN = await adminSigner.getAddress();

  ROUTER = await ethers.getContractAt("IUniswapV2RouterMock", UNISWAP_ROUTER);

  const EPNSTOKEN = await ethers.getContractFactory("EPNS");
  EPNS = await EPNSTOKEN.attach(EPNS_TOKEN_ADDRS);

  const EPNSCore = await ethers.getContractFactory("EPNSCoreV1_Temp");
  CORE_LOGIC = await EPNSCore.deploy();

  const proxyAdmin = await ethers.getContractFactory("EPNSCoreAdmin");
  PROXYADMIN = await proxyAdmin.deploy();

  const EPNSCommunicator = await ethers.getContractFactory("EPNSCommV1");
  COMMUNICATOR_LOGIC = await EPNSCommunicator.deploy();

  const EPNSCoreProxyContract = await ethers.getContractFactory(
    "EPNSCoreProxy"
  );
  EPNSCoreProxy = await EPNSCoreProxyContract.deploy(
    CORE_LOGIC.address,
    PROXYADMIN.address,
    ADMIN,
    EPNS.address,
    WETH,
    UNISWAP_ROUTER,
    AAVE_LENDING_POOL,
    DAI,
    ADAI,
    referralCode
  );

  const EPNSCommProxyContract = await ethers.getContractFactory(
    "EPNSCommProxy"
  );
  EPNSCommProxy = await EPNSCommProxyContract.deploy(
    COMMUNICATOR_LOGIC.address,
    PROXYADMIN.address,
    ADMIN,
    CHAIN_NAME
  );

  EPNSCoreV1Proxy = EPNSCore.attach(EPNSCoreProxy.address);
  EPNSCommV1Proxy = EPNSCommunicator.attach(EPNSCommProxy.address);
  await EPNSCommV1Proxy.setEPNSCoreAddress(EPNSCoreV1Proxy.address);
  await EPNSCoreV1Proxy.setEpnsCommunicatorAddress(EPNSCommV1Proxy.address);

  return {
    CORE_LOGIC,
    PROXYADMIN,
    COMMUNICATOR_LOGIC,
    EPNSCoreProxy,
    EPNSCoreV1Proxy,
    EPNSCommV1Proxy,
    ROUTER,
    EPNS,
    EPNS_TOKEN_ADDRS,
    WETH_ADDRS,
  };
};

const tokenFixture = async ([adminSigner, others]) => {
  const MOCKDAITOKEN = await ethers.getContractFactory("MockDAI");
  MOCKDAI = await MOCKDAITOKEN.attach(DAI);

  const ADAIContract = await ethers.getContractAt("IADai", ADAI);
  const DAI_WHALE_SIGNER = await ethers.getImpersonatedSigner(
    "0x7c8CA1a587b2c4c40fC650dB8196eE66DC9c46F4"
  );

  return {
    MOCKDAI,
    ADAI: ADAIContract,
    DAI_WHALE_SIGNER,
  };
};

module.exports = {
  epnsContractFixture,
  tokenFixture,
};
