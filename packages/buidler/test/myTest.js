const { ethers } = require("hardhat");
const { use, expect } = require("chai");
const { solidity } = require("ethereum-waffle");
const {
  advanceBlockTo,
  latestBlock,
  advanceBlock,
  increase,
  increaseTo,
  latest,
} = require("./time");

use(solidity);
const ADJUST_FOR_FLOAT = 10e7;

const calcChannelFairShare = (
  currentBlock,
  channelStartBlock,
  channelWeight,
  groupHistoricalZ,
  groupFairShareCount,
  groupLastUpdate,
  groupNormalizedWeight
) => {
  // formula is ratio = da / z + (nxw)
  // d is the difference of blocks from given block and the last update block of the entire group
  // a is the actual weight of that specific group
  // z is the historical constant
  // n is the number of channels
  // x is the difference of blocks from given block and the last changed start block of group
  // w is the normalized weight of the groups

  const d = currentBlock - channelStartBlock;
  const a = channelWeight;
  const z = groupHistoricalZ;
  const n = groupFairShareCount;
  const x = currentBlock - groupLastUpdate;
  const w = groupNormalizedWeight;

  const NXW = n * x * w;
  const ZNXW = z + NXW;
  const da = d * a;

  // eslint-disable-next-line camelcase
  return (da * ADJUST_FOR_FLOAT) / ZNXW;
};

const calcSubscriberFairShare = (
  currentBlock,
  memberLastUpdate,
  channelHistoricalZ,
  channelLastUpdate,
  channelFairShareCount
) => {
  // formula is ratio = d / z + (nx)
  // d is the difference of blocks from given block and the start block of subscriber
  // z is the historical constant
  // n is the number of subscribers of channel
  // x is the difference of blocks from given block and the last changed start block of channel

  const d = currentBlock - memberLastUpdate;
  const z = channelHistoricalZ;
  const x = currentBlock - channelLastUpdate;

  const nx = channelFairShareCount * x;

  return (d * ADJUST_FOR_FLOAT) / (z + nx); // == d / z + n * x
};

const AAVE_LENDING_POOL = "0x1c8756FD2B28e9426CDBDcC7E3c4d64fa9A54728";
const DAI = "0xf80A32A835F79D7787E8a8ee5721D0fEaFd78108";
const ADAI = "0xcB1Fe6F440c49E9290c3eb7f158534c2dC374201";
const referralCode = 0;
const delay = 0; // uint for the timelock delay

const forkAddress = {
  address: "0xe2a6cf5f463df94147a0f0a302c879eb349cb2cd",
};

let EPNS;
let GOVERNOR;
let PROXYADMIN;
let LOGIC;
let LOGICV2;
let EPNSProxy;
let TIMELOCK;
let ADMIN;
let ALICE;
let BOB;
let CHARLIE;
let CHANNEL_CREATOR;
let ADMINSIGNER;
let ALICESIGNER;
let BOBSIGNER;
let CHARLIESIGNER;
let CHANNEL_CREATORSIGNER;
const ADMIN_OVERRIDE = "";

const coder = new ethers.utils.AbiCoder();

