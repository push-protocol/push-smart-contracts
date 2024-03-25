pragma solidity ^0.8.20;

import { BasePushCoreTest } from "../../BasePushCoreTest.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";

contract transferChannelOwnership is BasePushCoreTest {
    function setUp() public virtual override {
        BasePushCoreTest.setUp();

        _createChannel(actor.bob_channel_owner);
    }

    modifier whenTheFunctionIsCalled() {
        _;
    }

    function test_WhenContractIsPaused() external whenTheFunctionIsCalled {
        // it should REVERT
        vm.prank(actor.admin);
        coreProxy.pauseContract();
        vm.prank(actor.bob_channel_owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.EnforcedPause.selector));
        coreProxy.transferChannelOwnership(actor.bob_channel_owner, actor.alice_channel_owner, 50 ether);
    }

    function test_WhenCallerIsNotOwner() external whenTheFunctionIsCalled {
        // it should REVERT

        vm.prank(actor.alice_channel_owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedCaller.selector, actor.alice_channel_owner));
        coreProxy.transferChannelOwnership(actor.bob_channel_owner, actor.alice_channel_owner, 50 ether);
    }

    function test_WhenChannelIsNotActive() external whenTheFunctionIsCalled {
        // it should REVERT

        vm.prank(actor.alice_channel_owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedCaller.selector, actor.alice_channel_owner));
        coreProxy.transferChannelOwnership(actor.alice_channel_owner, actor.bob_channel_owner, 50 ether);
    }

    function test_WhenAmountIsLessThanMinimumFees() external whenTheFunctionIsCalled {
        // it should REVERT

        vm.prank(actor.bob_channel_owner);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidArg_LessThanExpected.selector, ADD_CHANNEL_MIN_FEES, 49 ether)
        );
        coreProxy.transferChannelOwnership(actor.bob_channel_owner, actor.alice_channel_owner, 49 ether);
    }

    function test_WhenAllInputsAreCorrect() external whenTheFunctionIsCalled {
        // it should execute and update the storage
        (
            ,
            uint8 beforeChannelState,
            ,
            uint256 beforePoolContribution,
            ,
            ,
            ,
            uint256 beforeChannelStartBlock,
            uint256 beforeChannelUpdateBlock,
            uint256 beforeChannelWeight,
        ) = coreProxy.channels(actor.bob_channel_owner);

        vm.prank(actor.bob_channel_owner);
        coreProxy.transferChannelOwnership(actor.bob_channel_owner, actor.alice_channel_owner, 50 ether);
        {
            (
                ,
                uint8 ChannelState,
                ,
                uint256 PoolContribution,
                ,
                ,
                ,
                uint256 ChannelStartBlock,
                uint256 ChannelUpdateBlock,
                uint256 ChannelWeight,
            ) = coreProxy.channels(actor.bob_channel_owner);
            assertEq(ChannelState, 0);
            assertEq(PoolContribution, 0);
            assertEq(ChannelStartBlock, 0);
            assertEq(ChannelUpdateBlock, 0);
            assertEq(ChannelWeight, 0);
        }
        (
            ,
            uint8 aliceChannelState,
            ,
            uint256 alicePoolContribution,
            ,
            ,
            ,
            uint256 aliceChannelStartBlock,
            uint256 aliceChannelUpdateBlock,
            uint256 aliceChannelWeight,
        ) = coreProxy.channels(actor.alice_channel_owner);
        assertEq(aliceChannelState, beforeChannelState);
        assertEq(alicePoolContribution, beforePoolContribution);
        assertEq(aliceChannelStartBlock, beforeChannelStartBlock);
        assertEq(aliceChannelUpdateBlock, beforeChannelUpdateBlock);
        assertEq(aliceChannelWeight, beforeChannelWeight);
    }
}
