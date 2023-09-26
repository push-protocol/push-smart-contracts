const { tokensBN } = require("../../helpers/utils");
const { ethers } = require("hardhat");

const DAI = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
const ADAI = "0xfC1E690f61EFd961294b3e1Ce3313fBD8aa4f85d";
const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const AAVE_LENDING_POOL = "0x24a42fD28C976A61Df5D00D0599C34c4f90748c8";

const EPNS_TOKEN_ADDRS = "0xf418588522d5dd018b425E472991E52EBBeEEEEE";
const UNISWAP_ROUTER = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
const WETH_ADDRS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const referralCode = 0;

const CHAIN_NAME = "Mainnet"; // MAINNET, MATIC etc.

const PUSH_WHALE_ADDRESS = "0xCB8EFB0c065071E4110932858A84365A80C8feF0";
const AMT_TO_TRASFER = tokensBN(2_000_000);

const epnsContractFixture = async ([adminSigner, others]) => {
  const ADMIN = await adminSigner.getAddress();
  ROUTER = await ethers.getContractAt("IUniswapV2Router", UNISWAP_ROUTER);

  // deploy dummy push token
  let PushToken = await ethers.getContractFactory("EPNS");
  PushToken = await PushToken.deploy(ADMIN);

  const EPNSCore = await ethers.getContractFactory("PushCoreV2");
  CORE_LOGIC = await EPNSCore.deploy();

  const proxyAdmin = await ethers.getContractFactory("EPNSCoreAdmin");
  PROXYADMIN = await proxyAdmin.deploy();

  const EPNSCommunicator = await ethers.getContractFactory("PushCommV2");
  COMMUNICATOR_LOGIC = await EPNSCommunicator.deploy();

  const PushFeePool = await ethers.getContractFactory("PushFeePool");
  PUSH_STAKING_LOGIC = await PushFeePool.deploy();

  const EPNSCoreProxyContract = await ethers.getContractFactory(
    "EPNSCoreProxy"
  );
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

  const PushFeePoolProxyContract = await ethers.getContractFactory(
    "PushFeePoolProxy"
  );

  const PushFeePoolProxy = await PushFeePoolProxyContract.deploy(
    PUSH_STAKING_LOGIC.address,
    PROXYADMIN.address,
    ADMIN,
    EPNSCoreProxy.address,
    PushToken.address,
    0,
    450877,
    4,
    BigInt("3300000000000000000000"),
    BigInt("60000000000000000000000")
  );

  EPNSCoreV1Proxy = EPNSCore.attach(EPNSCoreProxy.address);
  EPNSCommV1Proxy = EPNSCommunicator.attach(EPNSCommProxy.address);
  PushFeePoolV1Proxy = PushFeePool.attach(PushFeePoolProxy.address);
  await EPNSCommV1Proxy.setEPNSCoreAddress(EPNSCoreV1Proxy.address);
  await EPNSCoreV1Proxy.setEpnsCommunicatorAddress(EPNSCommV1Proxy.address);
  await EPNSCoreV1Proxy.updateStakingAddress(PushFeePoolProxy.address);

  
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
    PushFeePoolV1Proxy,
  };
};



module.exports = {
  epnsContractFixture,
};