pragma solidity ^0.8.20;

import { BasePushCoreTest } from "../BasePushCoreTest.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";

contract ContractPausability_Test is BasePushCoreTest {
    function setUp() public virtual override {
        BasePushCoreTest.setUp();
    }

    modifier whenNotPaused() {
        _;
    }

    function test_Revertwhen_PausingNotByAdmin() public whenNotPaused {
        vm.prank(actor.bob_channel_owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotAdmin.selector));
        coreProxy.pauseContract();
    }

    function test_Revertwhen_UnpausingNotByAdmin() public {
        vm.prank(actor.bob_channel_owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotAdmin.selector));
        coreProxy.unPauseContract();
    }

    function test_PausingByAdmin() public whenNotPaused {
        vm.expectEmit(false, false, false, true, address(coreProxy));
        emit Paused(actor.admin);

        vm.prank(actor.admin);
        coreProxy.pauseContract();
    }

    function test_UnpausingByAdmin() public {
        vm.prank(actor.admin);
        coreProxy.pauseContract();

        vm.expectEmit(false, false, false, true, address(coreProxy));
        emit Unpaused(actor.admin);

        vm.prank(actor.admin);
        coreProxy.unPauseContract();
    }

    function test_Revertwhen_CreateChannelAfterPaused() public {
        vm.prank(actor.admin);
        coreProxy.pauseContract();

        vm.expectRevert("Pausable: paused");
        _createChannel(actor.bob_channel_owner);
    }

    function test_Revertwhen_DeactivateChannelAfterPaused() public {
        _createChannel(actor.bob_channel_owner);

        vm.prank(actor.admin);
        coreProxy.pauseContract();

        vm.expectRevert("Pausable: paused");
        vm.prank(actor.bob_channel_owner);
        coreProxy.updateChannelState(0);
    }

    function test_Revertwhen_ReactivateChannelAfterPaused() public {
        _createChannel(actor.bob_channel_owner);
        vm.prank(actor.bob_channel_owner);
        coreProxy.updateChannelState(0);

        vm.prank(actor.admin);
        coreProxy.pauseContract();

        vm.expectRevert("Pausable: paused");
        vm.prank(actor.bob_channel_owner);
        coreProxy.updateChannelState(ADD_CHANNEL_MIN_FEES);
    }

    function test_Revertwhen_BlockChannelAfterPaused() public {
        _createChannel(actor.bob_channel_owner);

        vm.prank(actor.admin);
        coreProxy.pauseContract();

        vm.expectRevert("Pausable: paused");
        vm.prank(actor.admin);
        coreProxy.blockChannel(toWormholeFormat(actor.bob_channel_owner));
    }

    function test_ChannelFunctionsAfterPauseUnpause() public {
        vm.startPrank(actor.admin);
        coreProxy.pauseContract();
        coreProxy.unPauseContract();
        vm.stopPrank();

        _createChannel(actor.bob_channel_owner);
        vm.startPrank(actor.bob_channel_owner);
        coreProxy.updateChannelState(0);
        coreProxy.updateChannelState(ADD_CHANNEL_MIN_FEES);
        vm.stopPrank();

        vm.prank(actor.admin);
        coreProxy.blockChannel(toWormholeFormat(actor.bob_channel_owner));
    }
}
