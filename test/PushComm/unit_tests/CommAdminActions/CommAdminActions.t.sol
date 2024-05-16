pragma solidity ^0.8.0;

import { BasePushCommTest } from "../BasePushCommTest.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";

contract CommAdminActions_Test is BasePushCommTest {
    function setUp() public override {
        BasePushCommTest.setUp();
    }

    function test_REVERTWhen_Non_adminTriesToChange_CoreAddress() external {
        // it should REVERT
        changePrank(actor.bob_channel_owner);
        vm.expectRevert(Errors.CallerNotAdmin.selector);
        commProxy.setPushCoreAddress(address(123));
        assertEq(commProxy.PushCoreAddress(), address(coreProxy));
    }

    function test_WhenAdminTriesToChange_CoreAddress() external {
        // it should update the core address
        changePrank(actor.admin);
        commProxy.setPushCoreAddress(address(123));
        assertEq(commProxy.PushCoreAddress(), address(123));
    }

    function test_REVERTWhen_Non_adminTriesTo_ChangeGovernanceAddress() external {
        // it should REVERT
        changePrank(actor.bob_channel_owner);
        vm.expectRevert(Errors.CallerNotAdmin.selector);
        commProxy.setGovernanceAddress(actor.governance);
        assertEq(commProxy.governance(), actor.admin);
    }

    function test_WhenAdminChanges_GovernanceAddress() external {
        // it should update the governance address
        changePrank(actor.admin);
        commProxy.setGovernanceAddress(actor.governance);
        assertEq(commProxy.governance(), actor.governance);
    }

    function test_RevertWhen_NonAdminTransfers_PushChannelAdminControl() external {
        // it should REVERT
        changePrank(actor.bob_channel_owner);
        vm.expectRevert(Errors.CallerNotAdmin.selector);
        commProxy.transferPushChannelAdminControl(actor.bob_channel_owner);
        assertEq(commProxy.pushChannelAdmin(), actor.admin);
    }

    function test_RevertWhen_AdminTransfers_AdminControl_ToZeroAddress() external {
        // it should REVERT
        changePrank(actor.admin);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArgument_WrongAddress.selector, address(0)));
        commProxy.transferPushChannelAdminControl(address(0));
        assertEq(commProxy.pushChannelAdmin(), actor.admin);
    }

    function test_RevertWhen_AdminTransfers_AdminControl_ToItself() external {
        // it should REVERT
        changePrank(actor.admin);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArgument_WrongAddress.selector, actor.admin));
        commProxy.transferPushChannelAdminControl(actor.admin);
    }

    function test_WhenAdminTransfers_AdminControl_ToCorrectAddress() external {
        // it should update the admin control
        changePrank(actor.admin);

        commProxy.transferPushChannelAdminControl(actor.bob_channel_owner);
        assertEq(commProxy.pushChannelAdmin(), actor.bob_channel_owner);
    }

    function test_RevertWhen_NonAdminTriesToSet_ThePushTokenAddress() external {
        // it should REVERT
        changePrank(actor.bob_channel_owner);
        vm.expectRevert(Errors.CallerNotAdmin.selector);
        commProxy.setPushTokenAddress(address(123));
        assertEq(commProxy.PUSH_TOKEN_ADDRESS(), address(pushToken));
    }

    function test_WhenAdminSets_ThePushTokenAddress() external {
        // it should update the push token address

        changePrank(actor.admin);
        commProxy.setPushTokenAddress(address(123));
        assertEq(commProxy.PUSH_TOKEN_ADDRESS(), address(123));
    }
}
