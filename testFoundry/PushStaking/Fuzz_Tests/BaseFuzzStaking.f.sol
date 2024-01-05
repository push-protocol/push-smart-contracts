pragma solidity ^0.8.20;
pragma experimental ABIEncoderV2;

import {BasePushFeePoolStaking} from "../BasePushFeePoolStaking.t.sol";

contract BaseFuzzStaking is BasePushFeePoolStaking {
    uint genesis;

    function setUp() public virtual override {
        BasePushFeePoolStaking.setUp();

        genesis = feePoolStaking.genesisEpoch();

        approveTokens(actor.admin, address(feePoolStaking), 100000 ether);
        approveTokens(actor.admin, address(coreProxy), 100000 ether);
        approveTokens(
            actor.bob_channel_owner,
            address(feePoolStaking),
            100000 ether
        );
        approveTokens(
            actor.alice_channel_owner,
            address(feePoolStaking),
            100000 ether
        );
        approveTokens(
            actor.charlie_channel_owner,
            address(feePoolStaking),
            100000 ether
        );
        approveTokens(
            actor.tony_channel_owner,
            address(feePoolStaking),
            100000 ether
        );

        approveTokens(address(coreProxy), address(feePoolStaking), 1 ether);
        //initialize stake to avoid divsion by zero errors

        stake(address(coreProxy), 1);
    }

    //Helper Functions
    function stake(address signer, uint256 amount) internal {
        changePrank(signer);
        feePoolStaking.stake(amount * 1e18);
    }

    function harvest(address signer) internal {
        changePrank(signer);
        feePoolStaking.harvestAll();
    }

    function harvestPaginated(address signer, uint _till) internal {
        changePrank(signer);
        feePoolStaking.harvestPaginated(_till);
    }

    function addPool(uint256 amount) internal {
        changePrank(actor.admin);
        coreProxy.addPoolFees(amount * 1e18);
    }

    function unstake(address signer) internal {
        changePrank(signer);
        feePoolStaking.unstake();
    }

    function daoHarvest(address signer, uint _epoch) internal {
        changePrank(signer);
        feePoolStaking.daoHarvestPaginated(_epoch);
    }

    function getCurrentEpoch() public returns (uint256 currentEpoch) {
        currentEpoch = feePoolStaking.lastEpochRelative(genesis, block.number);
    }
}
