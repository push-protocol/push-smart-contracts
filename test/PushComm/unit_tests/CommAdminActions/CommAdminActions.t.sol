pragma solidity ^0.8.0;
import {BasePushCommTest} from "../BasePushCommTest.t.sol";
import {Errors} from "contracts/libraries/Errors.sol";

contract CommAdminActions_Test is BasePushCommTest {
    function setUp() public override {
        BasePushCommTest.setUp();
    }

    function test_REVERTWhen_Non_adminTriesToChangeCoreAddress() external {
        // it should REVERT
        changePrank(actor.bob_channel_owner);
        vm.expectRevert(Errors.CallerNotAdmin.selector);
        commProxy.setEPNSCoreAddress(address(123));
        assertEq(commProxy.EPNSCoreAddress(), address(coreProxy));
    }

    function test_WhenAdminTriesToChangeCoreAddress() external {
        // it should update the core address
        changePrank(actor.admin);
        commProxy.setEPNSCoreAddress(address(123));
        assertEq(commProxy.EPNSCoreAddress(), address(123));
    }

    function test_REVERTWhen_Non_adminTriesToChangeGovernanceAddress()
        external
    {
        // it should REVERT
        changePrank(actor.bob_channel_owner);
        vm.expectRevert(Errors.CallerNotAdmin.selector);
        commProxy.setGovernanceAddress(actor.governance);
        assertEq(commProxy.governance(), actor.admin);
    }

    function test_WhenAdminChangesTheGovernanceAddress() external {
        // it should update the governance address
        changePrank(actor.admin);
        commProxy.setGovernanceAddress(actor.governance);
        assertEq(commProxy.governance(), actor.governance);
    }

    function test_REVERTWhen_Non_adminTransfersThePushChannelAdminControl()
        external
    {
        // it should REVERT
        changePrank(actor.bob_channel_owner);
        vm.expectRevert(Errors.CallerNotAdmin.selector);
        commProxy.transferPushChannelAdminControl(actor.bob_channel_owner);
        assertEq(commProxy.pushChannelAdmin(), actor.admin);
    }

    function test_REVERTWhen_AdminTransfersTheAdminControlToAZeroAddress()
        external
    {
        // it should REVERT
        changePrank(actor.admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidArgument_WrongAddress.selector,
                address(0)
            )
        );
        commProxy.transferPushChannelAdminControl(address(0));
        assertEq(commProxy.pushChannelAdmin(), actor.admin);
    }

    function test_REVERTWhen_AdminTransfersTheAdminControlToItself() external {
        // it should REVERT
        changePrank(actor.admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidArgument_WrongAddress.selector,
                actor.admin
            )
        );
        commProxy.transferPushChannelAdminControl(actor.admin);
    }

    function test_WhenAdminTransfersAdminControlToCorrectAddress() external {
        // it should update the admin control
        changePrank(actor.admin);

        commProxy.transferPushChannelAdminControl(actor.bob_channel_owner);
        assertEq(commProxy.pushChannelAdmin(), actor.bob_channel_owner);
    }

    function test_REVERTWhen_Non_adminTriesToSetThePushTokenAddress() external {
        // it should REVERT
        changePrank(actor.bob_channel_owner);
        vm.expectRevert(Errors.CallerNotAdmin.selector);
        commProxy.setPushTokenAddress(address(123));
        assertEq(commProxy.PUSH_TOKEN_ADDRESS(), address(pushToken));
    }

    function test_WhenAdminSetsThePushTokenAddress() external {
        // it should update the push token address

        changePrank(actor.admin);
        commProxy.setPushTokenAddress(address(123));
        assertEq(commProxy.PUSH_TOKEN_ADDRESS(), address(123));
    }
}
