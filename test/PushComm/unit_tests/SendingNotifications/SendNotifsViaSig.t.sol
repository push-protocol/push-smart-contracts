pragma solidity ^0.8.0;

import { BasePushCommTest } from "../BasePushCommTest.t.sol";

contract SendNotifsViaSig_Test is BasePushCommTest {
    function setUp() public override {
        BasePushCommTest.setUp();
    }

    function test_WhenChannel_SendsNotification_Using712Sig() external {
        // it Allows to send channel notification with 712 sig
        bytes32 DOMAIN_SEPARATOR = getDomainSeparator();

        SendNotif memory _sendNotif = SendNotif(
            actor.bob_channel_owner,
            actor.alice_channel_owner,
            _testChannelIdentity,
            commProxy.nonces(actor.bob_channel_owner),
            block.timestamp + 1000
        );
        bytes32 structHash = getNotifStructHash(_sendNotif);
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeys[actor.bob_channel_owner], digest);

        bool res = commProxy.sendNotifBySig(
            actor.bob_channel_owner,
            actor.alice_channel_owner,
            actor.bob_channel_owner,
            _testChannelIdentity,
            commProxy.nonces(actor.bob_channel_owner),
            block.timestamp + 1000,
            v,
            r,
            s
        );

        assertEq(true, res);
    }

    function test_WhenDelegatee_SendsNotification_Using712Sig() external {
        // it Allows delegatee to send notification

        changePrank(actor.bob_channel_owner);
        commProxy.addDelegate(actor.charlie_channel_owner);

        bytes32 DOMAIN_SEPARATOR = getDomainSeparator();
        SendNotif memory _sendNotif = SendNotif(
            actor.bob_channel_owner,
            actor.alice_channel_owner,
            _testChannelIdentity,
            commProxy.nonces(actor.charlie_channel_owner),
            block.timestamp + 1000
        );
        bytes32 structHash = getNotifStructHash(_sendNotif);
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeys[actor.charlie_channel_owner], digest);

        bool res = commProxy.sendNotifBySig(
            actor.bob_channel_owner,
            actor.alice_channel_owner,
            actor.charlie_channel_owner,
            _testChannelIdentity,
            commProxy.nonces(actor.charlie_channel_owner),
            block.timestamp + 1000,
            v,
            r,
            s
        );

        assertEq(true, res);
    }

    function test_WhenCalledUsingA1271Sig() external {
        // it Allow to send channel notification with 1271 sig
        bytes32 DOMAIN_SEPARATOR = getDomainSeparator();
        SendNotif memory _sendNotif = SendNotif(
            address(verifierContract),
            actor.alice_channel_owner,
            _testChannelIdentity,
            commProxy.nonces(address(verifierContract)),
            block.timestamp + 1000
        );
        bytes32 structHash = getNotifStructHash(_sendNotif);
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeys[actor.tim_push_holder], digest);

        bool res = commProxy.sendNotifBySig(
            address(verifierContract),
            actor.alice_channel_owner,
            address(verifierContract),
            _testChannelIdentity,
            commProxy.nonces(address(verifierContract)),
            block.timestamp + 1000,
            v,
            r,
            s
        );

        assertEq(true, res);
    }

    function test_WhenInvokedBy_AMaliciousUser_UsingSignatureReplay() external {
        // it Returns false on signature replay
        bytes32 DOMAIN_SEPARATOR = getDomainSeparator();
        SendNotif memory _sendNotif = SendNotif(
            address(verifierContract),
            actor.alice_channel_owner,
            _testChannelIdentity,
            commProxy.nonces(address(verifierContract)),
            block.timestamp + 1000
        );
        bytes32 structHash = getNotifStructHash(_sendNotif);
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeys[actor.tim_push_holder], digest);
        //Notification already sent one time
        commProxy.sendNotifBySig(
            address(verifierContract),
            actor.alice_channel_owner,
            address(verifierContract),
            _testChannelIdentity,
            commProxy.nonces(address(verifierContract)),
            block.timestamp + 1000,
            v,
            r,
            s
        );

        //Using the same signature twice should fail
        bool res = commProxy.sendNotifBySig(
            address(verifierContract),
            actor.alice_channel_owner,
            address(verifierContract),
            _testChannelIdentity,
            commProxy.nonces(address(verifierContract)),
            block.timestamp + 1000,
            v,
            r,
            s
        );
        assertEq(false, res);
    }

    function test_WhenInvokedBy_AMaliciousUserUsing_ExpiredSignature() external {
        // it Returns false on signature expire
        bytes32 DOMAIN_SEPARATOR = getDomainSeparator();
        SendNotif memory _sendNotif = SendNotif(
            address(verifierContract),
            actor.alice_channel_owner,
            _testChannelIdentity,
            commProxy.nonces(address(verifierContract)),
            block.timestamp + 1000
        );
        bytes32 structHash = getNotifStructHash(_sendNotif);
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeys[actor.tim_push_holder], digest);

        bool res = commProxy.sendNotifBySig(
            address(verifierContract),
            actor.alice_channel_owner,
            address(verifierContract),
            _testChannelIdentity,
            commProxy.nonces(address(verifierContract)),
            block.timestamp - 1,
            v,
            r,
            s
        );

        assertEq(false, res);
    }
}
