// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { BaseTest } from "../../../../BaseTest.t.sol";
import "contracts/mocks/MockTempProtocol.sol";

contract ResetHolderWeight_Test is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();

        vm.prank(actor.governance);
        pushNttToken.mint(actor.admin, 1e5 ether);
    }

    function test_Revertwhen_UnauthorisedDelegator() public {
        vm.prank(actor.dan_push_holder);
        vm.expectRevert(bytes("Push::resetHolderWeight: unauthorized"));
        pushNttToken.resetHolderWeight(actor.tim_push_holder);
    }

    function test_Reset_AuthorisedDelegator() public {
        vm.prank(actor.dan_push_holder);
        pushNttToken.setHolderDelegation(actor.tim_push_holder, true);

        vm.prank(actor.tim_push_holder);
        pushNttToken.resetHolderWeight(actor.dan_push_holder);
        uint256 danHolderWeight = pushNttToken.holderWeight(actor.dan_push_holder);
        assertEq(danHolderWeight, block.number);
    }

    function test_Reset_MsgSender() public {
        vm.prank(actor.dan_push_holder);
        pushNttToken.resetHolderWeight(actor.dan_push_holder);
        uint256 danHolderWeight = pushNttToken.holderWeight(actor.dan_push_holder);
        assertEq(danHolderWeight, block.number);
    }

    function test_HolderWeightOnTransfer_AfterReset() public {
        vm.prank(actor.admin);
        pushNttToken.transfer(actor.dan_push_holder, 10 ether);

        vm.startPrank(actor.dan_push_holder);
        pushNttToken.resetHolderWeight(actor.dan_push_holder);
        pushNttToken.transfer(actor.admin, 5 ether);
        vm.stopPrank();

        uint256 ownerHolderWeight = pushNttToken.holderWeight(actor.admin);
        uint256 danHolderWeight = pushNttToken.holderWeight(actor.dan_push_holder);
        assertEq(ownerHolderWeight, danHolderWeight);
    }

    function test_Revertwhen_UnauthorizedCall_ExternalContract() public {
        vm.prank(actor.admin);
        pushNttToken.transfer(actor.dan_push_holder, 10 ether);

        MockTempProtocol tempProtocol = new MockTempProtocol();

        vm.prank(actor.dan_push_holder);
        vm.expectRevert(bytes("Push::resetHolderWeight: unauthorized"));

        tempProtocol.claimReward(address(pushNttToken));
    }

    function test_AuthorizedCall_ExternalContract() public {
        vm.prank(actor.admin);
        pushNttToken.transfer(actor.dan_push_holder, 10 ether);

        MockTempProtocol tempProtocol = new MockTempProtocol();

        vm.startPrank(actor.dan_push_holder);
        pushNttToken.setHolderDelegation(address(tempProtocol), true);
        tempProtocol.claimReward(address(pushNttToken));
        vm.stopPrank();

        uint256 danHolderWeight = pushNttToken.holderWeight(actor.dan_push_holder);
        assertEq(danHolderWeight, block.number);
    }
}
