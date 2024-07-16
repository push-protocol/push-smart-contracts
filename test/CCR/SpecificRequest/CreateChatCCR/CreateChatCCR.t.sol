// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseCCRTest } from "../../BaseCCR.t.sol";
import { Errors } from ".././../../../contracts/libraries/Errors.sol";
import { console } from "forge-std/console.sol";

import { CrossChainRequestTypes } from "../../../../contracts/libraries/DataTypes.sol";
import "./../../../../contracts/libraries/wormhole-lib/TrimmedAmount.sol";
import { TransceiverStructs } from "./../../../../contracts/libraries/wormhole-lib/TransceiverStructs.sol";

contract CreateChatCCR is BaseCCRTest {
    uint256 amount = 100e18;

    function setUp() public override {
        BaseCCRTest.setUp();
        sourceAddress = toWormholeFormat(address(commProxy));
        (_payload, requestPayload) = getSpecificPayload(
            CrossChainRequestTypes.CrossChainFunction.IncentivizedChat,
            actor.charlie_channel_owner,
            amount,
            0,
            percentage,
            actor.bob_channel_owner
        );
    }

    modifier whenCreateChatIsCalled() {
        _;
    }

    function test_WhenContractIsPaused() external whenCreateChatIsCalled {
        // it should Revert

        changePrank(actor.admin);
        commProxy.pauseContract();
        vm.expectRevert("Pausable: paused");
        changePrank(actor.bob_channel_owner);
        commProxy.createCrossChainRequest(
            CrossChainRequestTypes.CrossChainFunction.IncentivizedChat, _payload, amount, GasLimit
        );
    }

    function test_RevertWhen_AmountIsLessThanMinimumFees() external whenCreateChatIsCalled {
        // it should revert
        amount = FEE_AMOUNT - 1e18;
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArg_LessThanExpected.selector, FEE_AMOUNT, amount));
        changePrank(actor.bob_channel_owner);
        commProxy.createCrossChainRequest(
            CrossChainRequestTypes.CrossChainFunction.IncentivizedChat, _payload, amount, GasLimit
        );
    }

    function test_RevertWhen_EtherPassedIsLess() external whenCreateChatIsCalled {
        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientFunds.selector));
        changePrank(actor.bob_channel_owner);
        commProxy.createCrossChainRequest(
            CrossChainRequestTypes.CrossChainFunction.IncentivizedChat, _payload, amount, GasLimit
        );
    }

    function test_WhenAllChecksPasses() public whenCreateChatIsCalled {
        // it should successfully create the CCR
        vm.expectEmit(true, false, false, false);
        emit LogMessagePublished(ArbSepolia.WORMHOLE_RELAYER_SOURCE, 2105, 0, requestPayload, 15);
        changePrank(actor.bob_channel_owner);
        commProxy.createCrossChainRequest{ value: 1e18 }(
            CrossChainRequestTypes.CrossChainFunction.IncentivizedChat, _payload, amount, GasLimit
        );
    }

    modifier whenReceiveFunctionIsCalledInCore() {
        test_WhenAllChecksPasses();
        setUpDestChain(EthSepolia.rpc);
        _;
    }

    function test_WhenSenderIsNotRegistered() external whenReceiveFunctionIsCalledInCore {
        // it should Revert

        //set sender to zero address
        coreProxy.setRegisteredSender(ArbSepolia.SourceChainId, toWormholeFormat(address(0)));

        vm.expectRevert("Not registered sender");
        receiveWormholeMessage(requestPayload);
    }

    function test_WhenSenderIsNotRelayer() external whenReceiveFunctionIsCalledInCore {
        // it should Revert

        coreProxy.setWormholeRelayer(address(0));
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotAdmin.selector));
        receiveWormholeMessage(requestPayload);
    }

    function test_WhenDeliveryHashIsUsedAlready() external whenReceiveFunctionIsCalledInCore {
        // it should Revert

        receiveWormholeMessage(requestPayload);
        vm.expectRevert(abi.encodeWithSelector(Errors.Payload_Duplicacy_Error.selector));
        receiveWormholeMessage(requestPayload);
    }

    function test_whenReceiveChecksPass() public whenReceiveFunctionIsCalledInCore {
        // it should emit event and create Channel

        uint256 poolFeeAmount = coreProxy.FEE_AMOUNT();
        uint256 userFundsPre = coreProxy.celebUserFunds(actor.charlie_channel_owner);
        uint256 PROTOCOL_POOL_FEES = coreProxy.PROTOCOL_POOL_FEES();

        vm.expectEmit(false, false, false, true);
        emit IncentivizeChatReqReceived(
            actor.bob_channel_owner, actor.charlie_channel_owner, amount - poolFeeAmount, poolFeeAmount, block.timestamp
        );

        receiveWormholeMessage(requestPayload);

        assertEq(coreProxy.celebUserFunds(actor.charlie_channel_owner), userFundsPre + amount - poolFeeAmount);
        assertEq(coreProxy.PROTOCOL_POOL_FEES(), PROTOCOL_POOL_FEES + poolFeeAmount);
    }

    function test_whenTokensAreTransferred() external {
        test_whenReceiveChecksPass();

        console.log(pushNttToken.balanceOf(address(coreProxy)));

        bytes[] memory a;
        TrimmedAmount _amt = _trimTransferAmount(amount);
        bytes memory tokenTransferMessage = TransceiverStructs.encodeNativeTokenTransfer(
            TransceiverStructs.NativeTokenTransfer({
                amount: _amt,
                sourceToken: toWormholeFormat(address(ArbSepolia.PUSH_NTT_SOURCE)),
                to: toWormholeFormat(address(coreProxy)),
                toChain: EthSepolia.DestChainId
            })
        );

        bytes memory transceiverMessage;
        TransceiverStructs.NttManagerMessage memory nttManagerMessage;
        (nttManagerMessage, transceiverMessage) = buildTransceiverMessageWithNttManagerPayload(
            0,
            toWormholeFormat(address(ArbSepolia.PushHolder)),
            toWormholeFormat(ArbSepolia.NTT_MANAGER),
            toWormholeFormat(EthSepolia.NTT_MANAGER),
            tokenTransferMessage
        );
        bytes32 hash = TransceiverStructs.nttManagerMessageDigest(10_003, nttManagerMessage);
        changePrank(EthSepolia.WORMHOLE_RELAYER_DEST);
        EthSepolia.wormholeTransceiverChain2.receiveWormholeMessages(
            transceiverMessage, // Verified
            a, // Should be zero
            bytes32(uint256(uint160(address(ArbSepolia.wormholeTransceiverChain1)))), // Must be a wormhole peers
            10_003, // ChainID from the call
            hash // Hash of the VAA being used
        );

        assertEq(pushNttToken.balanceOf(address(coreProxy)), amount);
    }
}
