pragma solidity ^0.8.20;

import {BasePushCoreTest} from "../BasePushCoreTest.t.sol";
import {Errors} from "contracts/libraries/Errors.sol";

contract UpdateChannelMeta_Test is BasePushCoreTest {
    function setUp() public virtual override {
        BasePushCoreTest.setUp();
        _createChannel(actor.bob_channel_owner);
        _createChannel(actor.alice_channel_owner);
        _createChannel(actor.charlie_channel_owner);
    }

    modifier whenCheckedTheDefaultVerificationStatus() {
        _;
    }

    function test_WhenCheckedTheVerificationStatusForAdminOrZeroAddress()
        external
        whenCheckedTheDefaultVerificationStatus
    {
        uint8 adminVerification = coreProxy.getChannelVerfication(actor.admin);
        uint8 zeroAddressVerification = coreProxy.getChannelVerfication(
            address(0)
        );

        assertEq(adminVerification, 1);
        assertEq(adminVerification, zeroAddressVerification);
    }

    function test_WhenCheckedTheVerificationStatusForUnverifiedChannel()
        external
        whenCheckedTheDefaultVerificationStatus
    {
        // it should return 0 for unverified Channels
        uint8 bobVerification = coreProxy.getChannelVerfication(
            actor.bob_channel_owner
        );
        uint8 aliceVerification = coreProxy.getChannelVerfication(
            actor.alice_channel_owner
        );

        assertEq(aliceVerification, 0);
        assertEq(bobVerification, aliceVerification);
    }

    function test_WhenAdminVerifiesAChannel() external {
        // it should return primary verified for channels verified by admin
        changePrank(actor.admin);
        coreProxy.verifyChannel(actor.bob_channel_owner);

        uint8 bobVerification = coreProxy.getChannelVerfication(
            actor.bob_channel_owner
        );
        assertEq(bobVerification, 1);
    }

    function test_WhenAVerifiedChannelVerifiesAnotherChannel() external {
        // it should give secondary verification(2) to that channel
        changePrank(actor.admin);
        coreProxy.verifyChannel(actor.bob_channel_owner);
        changePrank(actor.bob_channel_owner);
        coreProxy.verifyChannel(actor.alice_channel_owner);

        uint8 aliceVerification = coreProxy.getChannelVerfication(
            actor.alice_channel_owner
        );
        assertEq(aliceVerification, 2);
    }

    function test_RevertWhen_AnUnverifiedChannelTriesVerifyingAnotherChannel()
        external
    {
        // it should REVERT
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.UnauthorizedCaller.selector,
                actor.bob_channel_owner
            )
        );
        changePrank(actor.bob_channel_owner);
        coreProxy.verifyChannel(actor.alice_channel_owner);

        uint8 aliceVerification = coreProxy.getChannelVerfication(
            actor.alice_channel_owner
        );
        assertEq(aliceVerification, 0);
    }

    function test_WhenAdminUpgradesTheVerification() external {
        // it should allow admin to give primary verification
        changePrank(actor.admin);
        coreProxy.verifyChannel(actor.bob_channel_owner);
        changePrank(actor.bob_channel_owner);
        coreProxy.verifyChannel(actor.alice_channel_owner);

        uint8 aliceVerificationBefore = coreProxy.getChannelVerfication(
            actor.alice_channel_owner
        );
        assertEq(aliceVerificationBefore, 2);

        changePrank(actor.admin);
        coreProxy.verifyChannel(actor.alice_channel_owner);

        uint8 aliceVerificationAfter = coreProxy.getChannelVerfication(
            actor.alice_channel_owner
        );
        assertEq(aliceVerificationAfter, 1);
    }

    function test_RevertWhen_APrimaryVerifiedChannelVerifiesAnotherPrimaryErifiedChannel()
        external
    {
        // it should REVERT- not allowing downgrade primary verified to secondary

        changePrank(actor.admin);
        coreProxy.verifyChannel(actor.bob_channel_owner);
        changePrank(actor.admin);
        coreProxy.verifyChannel(actor.charlie_channel_owner);

        changePrank(actor.bob_channel_owner);
        coreProxy.verifyChannel(actor.alice_channel_owner);

        uint8 aliceVerificationBefore = coreProxy.getChannelVerfication(
            actor.alice_channel_owner
        );
        assertEq(aliceVerificationBefore, 2);

        vm.expectRevert(Errors.Core_InvalidChannel.selector);
        changePrank(actor.charlie_channel_owner);
        coreProxy.verifyChannel(actor.alice_channel_owner);

        uint8 aliceVerificationAfter = coreProxy.getChannelVerfication(
            actor.alice_channel_owner
        );
        assertEq(aliceVerificationAfter, 2);
    }

    function test_WhenAdminUnverifiesAChannelVerifiedByAdminItself() external {
        // it should be able to unverify
        changePrank(actor.admin);
        coreProxy.verifyChannel(actor.bob_channel_owner);

        uint8 bobVerificationBefore = coreProxy.getChannelVerfication(
            actor.bob_channel_owner
        );
        assertEq(bobVerificationBefore, 1);

        changePrank(actor.admin);
        coreProxy.unverifyChannel(actor.bob_channel_owner);

        uint8 bobVerificationAfter = coreProxy.getChannelVerfication(
            actor.bob_channel_owner
        );
        assertEq(bobVerificationAfter, 0);
    }

    function test_WhenAdminUnverifiesAChannelVerifiedByAnotherChannel()
        external
    {
        // it should be able to unverify
        changePrank(actor.admin);
        coreProxy.verifyChannel(actor.bob_channel_owner);
        changePrank(actor.bob_channel_owner);
        coreProxy.verifyChannel(actor.alice_channel_owner);

        uint8 aliceVerification = coreProxy.getChannelVerfication(
            actor.alice_channel_owner
        );
        assertEq(aliceVerification, 2);

        changePrank(actor.admin);
        coreProxy.unverifyChannel(actor.alice_channel_owner);

        uint8 aliceVerificationAfter = coreProxy.getChannelVerfication(
            actor.alice_channel_owner
        );
        assertEq(aliceVerificationAfter, 0);
    }

    function test_WhenAChannelUnverifiesASecondaryVerifiedChannelVerifiedByItself()
        external
    {
        // it should be able to unverify
        changePrank(actor.admin);
        coreProxy.verifyChannel(actor.bob_channel_owner);
        changePrank(actor.bob_channel_owner);
        coreProxy.verifyChannel(actor.alice_channel_owner);

        uint8 aliceVerification = coreProxy.getChannelVerfication(
            actor.alice_channel_owner
        );
        assertEq(aliceVerification, 2);

        changePrank(actor.bob_channel_owner);
        coreProxy.unverifyChannel(actor.alice_channel_owner);

        uint8 aliceVerificationAfter = coreProxy.getChannelVerfication(
            actor.alice_channel_owner
        );
        assertEq(aliceVerificationAfter, 0);
    }

    function test_RevertWhen_AChannelUnverifiesASecondaryVerifiedChannelVerifiedByAnotherChannel()
        external
    {
        // it should REVERT
        changePrank(actor.admin);
        coreProxy.verifyChannel(actor.bob_channel_owner);
        changePrank(actor.admin);
        coreProxy.verifyChannel(actor.charlie_channel_owner);

        changePrank(actor.bob_channel_owner);
        coreProxy.verifyChannel(actor.alice_channel_owner);

        uint8 aliceVerification = coreProxy.getChannelVerfication(
            actor.alice_channel_owner
        );
        assertEq(aliceVerification, 2);

        vm.expectRevert(Errors.CallerNotAdmin.selector);
        changePrank(actor.charlie_channel_owner);
        coreProxy.unverifyChannel(actor.alice_channel_owner);

        uint8 aliceVerificationAfter = coreProxy.getChannelVerfication(
            actor.alice_channel_owner
        );
        assertEq(aliceVerificationAfter, 2);
    }

    function test_WhenASecondaryVerifiedChannelVerifiesAnotherChannel()
        external
    {
        // it should give secondary verification to that channel
        changePrank(actor.admin);
        coreProxy.verifyChannel(actor.bob_channel_owner);

        changePrank(actor.bob_channel_owner);
        coreProxy.verifyChannel(actor.charlie_channel_owner);

        changePrank(actor.charlie_channel_owner);
        coreProxy.verifyChannel(actor.alice_channel_owner);

        uint8 aliceVerification = coreProxy.getChannelVerfication(
            actor.alice_channel_owner
        );
        assertEq(aliceVerification, 2);
    }

    function test_WhenASecondaryVerifiedChannelUnverifiesAnotherSecondaryChannelVerifiedByItself()
        external
    {
        // it should unverify those channels
        changePrank(actor.admin);
        coreProxy.verifyChannel(actor.bob_channel_owner);

        changePrank(actor.bob_channel_owner);
        coreProxy.verifyChannel(actor.charlie_channel_owner);

        changePrank(actor.charlie_channel_owner);
        coreProxy.verifyChannel(actor.alice_channel_owner);

        uint8 aliceVerification = coreProxy.getChannelVerfication(
            actor.alice_channel_owner
        );
        assertEq(aliceVerification, 2);

        changePrank(actor.charlie_channel_owner);
        coreProxy.unverifyChannel(actor.alice_channel_owner);

        uint8 aliceVerificationAfter = coreProxy.getChannelVerfication(
            actor.alice_channel_owner
        );
        assertEq(aliceVerificationAfter, 0);
    }

    function test_WhenASecondaryVerifiedChannelGetsUnverifed() external {
        // it should unverify any other secondary verified channel that is verified by this channel
        changePrank(actor.admin);
        coreProxy.verifyChannel(actor.bob_channel_owner);

        changePrank(actor.bob_channel_owner);
        coreProxy.verifyChannel(actor.charlie_channel_owner);

        changePrank(actor.charlie_channel_owner);
        coreProxy.verifyChannel(actor.alice_channel_owner);

        uint8 aliceVerification = coreProxy.getChannelVerfication(
            actor.alice_channel_owner
        );
        assertEq(aliceVerification, 2);

        changePrank(actor.bob_channel_owner);
        coreProxy.unverifyChannel(actor.charlie_channel_owner);

        uint8 charlieVerificationAfter = coreProxy.getChannelVerfication(
            actor.charlie_channel_owner
        );
        uint8 aliceVerificationAfter = coreProxy.getChannelVerfication(
            actor.alice_channel_owner
        );

        assertEq(charlieVerificationAfter, 0,"charlie");
        assertEq(aliceVerificationAfter, 0,"alice");
    }

    function test_WhenAdminUnverifiesAnyChannelPrimaryOrSecondary() external {
        // it should unverify all of them as well as any secondary channel verified by those channels
        changePrank(actor.admin);
        coreProxy.verifyChannel(actor.bob_channel_owner);

        changePrank(actor.bob_channel_owner);
        coreProxy.verifyChannel(actor.charlie_channel_owner);

        changePrank(actor.charlie_channel_owner);
        coreProxy.verifyChannel(actor.alice_channel_owner);

        uint8 aliceVerification = coreProxy.getChannelVerfication(
            actor.alice_channel_owner
        );
        assertEq(aliceVerification, 2);

        changePrank(actor.admin);
        coreProxy.unverifyChannel(actor.bob_channel_owner);

        uint8 bobVerificationAfter = coreProxy.getChannelVerfication(
            actor.bob_channel_owner
        );
        uint8 charlieVerificationAfter = coreProxy.getChannelVerfication(
            actor.charlie_channel_owner
        );
        uint8 aliceVerificationAfter = coreProxy.getChannelVerfication(
            actor.alice_channel_owner
        );

        assertEq(charlieVerificationAfter, 0,"charlie");
        assertEq(aliceVerificationAfter, 0,"alice");
        assertEq(bobVerificationAfter, 0,"bob");
    }

    function test_RevertWhen_Non_adminCallsBatchVerification() external {
        // it should REVERT- not allowing anyone other than Admin
        address[] memory _channels = new address[](2);
        _channels[0] = actor.charlie_channel_owner;
        _channels[1] = actor.alice_channel_owner;

        vm.expectRevert(Errors.CallerNotAdmin.selector);
        changePrank(actor.bob_channel_owner);
        coreProxy.batchVerification(0, 2, _channels);
        uint8 charlieVerificationAfter = coreProxy.getChannelVerfication(
            actor.charlie_channel_owner
        );
        uint8 aliceVerificationAfter = coreProxy.getChannelVerfication(
            actor.alice_channel_owner
        );

        assertEq(charlieVerificationAfter, 0,"charlie");
        assertEq(aliceVerificationAfter, 0,"alice");
    }

    function test_WhenAdminCallsBatchVerification() external {
        // it should execute and set the verifications to primary
        address[] memory _channels = new address[](3);
        _channels[0] = actor.charlie_channel_owner;
        _channels[1] = actor.bob_channel_owner;
        _channels[2] = actor.alice_channel_owner;

        changePrank(actor.admin);
        coreProxy.batchVerification(0, 3, _channels);

        uint8 charlieVerificationAfter = coreProxy.getChannelVerfication(
            actor.charlie_channel_owner
        );
        uint8 aliceVerificationAfter = coreProxy.getChannelVerfication(
            actor.alice_channel_owner
        );
        uint8 bobVerificationAfter = coreProxy.getChannelVerfication(
            actor.bob_channel_owner
        );

        assertEq(charlieVerificationAfter, 1, "charlie");
        assertEq(aliceVerificationAfter, 1, "alice");
        assertEq(bobVerificationAfter, 1, "bob");
    }
}
