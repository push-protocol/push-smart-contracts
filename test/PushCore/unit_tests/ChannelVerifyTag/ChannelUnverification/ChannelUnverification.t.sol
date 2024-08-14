pragma solidity ^0.8.20;

import { BasePushCoreTest } from "../../BasePushCoreTest.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";

contract ChannelUnverification_Test is BasePushCoreTest {
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

    function test_WhenAdminUnverifies_AChannelVerifiedBy_AdminItself() external {
        // it should be able to unverify
        changePrank(actor.admin);
        coreProxy.verifyChannel(bobBytes);

        uint8 bobVerificationBefore = coreProxy.getChannelVerfication(bobBytes);
        assertEq(bobVerificationBefore, 1);

        changePrank(actor.admin);
        vm.expectEmit(true, true, false, false);
        emit ChannelVerificationRevoked(channelCreators.bob_channel_owner_Bytes32, adminBytes);
        coreProxy.unverifyChannel(bobBytes);

        uint8 bobVerificationAfter = coreProxy.getChannelVerfication(bobBytes);
        assertEq(bobVerificationAfter, 0);

        address Bob_verifiedBy = _getVerifiedBy(actor.bob_channel_owner);
        assertEq(Bob_verifiedBy, address(0));
    }

    function test_WhenAdminUnverifies_AChannelVerifiedBy_AnotherChannel() external {
        // it should be able to unverify
        changePrank(actor.admin);
        coreProxy.verifyChannel(bobBytes);
        changePrank(actor.bob_channel_owner);
        coreProxy.verifyChannel(aliceBytes);

        uint8 aliceVerification = coreProxy.getChannelVerfication(aliceBytes);
        assertEq(aliceVerification, 2);

        changePrank(actor.admin);
        vm.expectEmit(true, true, false, false);
        emit ChannelVerificationRevoked(channelCreators.alice_channel_owner_Bytes32, adminBytes);
        coreProxy.unverifyChannel(aliceBytes);

        uint8 aliceVerificationAfter = coreProxy.getChannelVerfication(aliceBytes);
        assertEq(aliceVerificationAfter, 0);

        address Alice_verifiedBy = _getVerifiedBy(actor.alice_channel_owner);
        assertEq(Alice_verifiedBy, address(0));
    }

    function test_WhenAChannelUnverifies_ASecondaryVerifiedChannel_VerifiedByItself() external {
        // it should be able to unverify
        changePrank(actor.admin);
        coreProxy.verifyChannel(bobBytes);
        changePrank(actor.bob_channel_owner);
        coreProxy.verifyChannel(aliceBytes);

        uint8 aliceVerification = coreProxy.getChannelVerfication(aliceBytes);
        assertEq(aliceVerification, 2);

        changePrank(actor.bob_channel_owner);
        vm.expectEmit(true, true, false, false);
        emit ChannelVerificationRevoked(channelCreators.alice_channel_owner_Bytes32, bobBytes);
        coreProxy.unverifyChannel(aliceBytes);

        uint8 aliceVerificationAfter = coreProxy.getChannelVerfication(aliceBytes);
        assertEq(aliceVerificationAfter, 0);

        address Alice_verifiedBy = _getVerifiedBy(actor.alice_channel_owner);
        assertEq(Alice_verifiedBy, address(0));
    }

    function test_RevertWhen_AChannelUnverifies_ASecondaryVerifiedChannel_VerifiedByAnotherChannel() external {
        // it should REVERT
        changePrank(actor.admin);
        coreProxy.verifyChannel(bobBytes);
        coreProxy.verifyChannel(charlieBytes);

        changePrank(actor.bob_channel_owner);
        coreProxy.verifyChannel(aliceBytes);

        uint8 aliceVerification = coreProxy.getChannelVerfication(aliceBytes);
        assertEq(aliceVerification, 2);

        vm.expectRevert(Errors.CallerNotAdmin.selector);
        changePrank(actor.charlie_channel_owner);
        coreProxy.unverifyChannel(aliceBytes);

        uint8 aliceVerificationAfter = coreProxy.getChannelVerfication(aliceBytes);
        assertEq(aliceVerificationAfter, 2);

        address Alice_verifiedBy = _getVerifiedBy(actor.alice_channel_owner);
        assertEq(Alice_verifiedBy, actor.bob_channel_owner);
    }

    function test_WhenASecondaryVerifiedChannel_UnverifiesAnotherSecondaryChannel_VerifiedByItself() external {
        // it should unverify those channels
        changePrank(actor.admin);
        coreProxy.verifyChannel(bobBytes);

        changePrank(actor.bob_channel_owner);
        coreProxy.verifyChannel(charlieBytes);

        changePrank(actor.charlie_channel_owner);
        coreProxy.verifyChannel(aliceBytes);

        uint8 aliceVerification = coreProxy.getChannelVerfication(aliceBytes);
        assertEq(aliceVerification, 2);

        changePrank(actor.charlie_channel_owner);
        vm.expectEmit(true, true, false, false);
        emit ChannelVerificationRevoked(channelCreators.alice_channel_owner_Bytes32, charlieBytes);
        coreProxy.unverifyChannel(aliceBytes);

        uint8 aliceVerificationAfter = coreProxy.getChannelVerfication(aliceBytes);
        assertEq(aliceVerificationAfter, 0);

        address Alice_verifiedBy = _getVerifiedBy(actor.alice_channel_owner);
        assertEq(Alice_verifiedBy, address(0));
    }

    function test_WhenASecondaryVerifiedChannel_GetsUnverifed() external {
        // it should unverify any other secondary verified channel that is verified by this channel
        changePrank(actor.admin);
        coreProxy.verifyChannel(bobBytes);

        changePrank(actor.bob_channel_owner);
        coreProxy.verifyChannel(charlieBytes);

        changePrank(actor.charlie_channel_owner);
        coreProxy.verifyChannel(aliceBytes);

        uint8 aliceVerification = coreProxy.getChannelVerfication(aliceBytes);
        assertEq(aliceVerification, 2);

        changePrank(actor.bob_channel_owner);
        vm.expectEmit(true, true, false, false);
        emit ChannelVerificationRevoked(channelCreators.charlie_channel_owner_Bytes32, bobBytes);
        coreProxy.unverifyChannel(charlieBytes);

        uint8 charlieVerificationAfter = coreProxy.getChannelVerfication(charlieBytes);
        uint8 aliceVerificationAfter = coreProxy.getChannelVerfication(aliceBytes);

        assertEq(charlieVerificationAfter, 0, "charlie");
        assertEq(aliceVerificationAfter, 0, "alice");

        address Alice_verifiedBy = _getVerifiedBy(actor.alice_channel_owner);
        assertEq(Alice_verifiedBy, actor.charlie_channel_owner, "Alice");
        address Charlie_verifiedBy = _getVerifiedBy(actor.charlie_channel_owner);
        assertEq(Charlie_verifiedBy, address(0), "Charlie");
    }

    function test_WhenAdminUnverifies_AnyChannelPrimaryOrSecondary() external {
        // it should unverify all of them as well as any secondary channel verified by those channels
        changePrank(actor.admin);
        coreProxy.verifyChannel(bobBytes);

        changePrank(actor.bob_channel_owner);
        coreProxy.verifyChannel(charlieBytes);

        changePrank(actor.charlie_channel_owner);
        coreProxy.verifyChannel(aliceBytes);

        uint8 aliceVerification = coreProxy.getChannelVerfication(aliceBytes);
        assertEq(aliceVerification, 2);

        changePrank(actor.admin);
        vm.expectEmit(true, true, false, false);
        emit ChannelVerificationRevoked(channelCreators.bob_channel_owner_Bytes32, adminBytes);
        coreProxy.unverifyChannel(bobBytes);

        uint8 bobVerificationAfter = coreProxy.getChannelVerfication(bobBytes);
        uint8 charlieVerificationAfter = coreProxy.getChannelVerfication(charlieBytes);
        uint8 aliceVerificationAfter = coreProxy.getChannelVerfication(aliceBytes);

        assertEq(charlieVerificationAfter, 0, "charlie");
        assertEq(aliceVerificationAfter, 0, "alice");
        assertEq(bobVerificationAfter, 0, "bob");

        address Alice_verifiedBy = _getVerifiedBy(actor.alice_channel_owner);
        assertEq(Alice_verifiedBy, actor.charlie_channel_owner, "Alice");
        address Charlie_verifiedBy = _getVerifiedBy(actor.charlie_channel_owner);
        assertEq(Charlie_verifiedBy, actor.bob_channel_owner, "Charlie");
        address Bob_verifiedBy = _getVerifiedBy(actor.bob_channel_owner);
        assertEq(Bob_verifiedBy, address(0), "Bob");
    }
}
