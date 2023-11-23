pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {BasePushChannelStateCycle} from "../BasePushChannelStateCycle.t.sol";
import {PushCoreStorageV1_5} from "contracts/PushCore/PushCoreStorageV1_5.sol";

contract ReactivateChannel_Test is BasePushChannelStateCycle {
    function setUp() public virtual override {
        BasePushChannelStateCycle.setUp();
    }

    modifier whenNotPaused() {
        _;
    }

    function test_Revertwhen_PushAllowanceNotEnough() public whenNotPaused {
        uint256 _amountBeingTransferred = 10 ether;
        approveTokens(
            actor.bob_channel_owner,
            address(coreProxy),
            _amountBeingTransferred
        );

        vm.startPrank(actor.bob_channel_owner);
        vm.expectRevert(
            bytes("PushCoreV2::reactivateChannel: Insufficient Funds")
        );
        coreProxy.reactivateChannel(_amountBeingTransferred);
        vm.stopPrank();
    }

    function test_Revertwhen_ChannelAlreadyActive() public whenNotPaused {
        approveTokens(
            actor.bob_channel_owner,
            address(coreProxy),
            ADD_CHANNEL_MIN_FEES
        );

        vm.prank(actor.bob_channel_owner);
        vm.expectRevert(
            bytes("PushCoreV2::onlyDeactivatedChannels: Channel is Active")
        );
        coreProxy.reactivateChannel(ADD_CHANNEL_MIN_FEES);
    }

    function test_Revertwhen_ReactivatingBlockedChannel() public whenNotPaused {
        approveTokens(
            actor.bob_channel_owner,
            address(coreProxy),
            ADD_CHANNEL_MIN_FEES
        );

        vm.prank(actor.admin);
        coreProxy.blockChannel(actor.bob_channel_owner);

        vm.prank(actor.bob_channel_owner);
        vm.expectRevert(
            bytes("PushCoreV2::onlyDeactivatedChannels: Channel is Active")
        );
        coreProxy.reactivateChannel(ADD_CHANNEL_MIN_FEES);
    }

    function test_ReactivatingDeactivatedChannel() public whenNotPaused {
        approveTokens(
            actor.bob_channel_owner,
            address(coreProxy),
            ADD_CHANNEL_MIN_FEES
        );

        vm.startPrank(actor.bob_channel_owner);
        coreProxy.deactivateChannel();

        vm.expectEmit(true, true, false, false, address(coreProxy));
        emit ReactivateChannel(actor.bob_channel_owner, ADD_CHANNEL_MIN_FEES);

        coreProxy.reactivateChannel(ADD_CHANNEL_MIN_FEES);

        vm.stopPrank();
    }

    function test_ChannelStateUpdation() public whenNotPaused {
        approveTokens(
            actor.bob_channel_owner,
            address(coreProxy),
            ADD_CHANNEL_MIN_FEES
        );

        uint8 actualChannelStateBeforeDeactivation = _getChannelState(
            actor.bob_channel_owner
        );

        vm.startPrank(actor.bob_channel_owner);
        coreProxy.deactivateChannel();
        uint8 actualChannelStateAfterDeactivation = _getChannelState(
            actor.bob_channel_owner
        );

        coreProxy.reactivateChannel(ADD_CHANNEL_MIN_FEES);
        uint8 actualChannelStateAfterReactivation = _getChannelState(
            actor.bob_channel_owner
        );

        uint8 expectedChannelStateBeforeDeactivation = 1;
        uint8 expectedChannelStateAfterDeactivation = 2;
        uint8 expectedChannelStateAfterReactivation = 1;

        assertEq(
            actualChannelStateBeforeDeactivation,
            expectedChannelStateBeforeDeactivation
        );
        assertEq(
            actualChannelStateAfterDeactivation,
            expectedChannelStateAfterDeactivation
        );
        assertEq(
            actualChannelStateAfterReactivation,
            expectedChannelStateAfterReactivation
        );

        vm.stopPrank();
    }

    function test_FundsVariablesUpdation() public whenNotPaused {
        approveTokens(
            actor.bob_channel_owner,
            address(coreProxy),
            ADD_CHANNEL_MIN_FEES
        );

        vm.startPrank(actor.bob_channel_owner);
        coreProxy.deactivateChannel();

        coreProxy.reactivateChannel(ADD_CHANNEL_MIN_FEES);
        uint256 actualChannelFundsAfterReactivation = coreProxy.CHANNEL_POOL_FUNDS();
        uint256 actualPoolFeesAfterReactivation = coreProxy.PROTOCOL_POOL_FEES();
        uint256 actualChannelWeightAfterReactivation = _getChannelWeight(
            actor.bob_channel_owner
        );
        uint256 actualChannelPoolContributionAfterReactivation = _getChannelPoolContribution(
                actor.bob_channel_owner
            );

        uint256 expectedChannelFundsAfterReactivation = ADD_CHANNEL_MIN_FEES -
            FEE_AMOUNT +
            MIN_POOL_CONTRIBUTION;
        uint256 expectedPoolFeesAfterReactivation = FEE_AMOUNT * 2;
        uint256 expectedChannelPoolContributionAfterReactivation = MIN_POOL_CONTRIBUTION +
                ADD_CHANNEL_MIN_FEES -
                FEE_AMOUNT;
        uint256 expectedChannelWeightAfterReactivation = (expectedChannelPoolContributionAfterReactivation *
                ADJUST_FOR_FLOAT) / (MIN_POOL_CONTRIBUTION);

        assertEq(
            actualChannelFundsAfterReactivation,
            expectedChannelFundsAfterReactivation
        );
        assertEq(
            actualPoolFeesAfterReactivation,
            expectedPoolFeesAfterReactivation
        );
        assertEq(
            actualChannelWeightAfterReactivation,
            expectedChannelWeightAfterReactivation
        );
        assertEq(
            actualChannelPoolContributionAfterReactivation,
            expectedChannelPoolContributionAfterReactivation
        );

        vm.stopPrank();
    }
}
