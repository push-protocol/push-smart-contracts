pragma solidity ^0.8.20;

import { BaseIncentivizedChatRequest } from "../BaseIncentivizedChatRequest.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";

contract HandleChatRequestData_Test is BaseIncentivizedChatRequest {
    function setUp() public virtual override {
        BaseIncentivizedChatRequest.setUp();
    }

    modifier whenNotPaused() {
        _;
    }

    function test_Revertwhen_CallerNotComm() public whenNotPaused {
        address requestSender = actor.bob_channel_owner;
        address requestReceiver = actor.charlie_channel_owner;
        uint256 amount = 1e6;

        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedCaller.selector, requestSender));

        vm.prank(requestSender);
        coreProxy.handleChatRequestData(requestSender, requestReceiver, amount);
    }

    function test_ShouldUpdateRelevantVariables() public whenNotPaused {
        address requestSender = actor.bob_channel_owner;
        address requestReceiver = actor.charlie_channel_owner;
        uint256 amount = 1e20;

        uint256 actualCelebUserFundsBeforeRequest = coreProxy.celebUserFunds(requestReceiver);
        uint256 actualProtocolFeeBeforeRequest = coreProxy.PROTOCOL_POOL_FEES();

        approveTokens(requestSender, address(commProxy), amount);
        vm.prank(requestSender);
        commProxy.createIncentivizeChatRequest(requestReceiver, amount);

        uint256 actualCelebUserFundsAfterRequest = coreProxy.celebUserFunds(requestReceiver);
        uint256 actualProtocolFeeAfterRequest = coreProxy.PROTOCOL_POOL_FEES();

        uint256 corePoolFeeAmount = coreProxy.FEE_AMOUNT();
        uint256 expectedCelebUserFundsAfterRequest = actualCelebUserFundsBeforeRequest + amount - corePoolFeeAmount;
        uint256 expectedProtocolFeeAfterRequest = actualProtocolFeeBeforeRequest + corePoolFeeAmount;

        assertEq(expectedCelebUserFundsAfterRequest, actualCelebUserFundsAfterRequest);
        assertEq(expectedProtocolFeeAfterRequest, actualProtocolFeeAfterRequest);
    }

    function test_ShouldEmitRelevantEvent() public whenNotPaused {
        address requestSender = actor.bob_channel_owner;
        address requestReceiver = actor.charlie_channel_owner;
        uint256 amount = 1e20;

        approveTokens(requestSender, address(commProxy), amount);
        uint256 corePoolFeeAmount = coreProxy.FEE_AMOUNT();

        vm.expectEmit(false, false, false, true, address(coreProxy));
        emit IncentivizeChatReqReceived(
            requestSender, requestReceiver, amount - corePoolFeeAmount, corePoolFeeAmount, block.timestamp
        );

        vm.prank(requestSender);
        commProxy.createIncentivizeChatRequest(requestReceiver, amount);
    }
}
