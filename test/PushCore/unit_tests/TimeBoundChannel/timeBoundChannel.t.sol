pragma solidity ^0.8.20;

import { BasePushCoreTest } from "../BasePushCoreTest.t.sol";
import { CoreTypes } from "../../../../contracts/libraries/DataTypes.sol";
import { Errors } from "contracts/libraries/Errors.sol";

contract TimeBoundChannel_Test is BasePushCoreTest {
    function setUp() public virtual override {
        BasePushCoreTest.setUp();
    }

    function _getFutureTime(uint256 futureTime) internal view returns (uint256 time) {
        time = block.timestamp + futureTime;
    }

    function _createTimeBoundChannel(address from, uint256 expiryTime) internal {
        vm.prank(from);
        coreProxy.createChannelWithPUSH(
            CoreTypes.ChannelType.TimeBound, _testChannelIdentity, ADD_CHANNEL_MIN_FEES, expiryTime
        );
    }

    modifier whenNotPaused() {
        _;
    }

    function test_Revertwhen_ExpiryTimeInPast() public whenNotPaused {
        uint256 expiryTime = block.timestamp - 1 days;

        vm.expectRevert(abi.encodeWithSelector(Errors.Core_InvalidExpiryTime.selector));
        _createTimeBoundChannel(actor.bob_channel_owner, expiryTime);
    }

    function test_CreateTimeBoundChannel() public whenNotPaused {
        _createTimeBoundChannel(actor.bob_channel_owner, _getFutureTime(1 days));
    }

    function test_ShouldUpdateVariables() public whenNotPaused {
        uint256 expiryTime = _getFutureTime(1 days);
        _createTimeBoundChannel(actor.bob_channel_owner, expiryTime);

        uint256 expectedExpiryTime = expiryTime;
        uint256 actualExpiryTime = _getChannelExpiryTime(actor.bob_channel_owner);
        assertEq(expectedExpiryTime, actualExpiryTime);
    }

    // function test_Revertwhen_DestroyNotTimeBoundChannel() public whenNotPaused {
    //     _createChannel(actor.bob_channel_owner);

    //     vm.expectRevert(abi.encodeWithSelector(Errors.Core_InvalidChannelType.selector));

    //     vm.prank(actor.bob_channel_owner);
    //     coreProxy.updateChannelState(0);
    // }

    function test_Revertwhen_DestroyByOtherAfterExpiry() public whenNotPaused {
        _createTimeBoundChannel(actor.bob_channel_owner, _getFutureTime(1 days));

        skip(2 days);

        vm.expectRevert(abi.encodeWithSelector(Errors.Core_InvalidChannel.selector));

        vm.prank(actor.charlie_channel_owner);
        coreProxy.updateChannelState(0);
    }

    function test_Revertwhen_DestroyByOtherBeforeExpiry() public whenNotPaused {
        _createTimeBoundChannel(actor.bob_channel_owner, _getFutureTime(2 days));

        skip(1 days);

        vm.expectRevert(abi.encodeWithSelector(Errors.Core_InvalidChannel.selector));

        vm.prank(actor.charlie_channel_owner);
        coreProxy.updateChannelState(0);
    }

    function test_Revertwhen_DestroyByOwnerBeforeExpiry() public whenNotPaused {
        _createTimeBoundChannel(actor.bob_channel_owner, _getFutureTime(2 days));

        skip(1 days);

        vm.expectRevert(abi.encodeWithSelector(Errors.Core_InvalidChannel.selector));

        vm.prank(actor.bob_channel_owner);
        coreProxy.updateChannelState(0);
    }

    // function test_Revertwhen_DestroyByAdminBeforeExpiry() public whenNotPaused {
    //     _createTimeBoundChannel(actor.bob_channel_owner, _getFutureTime(2 days));

    //     skip(1 days);

    //     vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedCaller.selector, actor.admin));

    //     vm.prank(actor.bob_channel_owner);
    //     coreProxy.updateChannelState(0);
    // }

    // function test_Revertwhen_DestroyByAdminAfterExpiryBefore14Days() public whenNotPaused {
    //     _createTimeBoundChannel(actor.bob_channel_owner, _getFutureTime(1 days));

    //     skip(2 days);

    //     vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedCaller.selector, actor.admin));

    //     vm.prank(actor.bob_channel_owner);
    //     coreProxy.updateChannelState(0);
    // }

    // function test_Revertwhen_DestroyByAdminAfterExpiryEqualTo14Days() public whenNotPaused {
    //     _createTimeBoundChannel(actor.bob_channel_owner, _getFutureTime(1 days));

    //     skip(15 days);

    //     vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedCaller.selector, actor.admin));

    //     vm.prank(actor.bob_channel_owner);
    //     coreProxy.updateChannelState(0);
    // }

    function test_Revert_when_DestroyByOwnerAtExpiry() public whenNotPaused {
        _createTimeBoundChannel(actor.bob_channel_owner, _getFutureTime(1 days));

        skip(1 days);

        vm.expectRevert(abi.encodeWithSelector(Errors.Core_InvalidChannel.selector));

        vm.prank(actor.bob_channel_owner);
        coreProxy.updateChannelState(0);
    }

    function test_DestroyByOwnerAfterExpiry() public whenNotPaused {
        _createTimeBoundChannel(actor.bob_channel_owner, _getFutureTime(1 days));

        skip(1 days + 1 seconds);

        uint256 actualPoolContribution = _getChannelPoolContribution(actor.bob_channel_owner);

        emit ChannelStateUpdate(actor.bob_channel_owner, actualPoolContribution,0);

        vm.prank(actor.bob_channel_owner);
        coreProxy.updateChannelState(0);
    }
    // Admin can't perform this in the updated function
    // function test_DestroyByAdminAfterExpiryAfter14Days() public whenNotPaused {
    //     _createTimeBoundChannel(actor.bob_channel_owner, _getFutureTime(1 days));

    //     skip(15 days + 1 seconds);

    //     uint256 actualPoolContribution = _getChannelPoolContribution(actor.bob_channel_owner);

    //     emit TimeBoundChannelDestroyed(actor.admin, actualPoolContribution);

    //     vm.prank(actor.bob_channel_owner);
    //     coreProxy.updateChannelState(0);
    // }

    // function test_VariablesUpdationAfterDestroyedByAdmin() public whenNotPaused {
    //     _createTimeBoundChannel(actor.bob_channel_owner, _getFutureTime(1 days));

    //     skip(15 days + 1 seconds);

    //     uint256 poolContributionBeforeDestroyed = _getChannelPoolContribution(actor.bob_channel_owner);
    //     uint256 channelsCountBeforeDestroyed = coreProxy.channelsCount();
    //     uint256 channelPoolFundsBeforeDestroyed = coreProxy.CHANNEL_POOL_FUNDS();
    //     uint256 protocolPoolFeesBeforeDestroyed = coreProxy.PROTOCOL_POOL_FEES();

    //     vm.prank(actor.bob_channel_owner);
    //     coreProxy.updateChannelState(0);

    //     uint256 actualChannelsCountAfterDestroyed = coreProxy.channelsCount();
    //     uint256 actualChannelPoolFundsAfterDestroyed = coreProxy.CHANNEL_POOL_FUNDS();
    //     uint256 actualProtocolPoolFeesAfterDestroyed = coreProxy.PROTOCOL_POOL_FEES();
    //     uint256 expectedChannelsCountAfterDestroyed = channelsCountBeforeDestroyed - 1;
    //     uint256 expectedChannelPoolFundsAfterDestroyed =
    //         channelPoolFundsBeforeDestroyed - poolContributionBeforeDestroyed;
    //     uint256 expectedProtocolPoolFeesAfterDestroyed =
    //         protocolPoolFeesBeforeDestroyed + poolContributionBeforeDestroyed;

    //     assertEq(expectedChannelsCountAfterDestroyed, actualChannelsCountAfterDestroyed);
    //     assertEq(expectedChannelPoolFundsAfterDestroyed, actualChannelPoolFundsAfterDestroyed);
    //     assertEq(expectedProtocolPoolFeesAfterDestroyed, actualProtocolPoolFeesAfterDestroyed);
    // }

    function test_VariablesUpdationAfterDestroyedByOwner() public whenNotPaused {
        _createTimeBoundChannel(actor.bob_channel_owner, _getFutureTime(1 days));

        skip(1 days + 1 seconds);

        uint256 poolContributionBeforeDestroyed = _getChannelPoolContribution(actor.bob_channel_owner);
        uint256 channelsCountBeforeDestroyed = coreProxy.channelsCount();
        uint256 channelPoolFundsBeforeDestroyed = coreProxy.CHANNEL_POOL_FUNDS();
        uint256 protocolPoolFeesBeforeDestroyed = coreProxy.PROTOCOL_POOL_FEES();

        vm.prank(actor.bob_channel_owner);
        coreProxy.updateChannelState(0);

        uint256 actualChannelsCountAfterDestroyed = coreProxy.channelsCount();
        uint256 actualChannelPoolFundsAfterDestroyed = coreProxy.CHANNEL_POOL_FUNDS();
        uint256 actualProtocolPoolFeesAfterDestroyed = coreProxy.PROTOCOL_POOL_FEES();
        uint256 expectedChannelsCountAfterDestroyed = channelsCountBeforeDestroyed - 1;
        uint256 expectedChannelPoolFundsAfterDestroyed =
            channelPoolFundsBeforeDestroyed - poolContributionBeforeDestroyed;
        uint256 expectedProtocolPoolFeesAfterDestroyed = protocolPoolFeesBeforeDestroyed;

        assertEq(expectedChannelsCountAfterDestroyed, actualChannelsCountAfterDestroyed);
        assertEq(expectedChannelPoolFundsAfterDestroyed, actualChannelPoolFundsAfterDestroyed);
        assertEq(expectedProtocolPoolFeesAfterDestroyed, actualProtocolPoolFeesAfterDestroyed);
    }

    function test_ShouldRefundAfterDestroyedByOwner() public whenNotPaused {
        _createTimeBoundChannel(actor.bob_channel_owner, _getFutureTime(1 days));

        skip(1 days + 1 seconds);
        uint256 pushTokenBalanceOfOwnerBeforeDestroying = pushToken.balanceOf(actor.bob_channel_owner);
        uint256 poolContributionBeforeDestroyed = _getChannelPoolContribution(actor.bob_channel_owner);

        vm.prank(actor.bob_channel_owner);
        coreProxy.updateChannelState(0);

        uint256 actualPushTokenBalanceOfOwnerAfterDestroying = pushToken.balanceOf(actor.bob_channel_owner);
        uint256 expectedPushTokenBalanceOfOwnerAfterDestroying =
            pushTokenBalanceOfOwnerBeforeDestroying + poolContributionBeforeDestroyed;

        assertEq(expectedPushTokenBalanceOfOwnerAfterDestroying, actualPushTokenBalanceOfOwnerAfterDestroying);
    }

    // function test_ShouldNotRefundAfterDestroyedByAdmin() public whenNotPaused {
    //     _createTimeBoundChannel(actor.bob_channel_owner, _getFutureTime(1 days));

    //     skip(15 days + 1 seconds);
    //     uint256 pushTokenBalanceOfOwnerBeforeDestroying = pushToken.balanceOf(actor.bob_channel_owner);
    //     uint256 pushTokenBalanceOfAdminBeforeDestroying = pushToken.balanceOf(actor.admin);

    //     vm.prank(actor.bob_channel_owner);
    //     coreProxy.updateChannelState(0);

    //     uint256 actualPushTokenBalanceOfOwnerAfterDestroying = pushToken.balanceOf(actor.bob_channel_owner);
    //     uint256 expectedPushTokenBalanceOfOwnerAfterDestroying = pushTokenBalanceOfOwnerBeforeDestroying;
    //     uint256 actualPushTokenBalanceOfAdminAfterDestroying = pushToken.balanceOf(actor.admin);
    //     uint256 expectedPushTokenBalanceOfAdminAfterDestroying = pushTokenBalanceOfAdminBeforeDestroying;

    //     assertEq(expectedPushTokenBalanceOfOwnerAfterDestroying, actualPushTokenBalanceOfOwnerAfterDestroying);
    //     assertEq(expectedPushTokenBalanceOfAdminAfterDestroying, actualPushTokenBalanceOfAdminAfterDestroying);
    // }

    function test_ShouldDeleteDataAfterDestroyed() public whenNotPaused {
        _createTimeBoundChannel(actor.bob_channel_owner, _getFutureTime(1 days));

        skip(1 days + 1 seconds);

        vm.prank(actor.bob_channel_owner);
        coreProxy.updateChannelState(0);

        (
            CoreTypes.ChannelType channelTypeAfterChannelDestroyed,
            uint8 channelStateAfterChannelDestroyed,
            address verifiedByAfterChannelDestroyed,
            uint256 poolContributionAfterChannelDestroyed,
            uint256 channelHistoricalZAfterChannelDestroyed,
            uint256 channelFairShareCountAfterChannelDestroyed,
            uint256 channelLastUpdateAfterChannelDestroyed,
            uint256 channelStartBlockAfterChannelDestroyed,
            uint256 channelUpdateBlockAfterChannelDestroyed,
            uint256 channelWeightAfterChannelDestroyed,
            uint256 expiryTimeAfterChannelDestroyed
        ) = coreProxy.channels(actor.bob_channel_owner);

        assertEq(channelTypeAfterChannelDestroyed == CoreTypes.ChannelType.ProtocolNonInterest, true);
        assertEq(channelStateAfterChannelDestroyed, 0);
        assertEq(verifiedByAfterChannelDestroyed, address(0x0));
        assertEq(poolContributionAfterChannelDestroyed, 0);
        assertEq(channelHistoricalZAfterChannelDestroyed, 0);
        assertEq(channelFairShareCountAfterChannelDestroyed, 0);
        assertEq(channelLastUpdateAfterChannelDestroyed, 0);
        assertEq(channelStartBlockAfterChannelDestroyed, 0);
        assertEq(channelUpdateBlockAfterChannelDestroyed, 0);
        assertEq(channelWeightAfterChannelDestroyed, 0);
        assertEq(expiryTimeAfterChannelDestroyed, 0);
    }

    function test_ShouldAllowChannelCreationAfterDestroying() public whenNotPaused {
        _createTimeBoundChannel(actor.bob_channel_owner, _getFutureTime(1 days));

        skip(1 days + 1 seconds);

        vm.prank(actor.bob_channel_owner);
        coreProxy.updateChannelState(0);

        _createChannel(actor.bob_channel_owner);
    }

    function test_Revertwhen_DeactivateDestroyedChannel() public whenNotPaused {
        _createTimeBoundChannel(actor.bob_channel_owner, _getFutureTime(1 days));

        skip(1 days + 1 seconds);

        vm.prank(actor.bob_channel_owner);
        coreProxy.updateChannelState(0);

        vm.expectRevert(abi.encodeWithSelector(Errors.Core_InvalidChannel.selector));

        vm.prank(actor.bob_channel_owner);
        coreProxy.updateChannelState(0);
    }

    // Auto-UnSubscription from Channels - Now Deprecated
    
    // function test_ShouldUnsubscribeAfterDestroyed() public whenNotPaused {
    //     _createTimeBoundChannel(actor.bob_channel_owner, _getFutureTime(1 days));
    //     address EPNS_ALERTER = address(0);

    //     bool isChannelSubscribedToOwn_Before =
    //         commProxy.isUserSubscribed(actor.bob_channel_owner, actor.bob_channel_owner);
    //     bool isChannelSubscribedToEPNS_Before = commProxy.isUserSubscribed(EPNS_ALERTER, actor.bob_channel_owner);
    //     bool isAdminSubscribedToChannel_Before = commProxy.isUserSubscribed(actor.bob_channel_owner, actor.admin);

    //     skip(1 days + 1 seconds);

    //     vm.prank(actor.bob_channel_owner);
    //     coreProxy.updateChannelState(0);

    //     bool isChannelSubscribedToOwn_After =
    //         commProxy.isUserSubscribed(actor.bob_channel_owner, actor.bob_channel_owner);
    //     bool isChannelSubscribedToEPNS_After = commProxy.isUserSubscribed(EPNS_ALERTER, actor.bob_channel_owner);
    //     bool isAdminSubscribedToChannel_After = commProxy.isUserSubscribed(actor.bob_channel_owner, actor.admin);

    //     assertEq(isChannelSubscribedToOwn_Before, true);
    //     assertEq(isChannelSubscribedToEPNS_Before, true);
    //     assertEq(isAdminSubscribedToChannel_Before, true);

    //     assertEq(isChannelSubscribedToOwn_After, false);
    //     assertEq(isChannelSubscribedToEPNS_After, false);
    //     assertEq(isAdminSubscribedToChannel_After, false);
    // }
}
