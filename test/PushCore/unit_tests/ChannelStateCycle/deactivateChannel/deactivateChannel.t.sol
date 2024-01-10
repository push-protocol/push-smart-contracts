pragma solidity ^0.8.20;

import { BasePushCoreTest } from "../../BasePushCoreTest.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";

contract DeactivateChannel_Test is BasePushCoreTest {
    function setUp() public virtual override {
        BasePushCoreTest.setUp();

        _createChannel(actor.bob_channel_owner);
    }

    modifier whenNotPaused() {
        _;
    }

    function test_Revertwhen_ChannelAlreadyDeactive() public whenNotPaused {
        vm.startPrank(actor.bob_channel_owner);
        coreProxy.deactivateChannel();

        vm.expectRevert(Errors.Core_InvalidChannel.selector);
        coreProxy.deactivateChannel();
        vm.stopPrank();
    }

    function test_Revertwhen_DeactivatingBlockedChannel() public whenNotPaused {
        vm.prank(actor.admin);
        coreProxy.blockChannel(actor.bob_channel_owner);

        vm.prank(actor.bob_channel_owner);
        vm.expectRevert(Errors.Core_InvalidChannel.selector);
        coreProxy.deactivateChannel();
    }

    function test_DeactivateChannel() public whenNotPaused {
        vm.startPrank(actor.bob_channel_owner);

        uint256 expectedRefundAmount = ADD_CHANNEL_MIN_FEES - FEE_AMOUNT - MIN_POOL_CONTRIBUTION;
        vm.expectEmit(true, true, false, false, address(coreProxy));
        emit DeactivateChannel(actor.bob_channel_owner, expectedRefundAmount);

        coreProxy.deactivateChannel();

        vm.stopPrank();
    }

    function test_UserShouldReceiveCorrectRefund() public whenNotPaused {
        vm.startPrank(actor.bob_channel_owner);

        uint256 userPushBalanceBeforeDeactivation = pushToken.balanceOf(actor.bob_channel_owner);

        uint256 expectedRefundAmount = ADD_CHANNEL_MIN_FEES - FEE_AMOUNT - MIN_POOL_CONTRIBUTION;
        coreProxy.deactivateChannel();

        uint256 userPushBalanceAfterDeactivation = pushToken.balanceOf(actor.bob_channel_owner);
        uint256 expectedUserBalance = userPushBalanceBeforeDeactivation + expectedRefundAmount;

        assertEq(userPushBalanceAfterDeactivation, expectedUserBalance);

        vm.stopPrank();
    }

    function test_ChannelStateUpdation() public whenNotPaused {
        vm.startPrank(actor.bob_channel_owner);
        coreProxy.deactivateChannel();
        uint8 actualChannelStateAfterDeactivation = _getChannelState(actor.bob_channel_owner);

        uint8 expectedChannelStateAfterDeactivation = 2;

        assertEq(actualChannelStateAfterDeactivation, expectedChannelStateAfterDeactivation);
        vm.stopPrank();
    }

    function test_FundsVariablesUpdation() public whenNotPaused {
        vm.startPrank(actor.bob_channel_owner);
        uint256 actualPoolFeesBeforeDeactivation = coreProxy.PROTOCOL_POOL_FEES();

        uint256 expectedRefundAmount = ADD_CHANNEL_MIN_FEES - FEE_AMOUNT - MIN_POOL_CONTRIBUTION;
        coreProxy.deactivateChannel();

        uint256 actualChannelFundsAfterDeactivation = coreProxy.CHANNEL_POOL_FUNDS();
        uint256 actualPoolFeesAfterDeactivation = coreProxy.PROTOCOL_POOL_FEES();
        uint256 actualChannelWeightAfterDeactivation = _getChannelWeight(actor.bob_channel_owner);
        uint256 actualChannelPoolContributionAfterDeactivation = _getChannelPoolContribution(actor.bob_channel_owner);

        uint256 expectedChannelFundsAfterDeactivation = ADD_CHANNEL_MIN_FEES - FEE_AMOUNT - expectedRefundAmount;
        uint256 expectedPoolFeesAfterDeactivation = actualPoolFeesBeforeDeactivation;
        uint256 expectedChannelPoolContributionAfterDeactivation = MIN_POOL_CONTRIBUTION;
        uint256 expectedChannelWeightAfterDeactivation =
            (MIN_POOL_CONTRIBUTION * ADJUST_FOR_FLOAT) / (MIN_POOL_CONTRIBUTION);

        assertEq(actualChannelFundsAfterDeactivation, expectedChannelFundsAfterDeactivation);
        assertEq(actualPoolFeesAfterDeactivation, expectedPoolFeesAfterDeactivation);
        assertEq(actualChannelWeightAfterDeactivation, expectedChannelWeightAfterDeactivation);
        assertEq(actualChannelPoolContributionAfterDeactivation, expectedChannelPoolContributionAfterDeactivation);

        vm.stopPrank();
    }
}
