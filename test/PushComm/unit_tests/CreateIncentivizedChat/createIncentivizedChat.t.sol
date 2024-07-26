// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BasePushCommTest } from "../BasePushCommTest.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { console } from "forge-std/console.sol";

contract test_createIncentivizedChat is BasePushCommTest {
    function setUp() public override {
        BasePushCommTest.setUp();
    }

    modifier whenUserCreatesIncentivizedChat() {
        approveTokens(actor.bob_channel_owner, address(commEthProxy), 100 ether);
        _;
    }

    function test_WhenPassedAmountIsZero() external whenUserCreatesIncentivizedChat {
        // it should Revert
        changePrank(actor.bob_channel_owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArg_LessThanExpected.selector, 1, 0));
        commEthProxy.createIncentivizeChatRequest(actor.charlie_channel_owner, 0);
    }

    function test_WhenParametersAreCorrect() public whenUserCreatesIncentivizedChat {
        // it should update chatInfo and call core and emit event
        uint256 bobBalanceBefore = pushToken.balanceOf(actor.bob_channel_owner);
        uint256 coreBalanceBefore = pushToken.balanceOf(address(coreProxy));

        changePrank(actor.bob_channel_owner);

        vm.expectEmit(false, false, false, true);
        emit IncentivizeChatReqReceived(
            actor.bob_channel_owner, actor.charlie_channel_owner, 100e18 - FEE_AMOUNT, FEE_AMOUNT, block.timestamp
        );
        vm.expectEmit(false, false, false, true);
        emit IncentivizeChatReqInitiated(actor.bob_channel_owner, actor.charlie_channel_owner, 100e18, block.timestamp);

        commEthProxy.createIncentivizeChatRequest(actor.charlie_channel_owner, 100e18);

        assertEq(bobBalanceBefore - 100e18, pushToken.balanceOf(actor.bob_channel_owner));
        assertEq(coreBalanceBefore + 100e18, pushToken.balanceOf(address(coreProxy)));

        (address sender, uint256 time, uint256 amount) = commEthProxy.userChatData(actor.bob_channel_owner);
        assertEq(sender, actor.bob_channel_owner);
        assertEq(time, block.timestamp);
        assertEq(amount, 100e18);
    }

    modifier whenCoreIsCalled() {
        _;
    }

    function test_RevertWhen_CallerIsNotComm() external whenCoreIsCalled {
        // it should revert
        changePrank(address(this));
        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedCaller.selector, address(this)));
        coreProxy.handleChatRequestData(actor.bob_channel_owner, actor.charlie_channel_owner, 100e18);
    }

    function test_WhenCallerIsComm() external whenCoreIsCalled {
        // it should update storage and emit event
        uint256 previousAmount = coreProxy.celebUserFunds(actor.charlie_channel_owner);
        uint256 PROTOCOL_POOL_FEES = coreProxy.PROTOCOL_POOL_FEES();
        test_WhenParametersAreCorrect();
        assertEq(previousAmount + 100e18 - FEE_AMOUNT, coreProxy.celebUserFunds(actor.charlie_channel_owner));
        assertEq(PROTOCOL_POOL_FEES + FEE_AMOUNT, coreProxy.PROTOCOL_POOL_FEES());
    }

    modifier whenCelebTriesToClaimTheTokens() {
        _;
    }

    function test_WhenRequestedAmountIsMoreThanBalance() external whenCelebTriesToClaimTheTokens {
        // it should Revert
        test_WhenParametersAreCorrect();
        uint256 claimAmount = coreProxy.celebUserFunds(actor.charlie_channel_owner);

        changePrank(actor.charlie_channel_owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidArg_MoreThanExpected.selector,
                coreProxy.celebUserFunds(actor.charlie_channel_owner),
                claimAmount + 1
            )
        );
        coreProxy.claimChatIncentives(claimAmount + 1);
    }

    function test_WhenRequestedAmountIsCorrect() external whenCelebTriesToClaimTheTokens {
        // it should transfer the tokens to celebUser
        uint256 claimAmount = coreProxy.celebUserFunds(actor.charlie_channel_owner);
        uint256 charlieBalanceBefore = pushToken.balanceOf(actor.charlie_channel_owner);
        uint256 coreBalanceBefore = pushToken.balanceOf(address(coreProxy));

        changePrank(actor.charlie_channel_owner);
        coreProxy.claimChatIncentives(claimAmount);

        assertEq(charlieBalanceBefore + claimAmount, pushToken.balanceOf(actor.charlie_channel_owner));
        assertEq(coreBalanceBefore - claimAmount, pushToken.balanceOf(address(coreProxy)));
    }
}
