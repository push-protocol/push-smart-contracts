pragma solidity ^0.8.20;

import { BasePushCoreTest } from "../../BasePushCoreTest.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";

contract ChannelVerification_Test is BasePushCoreTest {
    function setUp() public virtual override {
        BasePushCoreTest.setUp();
        _createChannel(actor.bob_channel_owner);
        _createChannel(actor.alice_channel_owner);
        _createChannel(actor.charlie_channel_owner);
    }

    modifier whenCheckedTheDefaultVerificationStatus() {
        _;
    }

    function test_WhenChecked_TheVerificationStatusFor_AdminOrZeroAddress()
        external
        whenCheckedTheDefaultVerificationStatus
    {
        uint8 adminVerification = coreProxy.getChannelVerfication(actor.admin);
        uint8 zeroAddressVerification = coreProxy.getChannelVerfication(address(0));

        assertEq(adminVerification, 1);
        assertEq(adminVerification, zeroAddressVerification);

        address Admin_verifiedBy = _getVerifiedBy(actor.admin);
        address Zero_verifiedBy = _getVerifiedBy(address(0));

        assertEq(Admin_verifiedBy, address(0));
        assertEq(Zero_verifiedBy, address(0));
    }

    function test_WhenChecked_TheVerificationStatusFor_UnverifiedChannel()
        external
        whenCheckedTheDefaultVerificationStatus
    {
        // it should return 0 for unverified Channels
        uint8 bobVerification = coreProxy.getChannelVerfication(actor.bob_channel_owner);
        uint8 aliceVerification = coreProxy.getChannelVerfication(actor.alice_channel_owner);

        assertEq(aliceVerification, 0);
        assertEq(bobVerification, aliceVerification);

        address Bob_verifiedBy = _getVerifiedBy(actor.bob_channel_owner);
        address Alice_verifiedBy = _getVerifiedBy(actor.alice_channel_owner);

        assertEq(Bob_verifiedBy, address(0));
        assertEq(Alice_verifiedBy, address(0));
    }
    function test_RevertWhen_Admin_Verifies_InactiveChannel() external {
        // it should return primary verified for channels verified by admin
        changePrank(actor.admin);
        vm.expectRevert(Errors.Core_InvalidChannel.selector);
        coreProxy.verifyChannel(actor.tim_push_holder);

        uint8 timVerification = coreProxy.getChannelVerfication(actor.tim_push_holder);
        assertEq(timVerification, 0);

        address Tim_verifiedBy = _getVerifiedBy(actor.tim_push_holder);
        assertEq(Tim_verifiedBy, address(0));
    }
    function test_WhenAdmin_Verifies_ActiveChannel() external {
        // it should return primary verified for channels verified by admin
        changePrank(actor.admin);
        vm.expectEmit(true,true,false,false);
        emit ChannelVerified(actor.bob_channel_owner,actor.admin);
        coreProxy.verifyChannel(actor.bob_channel_owner);

        uint8 bobVerification = coreProxy.getChannelVerfication(actor.bob_channel_owner);
        assertEq(bobVerification, 1);

        address Bob_verifiedBy = _getVerifiedBy(actor.bob_channel_owner);
        assertEq(Bob_verifiedBy, actor.admin);
    }

    function test_WhenAVerifiedChannel_Verifies_AnotherChannel() external {
        // it should give secondary verification(2) to that channel
        changePrank(actor.admin);
        vm.expectEmit(true,true,false,false);
        emit ChannelVerified(actor.bob_channel_owner,actor.admin);
        coreProxy.verifyChannel(actor.bob_channel_owner);

        changePrank(actor.bob_channel_owner);
        vm.expectEmit(true,true,false,false);
        emit ChannelVerified(actor.alice_channel_owner,actor.bob_channel_owner);
        coreProxy.verifyChannel(actor.alice_channel_owner);

        uint8 aliceVerification = coreProxy.getChannelVerfication(actor.alice_channel_owner);
        assertEq(aliceVerification, 2);

        address Alice_verifiedBy = _getVerifiedBy(actor.alice_channel_owner);
        assertEq(Alice_verifiedBy, actor.bob_channel_owner);
    }

    function test_RevertWhen_AnUnverifiedChannelTries_VerifyingAnotherChannel() external {
        // it should REVERT
        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedCaller.selector, actor.bob_channel_owner));
        changePrank(actor.bob_channel_owner);
        coreProxy.verifyChannel(actor.alice_channel_owner);

        uint8 aliceVerification = coreProxy.getChannelVerfication(actor.alice_channel_owner);
        assertEq(aliceVerification, 0);

        address Alice_verifiedBy = _getVerifiedBy(actor.alice_channel_owner);
        assertEq(Alice_verifiedBy, address(0));
    }

    function test_WhenAdminUpgrades_TheVerification() external {
        // it should allow admin to give primary verification
        changePrank(actor.admin);
        vm.expectEmit(true,true,false,false);
        emit ChannelVerified(actor.bob_channel_owner,actor.admin);
        coreProxy.verifyChannel(actor.bob_channel_owner);

        vm.expectEmit(true,true,false,false);
        emit ChannelVerified(actor.alice_channel_owner,actor.bob_channel_owner);
        changePrank(actor.bob_channel_owner);
        coreProxy.verifyChannel(actor.alice_channel_owner);

        uint8 aliceVerificationBefore = coreProxy.getChannelVerfication(actor.alice_channel_owner);
        assertEq(aliceVerificationBefore, 2);

        address Alice_verifiedByBefore = _getVerifiedBy(actor.alice_channel_owner);
        assertEq(Alice_verifiedByBefore, actor.bob_channel_owner);

        changePrank(actor.admin);
        vm.expectEmit(true,true,false,false);
        emit ChannelVerified(actor.alice_channel_owner,actor.admin);
        coreProxy.verifyChannel(actor.alice_channel_owner);

        uint8 aliceVerificationAfter = coreProxy.getChannelVerfication(actor.alice_channel_owner);
        assertEq(aliceVerificationAfter, 1);

        address Alice_verifiedByAfter = _getVerifiedBy(actor.alice_channel_owner);
        assertEq(Alice_verifiedByAfter, actor.admin);
    }

    function test_RevertWhen_APrimaryVerifiedChannelVerifies_AnotherPrimaryVerifiedChannel() external {
        // it should REVERT- not allowing downgrade primary verified to secondary

        changePrank(actor.admin);
        vm.expectEmit(true,true,false,false);
        emit ChannelVerified(actor.bob_channel_owner,actor.admin);
        coreProxy.verifyChannel(actor.bob_channel_owner);

        vm.expectEmit(true,true,false,false);
        emit ChannelVerified(actor.alice_channel_owner,actor.admin);
        coreProxy.verifyChannel(actor.alice_channel_owner);

        uint8 aliceVerificationBefore = coreProxy.getChannelVerfication(actor.alice_channel_owner);
        assertEq(aliceVerificationBefore, 1);

        address Alice_verifiedByBefore = _getVerifiedBy(actor.alice_channel_owner);
        assertEq(Alice_verifiedByBefore, actor.admin);

        vm.expectRevert(Errors.Core_InvalidChannel.selector);
        changePrank(actor.bob_channel_owner);
        coreProxy.verifyChannel(actor.alice_channel_owner);

        uint8 aliceVerificationAfter = coreProxy.getChannelVerfication(actor.alice_channel_owner);
        assertEq(aliceVerificationAfter, 1);

        address Alice_verifiedByAfter = _getVerifiedBy(actor.alice_channel_owner);
        assertEq(Alice_verifiedByAfter, actor.admin);
    }

    function test_When_ASecondaryVerifiedChannel_VerifiesAnotherChannel() external {
        // it should give secondary verification to that channel
        changePrank(actor.admin);
        vm.expectEmit(true,true,false,false);
        emit ChannelVerified(actor.bob_channel_owner,actor.admin);
        coreProxy.verifyChannel(actor.bob_channel_owner);

        changePrank(actor.bob_channel_owner);
        vm.expectEmit(true,true,false,false);
        emit ChannelVerified(actor.charlie_channel_owner,actor.bob_channel_owner);
        coreProxy.verifyChannel(actor.charlie_channel_owner);

        changePrank(actor.charlie_channel_owner);
        vm.expectEmit(true,true,false,false);
        emit ChannelVerified(actor.alice_channel_owner,actor.charlie_channel_owner);
        coreProxy.verifyChannel(actor.alice_channel_owner);

        uint8 aliceVerification = coreProxy.getChannelVerfication(actor.alice_channel_owner);
        assertEq(aliceVerification, 2);

        address Alice_verifiedBy = _getVerifiedBy(actor.alice_channel_owner);
        assertEq(Alice_verifiedBy, actor.charlie_channel_owner);
    }

    function test_RevertWhen_NonAdminCalls_BatchVerification() external {
        // it should REVERT- not allowing anyone other than Admin
        address[] memory _channels = new address[](2);
        _channels[0] = actor.charlie_channel_owner;
        _channels[1] = actor.alice_channel_owner;

        vm.expectRevert(Errors.CallerNotAdmin.selector);
        changePrank(actor.bob_channel_owner);
        coreProxy.batchVerification(0, 2, _channels);
        uint8 charlieVerificationAfter = coreProxy.getChannelVerfication(actor.charlie_channel_owner);
        uint8 aliceVerificationAfter = coreProxy.getChannelVerfication(actor.alice_channel_owner);

        assertEq(charlieVerificationAfter, 0, "charlie");
        assertEq(aliceVerificationAfter, 0, "alice");
    }

    function test_WhenAdminCalls_BatchVerification() external {
        // it should execute and set the verifications to primary
        address[] memory _channels = new address[](3);
        _channels[0] = actor.charlie_channel_owner;
        _channels[1] = actor.bob_channel_owner;
        _channels[2] = actor.alice_channel_owner;

        changePrank(actor.admin);
        vm.expectEmit(true,true,false,false);
        emit ChannelVerified(actor.charlie_channel_owner,actor.admin);
        vm.expectEmit(true,true,false,false);
        emit ChannelVerified(actor.bob_channel_owner,actor.admin);
        vm.expectEmit(true,true,false,false);
        emit ChannelVerified(actor.alice_channel_owner,actor.admin);
        coreProxy.batchVerification(0, 3, _channels);

        uint8 charlieVerificationAfter = coreProxy.getChannelVerfication(actor.charlie_channel_owner);
        uint8 aliceVerificationAfter = coreProxy.getChannelVerfication(actor.alice_channel_owner);
        uint8 bobVerificationAfter = coreProxy.getChannelVerfication(actor.bob_channel_owner);

        assertEq(charlieVerificationAfter, 1, "charlie");
        assertEq(aliceVerificationAfter, 1, "alice");
        assertEq(bobVerificationAfter, 1, "bob");

        address Bob_verifiedBy = _getVerifiedBy(actor.bob_channel_owner);
        address Alice_verifiedBy = _getVerifiedBy(actor.alice_channel_owner);
        address Charlie_verifiedBy = _getVerifiedBy(actor.alice_channel_owner);

        assertEq(Bob_verifiedBy, actor.admin);
        assertEq(Alice_verifiedBy, actor.admin);
        assertEq(Charlie_verifiedBy, actor.admin);
    }
}
