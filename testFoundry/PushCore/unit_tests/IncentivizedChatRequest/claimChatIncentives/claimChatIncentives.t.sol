pragma solidity ^0.8.20;

import {BasePushIncentivizedChatRequest} from "../BasePushIncentivizedChatRequest.t.sol";
import {PushCoreStorageV1_5} from "contracts/PushCore/PushCoreStorageV1_5.sol";
import {Errors} from "contracts/libraries/Errors.sol";

contract ClaimChatIncentives_Test is BasePushIncentivizedChatRequest {
    function setUp() public virtual override {
        BasePushIncentivizedChatRequest.setUp();
    }

    modifier whenNotPaused() {
        _;
    }

    function test_Revertwhen_AmountMoreThanCelebFunds() public whenNotPaused {
        uint256 amount = 1e6;

        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidArg_MoreThanExpected.selector, 0, amount)
        );

        vm.prank(actor.bob_channel_owner);
        coreProxy.claimChatIncentives(amount);
    }

    function test_ShouldTransferFunds() public whenNotPaused {
        address requestSender = actor.bob_channel_owner;
        address requestReceiver = actor.charlie_channel_owner;
        uint256 amountReq = 1e20;

        // To populate celebUserFunds
        approveTokens(requestSender, address(commProxy), amountReq);
        vm.prank(requestSender);
        commProxy.createIncentivizeChatRequest(requestReceiver, amountReq);

        uint256 actualPushBalanceBeforeClaimed = pushToken.balanceOf(requestReceiver);

        uint256 amountClaimed = 1e18;
        vm.prank(requestReceiver);
        coreProxy.claimChatIncentives(amountClaimed);

        uint256 actualPushBalanceAfterClaimed = pushToken.balanceOf(requestReceiver);
        uint256 expectedPushBalanceAfterClaimed = actualPushBalanceBeforeClaimed + amountClaimed;

        assertEq(expectedPushBalanceAfterClaimed, actualPushBalanceAfterClaimed);
    }

    function test_ShouldUpdateRelevantVariables() public whenNotPaused {
        address requestSender = actor.bob_channel_owner;
        address requestReceiver = actor.charlie_channel_owner;
        uint256 amountReq = 1e20;

        // To populate celebUserFunds
        approveTokens(requestSender, address(commProxy), amountReq);
        vm.prank(requestSender);
        commProxy.createIncentivizeChatRequest(requestReceiver, amountReq);

        uint256 actualCelebUserFundsBeforeClaimed = coreProxy.celebUserFunds(requestReceiver);
        uint256 amountClaimed = 1e18;

        vm.prank(requestReceiver);
        coreProxy.claimChatIncentives(amountClaimed);

        uint256 actualCelebUserFundsAfterClaimed = coreProxy.celebUserFunds(requestReceiver);
        uint256 expectedCelebUserFundsAfterClaimed = actualCelebUserFundsBeforeClaimed - amountClaimed;

        assertEq(actualCelebUserFundsAfterClaimed, expectedCelebUserFundsAfterClaimed);
    }

    function test_ShouldEmitRelevantEvent() public whenNotPaused {
        address requestSender = actor.bob_channel_owner;
        address requestReceiver = actor.charlie_channel_owner;
        uint256 amountReq = 1e20;

        // To populate celebUserFunds
        approveTokens(requestSender, address(commProxy), amountReq);
        vm.prank(requestSender);
        commProxy.createIncentivizeChatRequest(requestReceiver, amountReq);

        uint256 amountClaimed = 1e18;
        vm.expectEmit(true, true, false, true, address(coreProxy));
        emit ChatIncentiveClaimed(
            requestReceiver,
            amountClaimed
        );

        vm.prank(requestReceiver);
        coreProxy.claimChatIncentives(amountClaimed);
    }
}
