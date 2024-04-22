// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { BaseTest } from "../../../../BaseTest.t.sol";
import "contracts/token/Push.sol";

contract HolderWeightUpdation_Test is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();

        vm.prank(actor.governance);
        pushNttToken.mint(actor.admin, 1e5 ether);
    }

    function test_BornAndWeight_ShouldBeEqual() public {
        uint256 bornBlockNumber = pushNttToken.born();
        uint256 ownerHolderWeight = pushNttToken.holderWeight(actor.admin);
        assertEq(bornBlockNumber, ownerHolderWeight);
    }

    function test_BornAndDeploymentBlock_ShouldBeEqual() public {
        Push nttTempToken = new Push(actor.dan_push_holder);
        uint256 bornBlockNumber = nttTempToken.born();
        assertEq(bornBlockNumber, block.number);
    }

    function test_HolderWeight_OnFirstTransfer() public {
        // should reflect accurate block number on transfer
        vm.prank(actor.admin);
        pushNttToken.transfer(actor.dan_push_holder, 50 ether);
        uint256 danHolderWeight = pushNttToken.holderWeight(actor.dan_push_holder);
        assertEq(danHolderWeight, block.number);
    }

    function test_HolderWeight_OnTransferBack() public {
        // should reflect same block number on transfer back
        vm.prank(actor.admin);
        pushNttToken.transfer(actor.dan_push_holder, 50 ether);

        vm.prank(actor.dan_push_holder);
        pushNttToken.transfer(actor.admin, 50 ether);
        uint256 adminHolderWeight = pushNttToken.holderWeight(actor.admin);
        assertEq(adminHolderWeight, block.number);
    }

    function test_HolderWeight_OnMultipleTransfers() public {
        // should reflect same block number on multiple transfers
        vm.prank(actor.admin);
        pushNttToken.transfer(actor.dan_push_holder, 50 ether);

        vm.prank(actor.dan_push_holder);
        pushNttToken.transfer(actor.tim_push_holder, 50 ether);

        uint256 blockNumber = block.number;

        vm.roll(100); // transferring from tim to dan again in block 100 (holder weight should remain 1)
        vm.prank(actor.tim_push_holder);
        pushNttToken.transfer(actor.dan_push_holder, 50 ether);

        uint256 timHolderWeight = pushNttToken.holderWeight(actor.tim_push_holder);
        uint256 danHolderWeight = pushNttToken.holderWeight(actor.dan_push_holder);
        assertEq(timHolderWeight, blockNumber);
        assertEq(danHolderWeight, blockNumber);
    }

    function test_GetHolderDelegation_ForUnauthorizedDelegator() public {
        bool danHolderDelegation = pushNttToken.returnHolderDelegation(actor.dan_push_holder, actor.tim_push_holder);
        assertEq(danHolderDelegation, false);
    }

    function test_GetHolderDelegation_ForAuthorizedDelegator() public {
        vm.prank(actor.dan_push_holder);
        pushNttToken.setHolderDelegation(actor.tim_push_holder, true);

        bool danHolderDelegation = pushNttToken.returnHolderDelegation(actor.dan_push_holder, actor.tim_push_holder);
        assertEq(danHolderDelegation, true);
    }
}
