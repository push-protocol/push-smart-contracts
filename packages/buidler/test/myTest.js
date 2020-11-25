const { ethers } = require("@nomiclabs/buidler");
const { use, expect } = require("chai");
const { solidity } = require("ethereum-waffle");
const {advanceBlockTo, latestBlock, advanceBlock, increase, increaseTo, latest} = require("./time");

use(solidity);

const AAVE_LENDING_POOL = "0x1c8756FD2B28e9426CDBDcC7E3c4d64fa9A54728";
const DAI = "0xf80A32A835F79D7787E8a8ee5721D0fEaFd78108";
const ADAI = "0xcB1Fe6F440c49E9290c3eb7f158534c2dC374201";
const referralCode = 0;
const delay = 0; // uint for the timelock delay

let EPNS;
let GOVERNOR;
let LOGIC;
let LOGICV2;
let EPNSProxy;
let TIMELOCK;
let ADMIN;
let ALICE;
let BOB;
let ADMIN_OVERRIDE = '';

let coder = new ethers.utils.AbiCoder();

describe("EPNS Stack", function () {
  before(async function () {
    const [adminSigner, aliceSigner, bobSigner] = await ethers.getSigners();

    ADMIN = await adminSigner.getAddress();
    ALICE = await aliceSigner.getAddress();
    BOB = await bobSigner.getAddress();
  });
  describe("EPNS", function () {
    it("Should deploy EPNS Token", async function () {
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

  describe("EPNSCore Logic", function () {
    it("Should deploy the EPNS Core Logic", async function () {
      const EPNSCore = await ethers.getContractFactory("EPNSCore");

      LOGIC = await EPNSCore.deploy();
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

      let data = coder.encode(['address'], [GOVERNOR.address]);

      await TIMELOCK.functions.queueTransaction(TIMELOCK.address, '0', 'setPendingAdmin(address)', data, (eta + 1));

      // await increaseTo(eta + 200);
      await advanceBlock();
      await advanceBlock();

      await TIMELOCK.functions.executeTransaction(TIMELOCK.address, '0', 'setPendingAdmin(address)', data, (eta + 1));

      await GOVERNOR.functions.__acceptAdmin();
      // eslint-disable-next-line no-underscore-dangle
      await GOVERNOR.functions.__abdicate();
    });
  });

  describe("EPNSProxy", function () {
    it("Should deploy EPNS Core Proxy", async function () {
      const EPNSPROXYContract = await ethers.getContractFactory("EPNSProxy");

      EPNSProxy = await EPNSPROXYContract.deploy(
        LOGIC.address,
        TIMELOCK.address,
        AAVE_LENDING_POOL,
        DAI,
        ADAI,
        referralCode
      );
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
      const targets = [EPNSProxy.address];
      const values = ["0x0"];
      const signatures = ["upgradeTo(address)"];
      let data = coder.encode(['address'],[LOGICV2.address])
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
      // await increase(259300);
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
});
