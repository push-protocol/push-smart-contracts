pragma solidity ^0.8.20;
pragma experimental ABIEncoderV2;

import { BaseTest } from "../../BaseTest.t.sol";

contract BaseFuzzStaking is BaseTest {

    function setUp() public virtual override {
        BaseTest.setUp();
        
        approveTokens(actor.admin, address(pushStaking), 50_000 ether);
        approveTokens(actor.governance, address(pushStaking), 50_000 ether);
        approveTokens(actor.bob_channel_owner, address(pushStaking), 50_000 ether);
        approveTokens(actor.alice_channel_owner, address(pushStaking), 50_000 ether);
        approveTokens(actor.charlie_channel_owner, address(pushStaking), 50_000 ether);
        approveTokens(actor.tony_channel_owner, address(pushStaking), 50_000 ether);
        approveTokens(actor.dan_push_holder, address(pushStaking), 50_000 ether);
        approveTokens(actor.tim_push_holder, address(pushStaking), 50_000 ether);
        
        changePrank(actor.admin);
        pushStaking.initializeStake();
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
