// Import helper functions
const { bn, tokensBN } = require('../../helpers/utils');

// We import Chai to use its asserting functions here.
const { expect } = require("chai");


describe("Benchmaking Contracts", async function () {
  // Get addresses
  let owner
  let alice
  let bob
  let charles
  const AAVE_LENDING_POOL = "0x1c8756FD2B28e9426CDBDcC7E3c4d64fa9A54728";
  const DAI = "0xf80A32A835F79D7787E8a8ee5721D0fEaFd78108";
  const ADAI = "0xcB1Fe6F440c49E9290c3eb7f158534c2dC374201";
  const referralCode = 0;
  const delay = 0; // uint for the timelock delay
  const ADD_CHANNEL_MIN_POOL_CONTRIBUTION = tokensBN(50)
  const ADD_CHANNEL_MAX_POOL_CONTRIBUTION = tokensBN(250000 * 50)
  const CHANNEL_TYPE = 2;
  const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

  // To load benchmarks
  let EPNSBenchmarks

  // Initialize
  before(async function () {
    [owner, alice, bob, charles, eventualAdmin] = await ethers.getSigners()
    
    const TimeLock = await ethers.getContractFactory("Timelock");
    const TIMELOCK = await TimeLock.deploy(owner.address, delay);

    const proxyAdmin = await ethers.getContractFactory("EPNSAdmin");
    const PROXYADMIN = await proxyAdmin.deploy();
    await PROXYADMIN.transferOwnership(TIMELOCK.address);

    // Define all benchmarks
    EPNSBenchmarks = [
      {
        name: "EPNSStagingV4",
        changes: "EPNSStagingV4 Testing",
        args: [owner.address, AAVE_LENDING_POOL, DAI, ADAI, referralCode],
        functions: [
          {
            call: `createChannelWithFees(${CHANNEL_TYPE},${testChannel}'${ADD_CHANNEL_MIN_POOL_CONTRIBUTION}')`,
            from: owner.address
          },
          {
            call: `createPromoterChannel()`,
            from: owner.address
          },
          {
            call: `createChannelWithFees(${CHANNEL_TYPE},${testChannel}'${ADD_CHANNEL_MIN_POOL_CONTRIBUTION}')`,
            from: owner.address
          },
          {
            call: `createChannelWithFees(${CHANNEL_TYPE},${testChannel}'${ADD_CHANNEL_MIN_POOL_CONTRIBUTION}')`,
            from: owner.address
          },
        ]
      },
      {
        name: "EPNSStagingV1",
        changes: "EPNS_StagingV1 Testing",
        args: [owner.address, AAVE_LENDING_POOL, DAI, ADAI, referralCode],
        functions: [
          {
            call: `addToChannelizationWhitelist('${charles.address}')`,
            from: owner.address
          },
          {
            call: `addToChannelizationWhitelist('${charles.address}')`,
            from: owner.address
          },
          {
            call: `addToChannelizationWhitelist('${charles.address}')`,
            from: owner.address
          },
          {
            call: `addToChannelizationWhitelist('${charles.address}')`,
            from: owner.address
          },
        ]
      },
      {
        name: "EPNSStagingV1",
        changes: "EPNSCoreV3 Testing",
        args: [owner.address, AAVE_LENDING_POOL, DAI, ADAI, referralCode],
        functions: [
          {
            call: `addToChannelizationWhitelist('${charles.address}')`,
            from: owner.address
          },
          {
            call: `addToChannelizationWhitelist('${charles.address}')`,
            from: owner.address
          },
          {
            call: `addToChannelizationWhitelist('${charles.address}')`,
            from: owner.address
          },
          {
            call: `addToChannelizationWhitelist('${charles.address}')`,
            from: owner.address
          },
        ]
      },
    ]
  })

  // Prepare benchmarks
  describe("Running Benchmark on EPNS.sol", async function () {
    let deployments = []

    beforeEach(async function () {
      for (const item of EPNSBenchmarks) {
        const Contract = await ethers.getContractFactory(`${item.name}`)
        const deployedContract = await Contract.deploy()

        const EPNSPROXYContract = await ethers.getContractFactory("EPNSProxy");
        
        EPNSProxy = await EPNSPROXYContract.deploy(
          deployedContract.address,
          ...item.args
        );
        await EPNSProxy.changeAdmin(eventualAdmin.address);

        const deployedContractProxy = deployedContract.attach(EPNSProxy.address)
        const deployedProxy = {
          name: item.name,
          contract: deployedContractProxy,
          calls: item.functions
        } 
        deployments.push(deployedProxy)
      }

    })

    afterEach(async function () {
      //deployments = []
    })

    it(`Benchmarking...`, async function () {
      for (const item of deployments) {
        const contract = item.contract
        for (const func of item.calls) {
          const AsyncFunction = Object.getPrototypeOf(async function(){}).constructor;

          let execute = new AsyncFunction('contract', 'func', + `await contract.${func.call}`)
          const tx = await execute(contract, func)
        }
      }
    })

  })

})