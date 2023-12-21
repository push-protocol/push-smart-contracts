pragma solidity ^0.8.0;
import {BaseTest} from "../../../BaseTest.t.sol";
import {PushCoreStorageV1_5} from "contracts/PushCore/PushCoreStorageV1_5.sol";
import {SignatureVerifier} from "contracts/mocks/MockERC1271.sol";
import "forge-std/console.sol";

contract SendNotifsViaSig_Test is BaseTest {
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,uint256 chainId,address verifyingContract)"
        );

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant SEND_NOTIFICATION_TYPEHASH =
        keccak256(
            "SendNotification(address channel,address recipient,bytes identity,uint256 nonce,uint256 expiry)"
        );

    bytes32 public constant NAME_HASH = keccak256(bytes("EPNS COMM V1"));

    bytes constant _testChannelIdentity = bytes("test-channel-hello-world");

    SignatureVerifier verifierContract;

    function setUp() public override {
        BaseTest.setUp();
        changePrank(actor.tim_push_holder);
        verifierContract = new SignatureVerifier();

        changePrank(actor.bob_channel_owner);
        coreProxy.createChannelWithPUSH(
            PushCoreStorageV1_5.ChannelType.InterestBearingOpen,
            _testChannelIdentity,
            50e18,
            0
        );
    }

    function test_WhenChannelSendsNotificationuUsing712Sig() external {
        // it Allows to send channel notification with 712 sig
        bytes32 DOMAIN_SEPARATOR = getDomainSeparator();

        SendNotif memory _sendNotif = SendNotif(
            actor.bob_channel_owner,
            actor.alice_channel_owner,
            _testChannelIdentity,
            commProxy.nonces(actor.bob_channel_owner),
            block.timestamp + 1000
        );
        bytes32 structHash = getStructHash(_sendNotif);
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );
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

    function test_WhenDelegateeSendsNotificationUsing712Sig() external {
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
        bytes32 structHash = getStructHash(_sendNotif);
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );
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
        bytes32 structHash = getStructHash(_sendNotif);
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );
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

    function test_WhenInvokedByAMaliciousUserUsingSignatureReplay() external {
        // it Returns false on signature replay
        bytes32 DOMAIN_SEPARATOR = getDomainSeparator();
        SendNotif memory _sendNotif = SendNotif(
            address(verifierContract),
            actor.alice_channel_owner,
            _testChannelIdentity,
            commProxy.nonces(address(verifierContract)),
            block.timestamp + 1000
        );
        bytes32 structHash = getStructHash(_sendNotif);
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );
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

    function test_WhenInvokedByAMaliciousUserUsingExpiredSignature() external {
        // it Returns false on signature expire
        bytes32 DOMAIN_SEPARATOR = getDomainSeparator();
        SendNotif memory _sendNotif = SendNotif(
            address(verifierContract),
            actor.alice_channel_owner,
            _testChannelIdentity,
            commProxy.nonces(address(verifierContract)),
            block.timestamp + 1000
        );
        bytes32 structHash = getStructHash(_sendNotif);
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );
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

    //HELPER FUNCTIONS
    struct SendNotif {
        address _channel;
        address _recipient;
        bytes _identity;
        uint nonce;
        uint expiry;
    }

    // computes the hash of a sendNotif
    function getStructHash(
        SendNotif memory _sendNotif
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    SEND_NOTIFICATION_TYPEHASH,
                    _sendNotif._channel,
                    _sendNotif._recipient,
                    keccak256(_sendNotif._identity),
                    _sendNotif.nonce,
                    _sendNotif.expiry
                )
            );
    }

    function getDomainSeparator() public returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    DOMAIN_TYPEHASH,
                    NAME_HASH,
                    block.chainid,
                    address(commProxy)
                )
            );
    }
}
