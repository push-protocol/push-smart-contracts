pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {BasePushChannelStateCycle} from "../BasePushChannelStateCycle.t.sol";
import {PushCoreStorageV1_5} from "contracts/PushCore/PushCoreStorageV1_5.sol";

contract BlockChannel_Test is BasePushChannelStateCycle {
    function setUp() public virtual override {
        BasePushChannelStateCycle.setUp();
    }

    modifier whenNotPaused() {
        _;
    }

    modifier whenCallerIsAdmin() {
        _;
    }

    function test_Revertwhen_BlockCallerNotAdmin()
        public
        whenNotPaused
        whenCallerIsAdmin
    {
        vm.expectRevert(
            bytes("PushCoreV2::onlyPushChannelAdmin: Invalid Caller")
        );

        core.blockChannel(actor.bob_channel_owner);
    }

    function test_AdminCanBlockActivatedChannel()
        public
        whenNotPaused
        whenCallerIsAdmin
    {
        vm.expectEmit(true, false, false, false, address(core));
        emit ChannelBlocked(actor.bob_channel_owner);

        vm.prank(actor.admin);
        core.blockChannel(actor.bob_channel_owner);
    }

    function test_AdminCanBlockDeactivatedChannel()
        public
        whenNotPaused
        whenCallerIsAdmin
    {
        vm.prank(actor.bob_channel_owner);
        core.deactivateChannel();

        vm.expectEmit(true, false, false, false, address(core));
        emit ChannelBlocked(actor.bob_channel_owner);

        vm.prank(actor.admin);
        core.blockChannel(actor.bob_channel_owner);
    }

    function test_Revertwhen_BlockInactiveChannel()
        public
        whenNotPaused
        whenCallerIsAdmin
    {
        vm.prank(actor.admin);
        vm.expectRevert(
            bytes("PushCoreV2::onlyUnblockedChannels: Invalid Channel")
        );
        core.blockChannel(actor.charlie_channel_owner);
    }

    function test_Revertwhen_AlreadyBlockedChannel()
        public
        whenNotPaused
        whenCallerIsAdmin
    {
        vm.startPrank(actor.admin);
        core.blockChannel(actor.bob_channel_owner);

        vm.expectRevert(
            bytes("PushCoreV2::onlyUnblockedChannels: Invalid Channel")
        );
        core.blockChannel(actor.bob_channel_owner);
        vm.stopPrank();
    }

    function test_ChannelDetailsUpdation()
        public
        whenNotPaused
        whenCallerIsAdmin
    {
        uint256 channelsCountBeforeBlocked = core.channelsCount();
        vm.prank(actor.admin);
        core.blockChannel(actor.bob_channel_owner);

        (
            ,
            uint8 actualChannelState,
            ,
            uint256 actualPoolContribution,
            ,
            ,
            ,
            ,
            uint256 actualChannelUpdateBlock,
            uint256 actualChannelWeight,

        ) = core.channels(actor.bob_channel_owner);
        uint256 actualChannelsCount = core.channelsCount();

        uint256 expectedPoolContribution = MIN_POOL_CONTRIBUTION;
        uint256 expectedChannelsCount = channelsCountBeforeBlocked - 1;
        uint8 expectedChannelState = 3;
        uint256 expectedChannelWeight = (MIN_POOL_CONTRIBUTION *
            ADJUST_FOR_FLOAT) / MIN_POOL_CONTRIBUTION;
        uint256 expectedChannelUpdateBlock = block.number;

        assertEq(actualChannelState, expectedChannelState);
        assertEq(actualPoolContribution, expectedPoolContribution);
        assertEq(actualChannelUpdateBlock, expectedChannelUpdateBlock);
        assertEq(actualChannelWeight, expectedChannelWeight);
        assertEq(actualChannelsCount, expectedChannelsCount);
    }

    function test_FundsVariablesUpdation()
        public
        whenNotPaused
        whenCallerIsAdmin
    {
        uint256 poolContributionBeforeBlocked = _getChannelPoolContribution(
            actor.bob_channel_owner
        );
        uint256 poolFeesBeforeBlocked = core.PROTOCOL_POOL_FEES();
        uint256 poolFundsBeforeBlocked = core.CHANNEL_POOL_FUNDS();

        vm.prank(actor.admin);
        core.blockChannel(actor.bob_channel_owner);
        uint256 actualChannelFundsAfterBlocked = core.CHANNEL_POOL_FUNDS();
        uint256 actualPoolFeesAfterBlocked = core.PROTOCOL_POOL_FEES();

        uint256 expectedPoolContributionAfterBlocked = poolContributionBeforeBlocked -
                MIN_POOL_CONTRIBUTION;
        uint256 expectedChannelFundsAfterBlocked = poolFundsBeforeBlocked -
            expectedPoolContributionAfterBlocked;
        uint256 expectedPoolFeesAfterBlocked = poolFeesBeforeBlocked +
            expectedPoolContributionAfterBlocked;

        assertEq(
            actualChannelFundsAfterBlocked,
            expectedChannelFundsAfterBlocked
        );
        assertEq(actualPoolFeesAfterBlocked, expectedPoolFeesAfterBlocked);
    }
}
