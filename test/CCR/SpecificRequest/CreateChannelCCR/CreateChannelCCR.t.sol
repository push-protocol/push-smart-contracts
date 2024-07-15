// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseCCRTest } from "../../BaseCCR.t.sol";
import { CoreTypes, CrossChainRequestTypes } from "../../../../contracts/libraries/DataTypes.sol";
import { Errors } from ".././../../../contracts/libraries/Errors.sol";
import { console } from "forge-std/console.sol";
import "./../../../../contracts/libraries/wormhole-lib/TrimmedAmount.sol";
import { TransceiverStructs } from "./../../../../contracts/libraries/wormhole-lib/TransceiverStructs.sol";

contract CreateChannelCCR is BaseCCRTest {
    uint256 amount = ADD_CHANNEL_MIN_FEES;

    function setUp() public override {
        BaseCCRTest.setUp();
        sourceAddress = toWormholeFormat(address(commProxy));
        (_payload, requestPayload) = getSpecificPayload(
            CrossChainRequestTypes.CrossChainFunction.AddChannel, address(0), amount, 0, 0, actor.charlie_channel_owner
        );
    }

    modifier whenCreateChannelIsCalled() {
        _;
    }

    function test_WhenContractIsPaused() external whenCreateChannelIsCalled {
        // it should Revert

        changePrank(actor.admin);
        commProxy.pauseContract();
        vm.expectRevert("Pausable: paused");
        changePrank(actor.charlie_channel_owner);
        commProxy.createCrossChainRequest(
            CrossChainRequestTypes.CrossChainFunction.AddChannel, _payload, amount, 10_000_000
        );
    }

    function test_RevertWhen_AmountIsLessThanMinimumFees() external whenCreateChannelIsCalled {
        // it should revert
        amount = 49e18;
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidArg_LessThanExpected.selector, ADD_CHANNEL_MIN_FEES, amount)
        );
        changePrank(actor.charlie_channel_owner);
        commProxy.createCrossChainRequest(
            CrossChainRequestTypes.CrossChainFunction.AddChannel, _payload, amount, 10_000_000
        );
    }

    function test_RevertWhen_EtherPassedIsLess() external whenCreateChannelIsCalled {
        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientFunds.selector));
        changePrank(actor.charlie_channel_owner);
        commProxy.createCrossChainRequest(
            CrossChainRequestTypes.CrossChainFunction.AddChannel, _payload, amount, 10_000_000
        );
    }

    function test_WhenAllChecksPasses() public whenCreateChannelIsCalled {
        // it should successfully create the CCR

        vm.expectEmit(true, false, false, false);
        emit LogMessagePublished(ArbSepolia.WORMHOLE_RELAYER_SOURCE, 2105, 0, requestPayload, 15);
        changePrank(actor.charlie_channel_owner);
        commProxy.createCrossChainRequest{ value: 1e18 }(
            CrossChainRequestTypes.CrossChainFunction.AddChannel, _payload, amount, 10_000_000
        );
    }

    modifier whenReceiveFunctionIsCalledInCore() {
        test_WhenAllChecksPasses();

        setUpChain2(EthSepolia.rpc);
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

    function test_WhenAllChecksPass() public whenReceiveFunctionIsCalledInCore {
        // it should emit event and create Channel

        (uint256 poolFunds, uint256 poolFees) = getPoolFundsAndFees(amount);

        vm.expectEmit(true, true, false, true);
        emit ChannelCreated(
            toWormholeFormat(actor.charlie_channel_owner),
            CoreTypes.ChannelType.InterestBearingMutual,
            _testChannelUpdatedIdentity
        );

        receiveWormholeMessage(requestPayload);
        assertEq(coreProxy.CHANNEL_POOL_FUNDS(), poolFunds);
        assertEq(coreProxy.PROTOCOL_POOL_FEES(), poolFees);

        (
            CoreTypes.ChannelType channelType,
            uint8 channelState,
            ,
            uint256 poolContribution,
            ,
            ,
            ,
            uint256 channelStartBlock,
            uint256 channelUpdateBlock,
            uint256 channelWeight,
        ) = coreProxy.channelInfo(toWormholeFormat(actor.charlie_channel_owner));

        assertEq(uint8(channelType), uint8(CoreTypes.ChannelType.InterestBearingMutual), "channel Type");
        assertEq(channelState, 1, "channel State");
        assertEq(poolContribution, amount - coreProxy.FEE_AMOUNT(), "Pool Contribution");
        assertEq(channelStartBlock, block.number, "Channel Start Block");
        assertEq(channelUpdateBlock, block.number, "Chanel Update Block");
        assertEq(
            channelWeight,
            ((amount - coreProxy.FEE_AMOUNT()) * 10 ** 7) / coreProxy.MIN_POOL_CONTRIBUTION(),
            "Channel Weight"
        );
    }

    function test_whenTokensAreTransferred() external {
        test_WhenAllChecksPass();

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
