// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import { BasePushCoreTest } from "../../PushCore/unit_tests/BasePushCoreTest.t.sol";
import { SignatureVerifier } from "contracts/mocks/MockERC1271.sol";
import { CoreTypes } from "../../../contracts/libraries/DataTypes.sol";

contract BasePushCommTest is BasePushCoreTest {
    SignatureVerifier verifierContract;

    function setUp() public virtual override {
        BasePushCoreTest.setUp();

        changePrank(actor.tim_push_holder);
        verifierContract = new SignatureVerifier();

        changePrank(actor.bob_channel_owner);
        coreProxy.createChannelWithPUSH(CoreTypes.ChannelType.InterestBearingOpen, _testChannelIdentity, 50e18, 0);
    }

    //Helper Functions
    struct SubscribeUnsubscribe {
        address _channel;
        address _subscriber;
        uint256 nonce;
        uint256 expiry;
    }

    struct SendNotif {
        address _channel;
        address _recipient;
        bytes _identity;
        uint256 nonce;
        uint256 expiry;
    }

    // computes the hash of a sendNotif
    function getSubscribeStructHash(
        SubscribeUnsubscribe memory _subscribeUnsubscribe,
        bytes32 _typehash
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                _typehash,
                _subscribeUnsubscribe._channel,
                _subscribeUnsubscribe._subscriber,
                _subscribeUnsubscribe.nonce,
                _subscribeUnsubscribe.expiry
            )
        );
    }

    // computes the hash of a sendNotif
    function getNotifStructHash(SendNotif memory _sendNotif) internal pure returns (bytes32) {
        return keccak256(
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
        return keccak256(abi.encode(DOMAIN_TYPEHASH, NAME_HASH, block.chainid, address(commProxy)));
    }
}
