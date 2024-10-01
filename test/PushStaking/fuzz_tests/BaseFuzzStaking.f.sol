pragma solidity ^0.8.20;
pragma experimental ABIEncoderV2;

import { BaseTest } from "../../BaseTest.t.sol";

contract BaseFuzzStaking is BaseTest {

    function setUp() public virtual override {
        BaseTest.setUp();
        genesisEpoch = pushStaking.genesisEpoch();
    }

    //Helper Functions
    function stake(address signer, uint256 amount) internal {
        changePrank(signer);
        pushStaking.stake(amount * 1e18);
    }

    function harvest(address signer) internal {
        changePrank(signer);
        pushStaking.harvestAll();
    }

    function harvestPaginated(address signer, uint256 _till) internal {
        changePrank(signer);
        pushStaking.harvestPaginated(_till);
    }

    function addPool(uint256 amount) internal {
        changePrank(actor.admin);
        coreProxy.addPoolFees(amount * 1e18);
    }

    function unstake(address signer) internal {
        changePrank(signer);
        pushStaking.unstake();
    }

    function daoHarvest(address signer, uint256 _epoch) internal {
        changePrank(signer);
        pushStaking.daoHarvestPaginated(_epoch);
    }

    function getCurrentEpoch() public returns (uint256 currentEpoch) {
        currentEpoch = pushStaking.lastEpochRelative(genesisEpoch, block.number);
    }
}