describe("EPNS Stack", function () {
  before(async function () {
    const [
      adminSigner,
      aliceSigner,
      bobSigner,
      charlieSigner,
      channelCreatorSigner,
    ] = await ethers.getSigners();

    ADMINSIGNER = adminSigner;
    ALICESIGNER = aliceSigner;
    BOBSIGNER = bobSigner;
    CHARLIESIGNER = charlieSigner;
    CHANNEL_CREATORSIGNER = channelCreatorSigner;

    ADMIN = await adminSigner.getAddress();
    ALICE = await aliceSigner.getAddress();
    BOB = await bobSigner.getAddress();
    CHARLIE = await charlieSigner.getAddress();
    CHANNEL_CREATOR = await channelCreatorSigner.getAddress();
  });

  describe("EPNS", function () {
    it("Should deploy PUSH Token", async function () {
      const EPNSTOKEN = await ethers.getContractFactory("EPNS");
      EPNS = await EPNSTOKEN.deploy();
      expect(EPNS.address).to.not.equal(null);
    });

    describe("get Balance of account 0", function () {
      it("Total Supply should be sent to the msg sender", async function () {
        const balance = await EPNS.balanceOf(ADMIN);
        expect(await EPNS.totalSupply()).to.equal(balance);
      });
    });
  });

  describe("EPNSCoreV1 Logic", function () {
    it("Should deploy the EPNS Core Logic", async function () {
      const EPNSCoreV1 = await ethers.getContractFactory("EPNSCoreV1");

      LOGIC = await EPNSCoreV1.deploy();
    });
  });

  describe("EPNSCoreV2 Logic", function () {
    it("Should deploy the EPNS CoreV2 Logic", async function () {
      const EPNSCoreV2 = await ethers.getContractFactory("EPNSCoreV2");

      LOGICV2 = await EPNSCoreV2.deploy();
    });
  });

  describe("Timelock", function () {
    it("Should deploy A Timelock", async function () {
      const TimeLock = await ethers.getContractFactory("Timelock");

      TIMELOCK = await TimeLock.deploy(ADMIN, delay);
    });
  });

  describe("GovernorAlpha", function () {
    it("Should deploy GovernorAlpha Platform", async function () {
      const GovernorAlpha = await ethers.getContractFactory("GovernorAlpha");

      GOVERNOR = await GovernorAlpha.deploy(
        TIMELOCK.address,
        EPNS.address,
        ADMIN
      );

      const eta = (await latest()).toNumber();

      const data = coder.encode(["address"], [GOVERNOR.address]);

      await TIMELOCK.functions.queueTransaction(
        TIMELOCK.address,
        "0",
        "setPendingAdmin(address)",
        data,
        eta + 1
      );

      // await increaseTo(eta + 200);
      await advanceBlock();
      await advanceBlock();

      await TIMELOCK.functions.executeTransaction(
        TIMELOCK.address,
        "0",
        "setPendingAdmin(address)",
        data,
        eta + 1
      );

      await GOVERNOR.functions.__acceptAdmin();
      // eslint-disable-next-line no-underscore-dangle
      await GOVERNOR.functions.__abdicate();
    });
  });

  describe("ProxyAdmin", function () {
    it("Should deploy a ProxyAdmin Contract", async function () {
      const proxyAdmin = await ethers.getContractFactory("EPNSAdmin");
      PROXYADMIN = await proxyAdmin.deploy();
      await PROXYADMIN.transferOwnership(TIMELOCK.address);
    });
  });

  describe("EPNSProxy", function () {
    it("Should deploy EPNS Core Proxy", async function () {
      const EPNSPROXYContract = await ethers.getContractFactory("EPNSProxy");
      EPNSProxy = await EPNSPROXYContract.deploy(
        LOGIC.address,
        ADMIN,
        AAVE_LENDING_POOL,
        DAI,
        ADAI,
        referralCode
      );
    });

    it("Should Change the admin to the ProxyAdmin", async function () {
      await EPNSProxy.changeAdmin(PROXYADMIN.address);
    });
  });

  describe("EPNSProxy - Upgrade Logic to V2 Contract", function () {
    let proposalTx;
    let proposalId;
    it("Admin will delegate all votes to admin", async function () {
      // need to delegate tokens to make proposalsconst [adminSigner, aliceSigner, bobSigner] = await ethers.getSigners();
      //
      //   const admin = await adminSigner.getAddress();
      await EPNS.functions.delegate(ADMIN);
    });

    it("Admin will create a new proposal and vote for it", async function () {
      // proposal steps

      const targets = [PROXYADMIN.address];
      const values = ["0x0"];
      const fragment = LOGICV2.interface.getFunction("initialize");
      const upgradeData = LOGICV2.interface.encodeFunctionData(fragment, []);
      console.log(upgradeData);
      const signatures = ["upgradeAndCall(address,address,bytes)"];
      const data = coder.encode(
        ["address", "address", "bytes"],
        [EPNSProxy.address, LOGICV2.address, upgradeData]
      );
      const calldatas = [data];
      const description = "ipfs://wip"; // ipfs hash

      proposalTx = await GOVERNOR.functions.propose(
        targets,
        values,
        signatures,
        calldatas,
        description
      );
      const receipt = await proposalTx.wait();

      proposalId = receipt.events[0].args[0].toString();

      await advanceBlock();
      await GOVERNOR.functions.castVote(proposalId, true); // vote in support of the proposal

      // move time into the future whatever the timeout of the prposal is set to
    });

    it("Admin will queue the finalized proposal", async function () {
      await increase(259300);
      const currBlock = await latestBlock();
      console.log(currBlock.toNumber());
      const votingPeriod = await GOVERNOR.functions.votingPeriod();
      console.log(votingPeriod);
      const advance = currBlock.toNumber() + votingPeriod[0].toNumber() + 1;
      console.log(advance);
      await advanceBlockTo(advance);
      await GOVERNOR.functions.queue(proposalId);

      // pass time until timelock
    }).timeout(100000);

    it("Admin execute the proposal.", async function () {
      await increase(172900);
      await GOVERNOR.functions.execute(proposalId);
    });
  });

  describe("EPNS - Share Fair Ratio", function () {
    it("Should mint 10000 DAI as account 0 and transfer 100 to ALICE and BOB", async function () {
      const mockDAI = await ethers.getContractAt(
        "MockDAI",
        DAI,
        CHANNEL_CREATORSIGNER
      );
      await mockDAI.mint(ethers.utils.parseEther("10000.00"));
      await mockDAI.approve(EPNSProxy.address, ethers.utils.parseEther("500"));
      const userBalance = ethers.utils.parseEther("1000");

      await mockDAI.transfer(CHANNEL_CREATOR, userBalance);
      await mockDAI.transfer(ALICE, userBalance);
      await mockDAI.transfer(BOB, userBalance);
      await mockDAI.transfer(CHARLIE, userBalance);
    });

    it("Should approve the epns protocol for 1k DAI each ", async function () {
      const mockDAIAlice = await ethers.getContractAt(
        "MockDAI",
        DAI,
        ALICESIGNER
      );
      const mockDAIBob = await ethers.getContractAt("MockDAI", DAI, BOBSIGNER);
      const mockDAICharlie = await ethers.getContractAt(
        "MockDAI",
        DAI,
        CHARLIESIGNER
      );

      await mockDAIAlice.approve(EPNSProxy.address, 1000);
      await mockDAIBob.approve(EPNSProxy.address, 1000);
      await mockDAICharlie.approve(EPNSProxy.address, 1000);
    });

    it("Whitelist channel creator address ", async function () {
      const lEPNS = await ethers.getContractAt(
        "EPNSCoreV1",
        EPNSProxy.address,
        ADMINSIGNER
      );

      await lEPNS.addToChannelizationWhitelist(CHANNEL_CREATOR);
    });

    it("should create a channel and subscribe users to it", async function () {
      const CHANNEL_TYPE = 2;
      const createChannelEPNS = await ethers.getContractAt(
        "EPNSCoreV1",
        EPNSProxy.address,
        CHANNEL_CREATORSIGNER
      );

      const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");
      console.log(`Test Channel Bytes is : ${testChannel}`);

      await createChannelEPNS.createChannelWithFees(CHANNEL_TYPE, testChannel);

      // randomize the entrance sets

      const randomEntrance = [
        [ALICE, ALICESIGNER, Math.floor(Math.random() * 100)],
        [BOB, BOBSIGNER, Math.floor(Math.random() * 100)],
        [CHARLIE, CHARLIESIGNER, Math.floor(Math.random() * 100)],
      ];
      let currentBlock = (await latestBlock()).toNumber();

      // eslint-disable-next-line no-plusplus
      for (let x = 0; x < randomEntrance.length; x++) {
        const [signerAddress, signer, blockDiff] = randomEntrance[x];
        console.log(`Block Differential for ${signerAddress}: ${blockDiff}`);
        const epns = await ethers.getContractAt(
          "EPNSCoreV1",
          EPNSProxy.address,
          signer
        );

        // eslint-disable-next-line no-multi-assign
        const advanceTo = (currentBlock += blockDiff);
        await epns.subscribe(CHANNEL_CREATOR);

        await advanceBlockTo(advanceTo.toString());

        // eslint-disable-next-line no-restricted-syntax,no-plusplus
        for (let i = 0; i <= x; i++) {
          const [signerAddress, signer, blockDiff] = randomEntrance[i];

          // eslint-disable-next-line no-await-in-loop
          const subscriberFairShare = await epns.getSubscriberFSRatio(
            CHANNEL_CREATOR,
            signerAddress,
            advanceTo
          );

          console.log(
            `subscriberFairShare: ${signerAddress} has a ratio of ${
              subscriberFairShare / 10e7
            }` // adjusted for float
          );
        }
      }
    });
  });
});
