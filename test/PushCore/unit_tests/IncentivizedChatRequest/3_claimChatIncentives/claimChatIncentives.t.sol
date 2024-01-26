pragma solidity ^0.8.20;

import { BaseIncentivizedChatRequest } from "../BaseIncentivizedChatRequest.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";

contract ClaimChatIncentives_Test is BaseIncentivizedChatRequest {
    function setUp() public virtual override {
        BaseIncentivizedChatRequest.setUp();
        address requestSender = actor.bob_channel_owner;
        address requestReceiver = actor.charlie_channel_owner;
        uint256 amount = 1e20;

        approveTokens(requestSender, address(commProxy), amount);
        vm.prank(requestSender);
        commProxy.createIncentivizeChatRequest(requestReceiver, amount);
    }

    function test_REVERTWhen_ClaimableFunds_OfCaller_IsLessThan_AmountAsked() external {
        // it REVERT - InvalidArg_MoreThanExpected(claimable funds, _amount)
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArg_MoreThanExpected.selector, 1e20 - FEE_AMOUNT, 1e20));
        changePrank(actor.charlie_channel_owner);
        coreProxy.claimChatIncentives(1e20);
    }

    function test_When_ClaimableFunds_OfCaller_IsMoreThanOrEqual_ToAmountAsked() external {
        // it should update claimable funds of caller and emit ChatIncentiveClaimed(msg.sender, _amount)
        // it should transfer PUSH token equal to _amount passed
        uint256 coreBalanceBefore = pushToken.balanceOf(address(coreProxy));
        uint256 charlieBalanceBefore = pushToken.balanceOf(actor.charlie_channel_owner);
        uint256 claimableFundsBefore = coreProxy.celebUserFunds(actor.charlie_channel_owner);
        uint256 amountToClaim = 1e20 - FEE_AMOUNT;
        changePrank(actor.charlie_channel_owner);
        coreProxy.claimChatIncentives(amountToClaim);

        uint256 coreBalanceAfter = pushToken.balanceOf(address(coreProxy));
        uint256 charlieBalanceAfter = pushToken.balanceOf(actor.charlie_channel_owner);
        uint256 claimableFundsAfter = coreProxy.celebUserFunds(actor.charlie_channel_owner);

        assertEq(coreBalanceBefore, coreBalanceAfter + amountToClaim);
        assertEq(charlieBalanceBefore, charlieBalanceAfter - amountToClaim);
        assertEq(claimableFundsAfter, claimableFundsBefore - amountToClaim);
    }
}
