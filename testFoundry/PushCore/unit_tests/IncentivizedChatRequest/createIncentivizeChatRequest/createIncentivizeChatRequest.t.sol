pragma solidity ^0.8.20;

import {BasePushIncentivizedChatRequest} from "../BasePushIncentivizedChatRequest.t.sol";
import {PushCoreStorageV1_5} from "contracts/PushCore/PushCoreStorageV1_5.sol";
import {Errors} from "contracts/libraries/Errors.sol";

contract CreateIncentivizeChatRequest_Test is BasePushIncentivizedChatRequest {
    function setUp() public virtual override {
        BasePushIncentivizedChatRequest.setUp();
    }

    modifier whenNotPaused() {
        _;
    }

    function test_Revertwhen_AmountIsZero() public whenNotPaused {
        address requestSender = actor.bob_channel_owner;
        address requestReceiver = actor.charlie_channel_owner;
        uint256 amount = 0;

        vm.prank(requestSender);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidArg_LessThanExpected.selector,
                0,
                amount
            )
        );

        commProxy.createIncentivizeChatRequest(requestReceiver, 0);
    }

    function test_Revertwhen_NotEnoughAllowance() public whenNotPaused {
        address requestSender = actor.bob_channel_owner;
        address requestReceiver = actor.charlie_channel_owner;
        uint256 amount = 1e8;

        vm.prank(requestSender);

        vm.expectRevert(
            bytes(
                "Push::transferFrom: transfer amount exceeds spender allowance"
            )
        );

        commProxy.createIncentivizeChatRequest(requestReceiver, amount);
    }

    function test_CoreShouldReceiveTokens() public whenNotPaused {
        address requestSender = actor.bob_channel_owner;
        address requestReceiver = actor.charlie_channel_owner;
        uint256 amount = 1e20;

        uint256 actualPushTokenbalanceBeforeCall = pushToken.balanceOf(
            address(coreProxy)
        );

        approveTokens(requestSender, address(commProxy), amount);
        vm.prank(requestSender);
        commProxy.createIncentivizeChatRequest(requestReceiver, amount);

        uint256 actualPushTokenbalanceAfterCall = pushToken.balanceOf(
            address(coreProxy)
        );
        uint256 expectedPushTokenbalanceAfterCall = actualPushTokenbalanceBeforeCall +
                amount;
        assertEq(
            expectedPushTokenbalanceAfterCall,
            actualPushTokenbalanceAfterCall
        );
    }

    function test_ShouldUpdateVariables() public whenNotPaused {
        address requestSender = actor.bob_channel_owner;
        address requestReceiver = actor.charlie_channel_owner;
        uint256 amount = 1e20;

        (
            address requestSenderBeforeFirstRequest,
            uint256 timestampBeforeFirstRequest,
            uint256 amountDepositedBeforeFirstRequest
        ) = commProxy.userChatData(requestSender);

        assertEq(requestSenderBeforeFirstRequest, address(0));
        assertEq(timestampBeforeFirstRequest, 0);
        assertEq(amountDepositedBeforeFirstRequest, 0);

        approveTokens(requestSender, address(commProxy), amount);
        vm.prank(requestSender);
        commProxy.createIncentivizeChatRequest(requestReceiver, amount);

        (
            address requestSenderAfterFirstRequest,
            uint256 timestampAfterFirstRequest,
            uint256 amountDepositedAfterFirstRequest
        ) = commProxy.userChatData(requestSender);

        uint256 blockTimestampInFirstRequest = block.timestamp;

        assertEq(requestSenderAfterFirstRequest, requestSender);
        assertEq(timestampAfterFirstRequest, blockTimestampInFirstRequest);
        assertEq(amountDepositedAfterFirstRequest, amount);

        uint256 forwardedTimestamp = 3000;
        skip(forwardedTimestamp);

        approveTokens(requestSender, address(commProxy), amount);
        vm.prank(requestSender);
        commProxy.createIncentivizeChatRequest(requestReceiver, amount);

        (
            address requestSenderAfterSecondRequest,
            uint256 timestampAfterSecondRequest,
            uint256 amountDepositedAfterSecondRequest
        ) = commProxy.userChatData(requestSender);

        assertEq(requestSenderAfterSecondRequest, requestSender);
        assertEq(
            timestampAfterSecondRequest,
            blockTimestampInFirstRequest + forwardedTimestamp
        );
        assertEq(amountDepositedAfterSecondRequest, amount * 2);
    }

    function test_ShouldEmitRelevantEvent() public whenNotPaused {
        address requestSender = actor.bob_channel_owner;
        address requestReceiver = actor.charlie_channel_owner;
        uint256 amount = 1e20;

        approveTokens(requestSender, address(commProxy), amount);

        vm.expectEmit(false, false, false, true, address(commProxy));
        emit IncentivizeChatReqInitiated(
            requestSender,
            requestReceiver,
            amount,
            block.timestamp
        );

        vm.prank(requestSender);
        commProxy.createIncentivizeChatRequest(requestReceiver, amount);
    }
}
