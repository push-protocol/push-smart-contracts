pragma solidity ^0.8.20;
pragma experimental ABIEncoderV2;

import { BaseTest } from "../../BaseTest.t.sol";

contract BaseFuzzStaking is BaseTest {

    function setUp() public virtual override {
        BaseTest.setUp();
        genesisEpoch = coreProxy.genesisEpoch();
    }

    //Helper Functions
    function stake(address signer, uint256 amount) internal {
        changePrank(signer);
        coreProxy.stake(amount * 1e18);
    }

    function harvest(address signer) internal {
        changePrank(signer);
        coreProxy.harvestAll();
    }

    function harvestPaginated(address signer, uint256 _till) internal {
        changePrank(signer);
        coreProxy.harvestPaginated(_till);
    }

    function addPool(uint256 amount) internal {
        changePrank(actor.admin);
        coreProxy.addPoolFees(amount * 1e18);
    }

    function unstake(address signer) internal {
        changePrank(signer);
        coreProxy.unstake();
    }

    function daoHarvest(address signer, uint256 _epoch) internal {
        changePrank(signer);
        coreProxy.daoHarvestPaginated(_epoch);
    }

    function getCurrentEpoch() public returns (uint256 currentEpoch) {
        currentEpoch = coreProxy.lastEpochRelative(genesisEpoch, block.number);
    }
}
