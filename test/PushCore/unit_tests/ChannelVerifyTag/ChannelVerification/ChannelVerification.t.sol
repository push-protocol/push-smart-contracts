pragma solidity ^0.8.20;

import { BasePushCoreTest } from "../../BasePushCoreTest.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";

contract ChannelVerification_Test is BasePushCoreTest {
    bytes32 bobBytes; 
    bytes32 aliceBytes;
    bytes32 charlieBytes;
    bytes32 adminBytes;
    function setUp() public virtual override {
        BasePushCoreTest.setUp();
        _createChannel(actor.bob_channel_owner);
        _createChannel(actor.alice_channel_owner);
        _createChannel(actor.charlie_channel_owner);

        bobBytes = toWormholeFormat(actor.bob_channel_owner);
        aliceBytes = toWormholeFormat(actor.alice_channel_owner);
        charlieBytes = toWormholeFormat(actor.charlie_channel_owner);
        adminBytes = toWormholeFormat(actor.admin);
    }

    modifier whenCheckedTheDefaultVerificationStatus() {
        _;
    }

    function test_WhenChecked_TheVerificationStatusFor_AdminOrZeroAddress()
        external
        whenCheckedTheDefaultVerificationStatus
    {
        uint8 adminVerification = coreProxy.getChannelVerfication(toWormholeFormat(actor.admin));
        uint8 zeroAddressVerification = coreProxy.getChannelVerfication(toWormholeFormat(address(0)));

        assertEq(adminVerification, 1);

        address Admin_verifiedBy = _getVerifiedBy(actor.admin);

        assertEq(Admin_verifiedBy, address(0));
    }

    function test_WhenChecked_TheVerificationStatusFor_UnverifiedChannel()
        external
        whenCheckedTheDefaultVerificationStatus
    {
        // it should return 0 for unverified Channels
        uint8 bobVerification = coreProxy.getChannelVerfication(bobBytes);
        uint8 aliceVerification = coreProxy.getChannelVerfication(aliceBytes);

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
        coreProxy.verifyChannel(toWormholeFormat(actor.tim_push_holder));

        uint8 timVerification = coreProxy.getChannelVerfication(toWormholeFormat(actor.tim_push_holder));
        assertEq(timVerification, 0);

        address Tim_verifiedBy = _getVerifiedBy(actor.tim_push_holder);
        assertEq(Tim_verifiedBy, address(0));
    }

    function test_WhenAdmin_Verifies_ActiveChannel() external {
        // it should return primary verified for channels verified by admin
        changePrank(actor.admin);
        vm.expectEmit(true, true, false, false);
        emit ChannelVerified(channelCreators.bob_channel_owner_Bytes32, adminBytes);
        coreProxy.verifyChannel(bobBytes);

        uint8 bobVerification = coreProxy.getChannelVerfication(bobBytes);
        assertEq(bobVerification, 1);

        address Bob_verifiedBy = _getVerifiedBy(actor.bob_channel_owner);
        assertEq(Bob_verifiedBy, actor.admin);
    }

    function test_WhenAVerifiedChannel_Verifies_AnotherChannel() external {
        // it should give secondary verification(2) to that channel
        changePrank(actor.admin);
        vm.expectEmit(true, true, false, false);
        emit ChannelVerified(channelCreators.bob_channel_owner_Bytes32, adminBytes);
        coreProxy.verifyChannel(bobBytes);

        changePrank(actor.bob_channel_owner);
        vm.expectEmit(true, true, false, false);
        emit ChannelVerified(channelCreators.alice_channel_owner_Bytes32, bobBytes);
        coreProxy.verifyChannel(aliceBytes);

        uint8 aliceVerification = coreProxy.getChannelVerfication(aliceBytes);
        assertEq(aliceVerification, 2);

        address Alice_verifiedBy = _getVerifiedBy(actor.alice_channel_owner);
        assertEq(Alice_verifiedBy, actor.bob_channel_owner);
    }

    function test_RevertWhen_AnUnverifiedChannelTries_VerifyingAnotherChannel() external {
        // it should REVERT
        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedCaller.selector, actor.bob_channel_owner));
        changePrank(actor.bob_channel_owner);
        coreProxy.verifyChannel(aliceBytes);

        uint8 aliceVerification = coreProxy.getChannelVerfication(aliceBytes);
        assertEq(aliceVerification, 0);

        address Alice_verifiedBy = _getVerifiedBy(actor.alice_channel_owner);
        assertEq(Alice_verifiedBy, address(0));
    }

    function test_WhenAdminUpgrades_TheVerification() external {
        // it should allow admin to give primary verification
        changePrank(actor.admin);
        vm.expectEmit(true, true, false, false);
        emit ChannelVerified(channelCreators.bob_channel_owner_Bytes32, adminBytes);
        coreProxy.verifyChannel(bobBytes);

        vm.expectEmit(true, true, false, false);
        emit ChannelVerified(channelCreators.alice_channel_owner_Bytes32, bobBytes);
        changePrank(actor.bob_channel_owner);
        coreProxy.verifyChannel(aliceBytes);

        uint8 aliceVerificationBefore = coreProxy.getChannelVerfication(aliceBytes);
        assertEq(aliceVerificationBefore, 2);

        address Alice_verifiedByBefore = _getVerifiedBy(actor.alice_channel_owner);
        assertEq(Alice_verifiedByBefore, actor.bob_channel_owner);

        changePrank(actor.admin);
        vm.expectEmit(true, true, false, false);
        emit ChannelVerified(channelCreators.alice_channel_owner_Bytes32, adminBytes);
        coreProxy.verifyChannel(aliceBytes);

        uint8 aliceVerificationAfter = coreProxy.getChannelVerfication(aliceBytes);
        assertEq(aliceVerificationAfter, 1);

        address Alice_verifiedByAfter = _getVerifiedBy(actor.alice_channel_owner);
        assertEq(Alice_verifiedByAfter, actor.admin);
    }

    function test_RevertWhen_APrimaryVerifiedChannelVerifies_AnotherPrimaryVerifiedChannel() external {
        // it should REVERT- not allowing downgrade primary verified to secondary

        changePrank(actor.admin);
        vm.expectEmit(true, true, false, false);
        emit ChannelVerified(channelCreators.bob_channel_owner_Bytes32, adminBytes);
        coreProxy.verifyChannel(bobBytes);

        vm.expectEmit(true, true, false, false);
        emit ChannelVerified(channelCreators.alice_channel_owner_Bytes32, adminBytes);
        coreProxy.verifyChannel(aliceBytes);

        uint8 aliceVerificationBefore = coreProxy.getChannelVerfication(aliceBytes);
        assertEq(aliceVerificationBefore, 1);

        address Alice_verifiedByBefore = _getVerifiedBy(actor.alice_channel_owner);
        assertEq(Alice_verifiedByBefore, actor.admin);

        vm.expectRevert(Errors.Core_InvalidChannel.selector);
        changePrank(actor.bob_channel_owner);
        coreProxy.verifyChannel(aliceBytes);

        uint8 aliceVerificationAfter = coreProxy.getChannelVerfication(aliceBytes);
        assertEq(aliceVerificationAfter, 1);

        address Alice_verifiedByAfter = _getVerifiedBy(actor.alice_channel_owner);
        assertEq(Alice_verifiedByAfter, actor.admin);
    }

    function test_When_ASecondaryVerifiedChannel_VerifiesAnotherChannel() external {
        // it should give secondary verification to that channel
        changePrank(actor.admin);
        vm.expectEmit(true, true, false, false);
        emit ChannelVerified(channelCreators.bob_channel_owner_Bytes32, adminBytes);
        coreProxy.verifyChannel(bobBytes);

        changePrank(actor.bob_channel_owner);
        vm.expectEmit(true, true, false, false);
        emit ChannelVerified(channelCreators.charlie_channel_owner_Bytes32, bobBytes);
        coreProxy.verifyChannel(charlieBytes);

        changePrank(actor.charlie_channel_owner);
        vm.expectEmit(true, true, false, false);
        emit ChannelVerified(channelCreators.alice_channel_owner_Bytes32, charlieBytes);
        coreProxy.verifyChannel(aliceBytes);

        uint8 aliceVerification = coreProxy.getChannelVerfication(aliceBytes);
        assertEq(aliceVerification, 2);

        address Alice_verifiedBy = _getVerifiedBy(actor.alice_channel_owner);
        assertEq(Alice_verifiedBy, actor.charlie_channel_owner);
    }

    function test_RevertWhen_NonAdminCalls_BatchVerification() external {
        // it should REVERT- not allowing anyone other than Admin
        bytes32[] memory _channels = new bytes32[](2);
        _channels[0] = charlieBytes;
        _channels[1] = aliceBytes;

        vm.expectRevert(Errors.CallerNotAdmin.selector);
        changePrank(actor.bob_channel_owner);
        coreProxy.batchVerification(0, 2, _channels);
        uint8 charlieVerificationAfter = coreProxy.getChannelVerfication(charlieBytes);
        uint8 aliceVerificationAfter = coreProxy.getChannelVerfication(aliceBytes);

        assertEq(charlieVerificationAfter, 0, "charlie");
        assertEq(aliceVerificationAfter, 0, "alice");
    }

    function test_WhenAdminCalls_BatchVerification() external {
        // it should execute and set the verifications to primary
        bytes32[] memory _channels = new bytes32[](3);
        _channels[0] = charlieBytes;
        _channels[1] = bobBytes;
        _channels[2] = aliceBytes;

        changePrank(actor.admin);
        vm.expectEmit(true, true, false, false);
        emit ChannelVerified(channelCreators.charlie_channel_owner_Bytes32, adminBytes);
        vm.expectEmit(true, true, false, false);
        emit ChannelVerified(channelCreators.bob_channel_owner_Bytes32, adminBytes);
        vm.expectEmit(true, true, false, false);
        emit ChannelVerified(channelCreators.alice_channel_owner_Bytes32, adminBytes);
        coreProxy.batchVerification(0, 3, _channels);

        uint8 charlieVerificationAfter = coreProxy.getChannelVerfication(charlieBytes);
        uint8 aliceVerificationAfter = coreProxy.getChannelVerfication(aliceBytes);
        uint8 bobVerificationAfter = coreProxy.getChannelVerfication(bobBytes);

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
