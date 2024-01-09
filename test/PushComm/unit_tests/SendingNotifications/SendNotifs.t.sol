pragma solidity ^0.8.0;

import { BaseTest } from "../../../BaseTest.t.sol";
import { CoreTypes } from "../../../../contracts/libraries/DataTypes.sol";

// import "forge-std/console.sol";
contract SendNotifs_Test is BaseTest {

    function setUp() public override {
        BaseTest.setUp();
        changePrank(actor.bob_channel_owner);
        coreProxy.createChannelWithPUSH(CoreTypes.ChannelType.InterestBearingOpen, _testChannelIdentity, 50e18, 0);
    }

    function test_WhenAUserIsSendingNotifToOtherAddressInsteadOfThemselves() external {
        changePrank(actor.charlie_channel_owner);
        bool res = commProxy.sendNotification(actor.bob_channel_owner, actor.alice_channel_owner, _testChannelIdentity);
        assertEq(res, false);
    }

    function test_WhenRecipientIsSendingNOTIFOnlyToThemselves() external {
        //User can no longer send notifs to themselves
    }

    function test_WhenChannelIs0x00ButCallerIsAnyAddressOtherThanAdminOrGovernance() external {
        changePrank(actor.charlie_channel_owner);
        bool res = commProxy.sendNotification(address(0), actor.alice_channel_owner, _testChannelIdentity);
        assertEq(res, false);
    }

    function test_WhenChannelIs0x00AndCallerIsAdminOrGovernance() external {
        changePrank(actor.admin);
        bool res = commProxy.sendNotification(address(0), actor.alice_channel_owner, _testChannelIdentity);
        assertEq(res, true);
    }

    function test_WhenDelegateSendNotificationWithoutApproval() external {
        bool isTonyDelegate = commProxy.delegatedNotificationSenders(actor.bob_channel_owner, actor.dan_push_holder);

        assertEq(isTonyDelegate, false);

        changePrank(actor.dan_push_holder);
        bool res = commProxy.sendNotification(actor.bob_channel_owner, actor.alice_channel_owner, _testChannelIdentity);
        assertEq(res, false);
    }

    function test_WhenAllowedDelagtesSendsNotificationToAnyRecipient() external {
        changePrank(actor.bob_channel_owner);
        commProxy.addDelegate(actor.dan_push_holder);
        bool isTonyDelegate = commProxy.delegatedNotificationSenders(actor.bob_channel_owner, actor.dan_push_holder);

        assertEq(isTonyDelegate, true);

        changePrank(actor.dan_push_holder);
        bool res = commProxy.sendNotification(actor.bob_channel_owner, actor.alice_channel_owner, _testChannelIdentity);
        assertEq(res, true);
    }

    function test_WhenAddDelegateItShouldBeSubscribedToChannel() external {
        changePrank(actor.bob_channel_owner);
        commProxy.addDelegate(actor.dan_push_holder);
        bool isTonyDelegate = commProxy.delegatedNotificationSenders(actor.bob_channel_owner, actor.dan_push_holder);

        assertEq(isTonyDelegate, true);

        //Check the delegate becomes a subscriber.
        bool isSub = commProxy.isUserSubscribed(actor.bob_channel_owner, actor.dan_push_holder);
        assertEq(isSub, true);
    }
}
