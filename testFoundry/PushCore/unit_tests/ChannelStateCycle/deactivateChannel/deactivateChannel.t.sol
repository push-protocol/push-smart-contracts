pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {BasePushChannelStateCycle} from "../BasePushChannelStateCycle.t.sol";
import {PushCoreStorageV1_5} from "contracts/PushCore/PushCoreStorageV1_5.sol";

contract DeactivateChannel_Test is BasePushChannelStateCycle {
    function setUp() public virtual override {
        BasePushChannelStateCycle.setUp();
    }

    modifier whenNotPaused() {
        _;
    }

    function test_Revertwhen_ChannelAlreadyDeactive() public whenNotPaused {
        vm.startPrank(actor.bob_channel_owner);
        core.deactivateChannel();

        vm.expectRevert(
            bytes("PushCoreV2::onlyActivatedChannels: Invalid Channel")
        );
        core.deactivateChannel();
        vm.stopPrank();
    }

    function test_Revertwhen_DeactivatingBlockedChannel() public whenNotPaused {
        vm.prank(actor.admin);
        core.blockChannel(actor.bob_channel_owner);

        vm.prank(actor.bob_channel_owner);
        vm.expectRevert(
            bytes("PushCoreV2::onlyActivatedChannels: Invalid Channel")
        );
        core.deactivateChannel();
    }

    function test_DeactivateChannel() public whenNotPaused {
        vm.startPrank(actor.bob_channel_owner);

        uint256 expectedRefundAmount = ADD_CHANNEL_MIN_FEES -
            FEE_AMOUNT -
            MIN_POOL_CONTRIBUTION;
        vm.expectEmit(true, true, false, false, address(core));
        emit DeactivateChannel(actor.bob_channel_owner, expectedRefundAmount);

        core.deactivateChannel();

        vm.stopPrank();
    }

    function test_UserShouldReceiveCorrectRefund() public whenNotPaused {
        vm.startPrank(actor.bob_channel_owner);

        uint256 userPushBalanceBeforeDeactivation = pushToken.balanceOf(
            actor.bob_channel_owner
        );

        uint256 expectedRefundAmount = ADD_CHANNEL_MIN_FEES -
            FEE_AMOUNT -
            MIN_POOL_CONTRIBUTION;
        core.deactivateChannel();

        uint256 userPushBalanceAfterDeactivation = pushToken.balanceOf(
            actor.bob_channel_owner
        );
        uint256 expectedUserBalance = userPushBalanceBeforeDeactivation +
            expectedRefundAmount;

        assertEq(userPushBalanceAfterDeactivation, expectedUserBalance);

        vm.stopPrank();
    }

    function test_ChannelStateUpdation() public whenNotPaused {
        vm.startPrank(actor.bob_channel_owner);
        core.deactivateChannel();
        uint8 actualChannelStateAfterDeactivation = _getChannelState(
            actor.bob_channel_owner
        );

        uint8 expectedChannelStateAfterDeactivation = 2;

        assertEq(
            actualChannelStateAfterDeactivation,
            expectedChannelStateAfterDeactivation
        );
        vm.stopPrank();
    }

    function test_FundsVariablesUpdation() public whenNotPaused {
        vm.startPrank(actor.bob_channel_owner);
        uint256 actualPoolFeesBeforeDeactivation = core.PROTOCOL_POOL_FEES();

        uint256 expectedRefundAmount = ADD_CHANNEL_MIN_FEES -
            FEE_AMOUNT -
            MIN_POOL_CONTRIBUTION;
        core.deactivateChannel();

        uint256 actualChannelFundsAfterDeactivation = core.CHANNEL_POOL_FUNDS();
        uint256 actualPoolFeesAfterDeactivation = core.PROTOCOL_POOL_FEES();
        uint256 actualChannelWeightAfterDeactivation = _getChannelWeight(
            actor.bob_channel_owner
        );
        uint256 actualChannelPoolContributionAfterDeactivation = _getChannelPoolContribution(
                actor.bob_channel_owner
            );

        uint256 expectedChannelFundsAfterDeactivation = ADD_CHANNEL_MIN_FEES -
            FEE_AMOUNT -
            expectedRefundAmount;
        uint256 expectedPoolFeesAfterDeactivation = actualPoolFeesBeforeDeactivation;
        uint256 expectedChannelPoolContributionAfterDeactivation = MIN_POOL_CONTRIBUTION;
        uint256 expectedChannelWeightAfterDeactivation = (MIN_POOL_CONTRIBUTION *
                ADJUST_FOR_FLOAT) / (MIN_POOL_CONTRIBUTION);

        assertEq(
            actualChannelFundsAfterDeactivation,
            expectedChannelFundsAfterDeactivation
        );
        assertEq(
            actualPoolFeesAfterDeactivation,
            expectedPoolFeesAfterDeactivation
        );
        assertEq(
            actualChannelWeightAfterDeactivation,
            expectedChannelWeightAfterDeactivation
        );
        assertEq(
            actualChannelPoolContributionAfterDeactivation,
            expectedChannelPoolContributionAfterDeactivation
        );

        vm.stopPrank();
    }
}
