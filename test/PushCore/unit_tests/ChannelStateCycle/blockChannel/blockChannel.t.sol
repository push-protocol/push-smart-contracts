pragma solidity ^0.8.20;

import { BasePushCoreTest } from "../../BasePushCoreTest.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";

contract BlockChannel_Test is BasePushCoreTest {
    function setUp() public virtual override {
        BasePushCoreTest.setUp();

        _createChannel(actor.bob_channel_owner);
    }

    modifier whenNotPaused() {
        _;
    }

    modifier whenCallerIsAdmin() {
        _;
    }

    function test_Revertwhen_BlockCallerNotGovernance() public whenNotPaused whenCallerIsAdmin {
        vm.expectRevert(Errors.CallerNotGovernance.selector);

        coreProxy.blockChannel(actor.bob_channel_owner);
    }

    function test_AdminCanBlockActivatedChannel() public whenNotPaused whenCallerIsAdmin {
        vm.expectEmit(true, false, false, false, address(coreProxy));
        emit ChannelBlocked(actor.bob_channel_owner);

        vm.prank(actor.admin);
        coreProxy.blockChannel(actor.bob_channel_owner);
    }

    function test_AdminCanBlockDeactivatedChannel() public whenNotPaused whenCallerIsAdmin {
        vm.prank(actor.bob_channel_owner);
        coreProxy.updateChannelState(0);

        vm.expectEmit(true, false, false, false, address(coreProxy));
        emit ChannelBlocked(actor.bob_channel_owner);

        vm.prank(actor.admin);
        coreProxy.blockChannel(actor.bob_channel_owner);
    }

    function test_Revertwhen_BlockInactiveChannel() public whenNotPaused whenCallerIsAdmin {
        vm.prank(actor.admin);
        vm.expectRevert(Errors.Core_InvalidChannel.selector);
        coreProxy.blockChannel(actor.charlie_channel_owner);
    }

    function test_Revertwhen_AlreadyBlockedChannel() public whenNotPaused whenCallerIsAdmin {
        vm.startPrank(actor.admin);
        coreProxy.blockChannel(actor.bob_channel_owner);

        vm.expectRevert(Errors.Core_InvalidChannel.selector);
        coreProxy.blockChannel(actor.bob_channel_owner);
        vm.stopPrank();
    }

    function test_ChannelDetailsUpdation() public whenNotPaused whenCallerIsAdmin {
        uint256 channelsCountBeforeBlocked = coreProxy.channelsCount();
        vm.prank(actor.admin);
        coreProxy.blockChannel(actor.bob_channel_owner);

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
        ) = coreProxy.channels(actor.bob_channel_owner);
        uint256 actualChannelsCount = coreProxy.channelsCount();

        uint256 expectedPoolContribution = MIN_POOL_CONTRIBUTION;
        uint256 expectedChannelsCount = channelsCountBeforeBlocked - 1;
        uint8 expectedChannelState = 3;
        uint256 expectedChannelWeight = (MIN_POOL_CONTRIBUTION * ADJUST_FOR_FLOAT) / MIN_POOL_CONTRIBUTION;
        uint256 expectedChannelUpdateBlock = block.number;

        assertEq(actualChannelState, expectedChannelState);
        assertEq(actualPoolContribution, expectedPoolContribution);
        assertEq(actualChannelUpdateBlock, expectedChannelUpdateBlock);
        assertEq(actualChannelWeight, expectedChannelWeight);
        assertEq(actualChannelsCount, expectedChannelsCount);
    }

    function test_FundsVariablesUpdation() public whenNotPaused whenCallerIsAdmin {
        uint256 poolContributionBeforeBlocked = _getChannelPoolContribution(actor.bob_channel_owner);
        uint256 poolFeesBeforeBlocked = coreProxy.PROTOCOL_POOL_FEES();
        uint256 poolFundsBeforeBlocked = coreProxy.CHANNEL_POOL_FUNDS();

        vm.prank(actor.admin);
        coreProxy.blockChannel(actor.bob_channel_owner);
        uint256 actualChannelFundsAfterBlocked = coreProxy.CHANNEL_POOL_FUNDS();
        uint256 actualPoolFeesAfterBlocked = coreProxy.PROTOCOL_POOL_FEES();

        uint256 expectedPoolContributionAfterBlocked = poolContributionBeforeBlocked - MIN_POOL_CONTRIBUTION;
        uint256 expectedChannelFundsAfterBlocked = poolFundsBeforeBlocked - expectedPoolContributionAfterBlocked;
        uint256 expectedPoolFeesAfterBlocked = poolFeesBeforeBlocked + expectedPoolContributionAfterBlocked;

        assertEq(actualChannelFundsAfterBlocked, expectedChannelFundsAfterBlocked);
        assertEq(actualPoolFeesAfterBlocked, expectedPoolFeesAfterBlocked);
    }
}
