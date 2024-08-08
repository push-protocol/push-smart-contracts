// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseCCRTest } from "../../../BaseCCR.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { console } from "forge-std/console.sol";

import { CrossChainRequestTypes } from "contracts/libraries/DataTypes.sol";
import { BaseHelper } from "contracts/libraries/BaseHelper.sol";

contract DeactivateChannelCCR is BaseCCRTest {
    uint256 amount;

    function setUp() public override {
        BaseCCRTest.setUp();
        sourceAddress = toWormholeFormat(address(commProxy));
        (_payload, requestPayload) = getSpecificPayload(
            CrossChainRequestTypes.CrossChainFunction.DeactivateChannel,
            BaseHelper.addressToBytes32(actor.bob_channel_owner),
            amount,
            0,
            percentage,
            0,
            "",
            "",
            BaseHelper.addressToBytes32(actor.bob_channel_owner)
        );
    }

    modifier whencreateCrossChainReqIsCalled() {
        _;
    }

    function test_WhenContractIsPaused() external whencreateCrossChainReqIsCalled {
        // it should Revert

        changePrank(actor.admin);
        commProxy.pauseContract();
        vm.expectRevert("Pausable: paused");
        changePrank(actor.bob_channel_owner);
        commProxy.createCrossChainRequest(
            CrossChainRequestTypes.CrossChainFunction.DeactivateChannel, _payload, amount, GasLimit
        );
    }

    function test_RevertWhen_EtherPassedIsLess() external whencreateCrossChainReqIsCalled {
        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientFunds.selector));
        changePrank(actor.bob_channel_owner);
        commProxy.createCrossChainRequest(
            CrossChainRequestTypes.CrossChainFunction.DeactivateChannel, _payload, amount, GasLimit
        );
    }

    function test_WhenAllChecksPasses() public whencreateCrossChainReqIsCalled {
        // it should successfully create the CCR
        vm.expectEmit(true, false, false, false);
        emit LogMessagePublished(SourceChain.WORMHOLE_RELAYER_SOURCE, 2105, 0, requestPayload, 15);
        changePrank(actor.bob_channel_owner);
        commProxy.createCrossChainRequest{ value: 1e18 }(
            CrossChainRequestTypes.CrossChainFunction.DeactivateChannel, _payload, amount, GasLimit
        );
    }

    modifier whenReceiveFunctionIsCalledInCore() {
        test_WhenAllChecksPasses();
        setUpDestChain();
        _;
    }

    function test_WhenSenderIsNotRegistered() external whenReceiveFunctionIsCalledInCore {
        // it should Revert

        //set sender to zero address
        coreProxy.setRegisteredSender(SourceChain.SourceChainId, toWormholeFormat(address(0)));

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

    function test_WhenChannelIsActive() public whenReceiveFunctionIsCalledInCore {
        // it should deactivate Channel
        uint256 CHANNEL_POOL_FUNDS = coreProxy.CHANNEL_POOL_FUNDS();

        (
         ,
         ,
         ,
        uint256 poolContributionBefore,
         ,
         ,
         ,
         ,
         ,
         ,
         ) = coreProxy.channelInfo(toWormholeFormat(actor.bob_channel_owner));

         uint refundableAmount = poolContributionBefore - MIN_POOL_CONTRIBUTION;

        vm.expectEmit(true, true, false, true);
        emit ChannelStateUpdate(toWormholeFormat(actor.bob_channel_owner), refundableAmount, amount);

        receiveWormholeMessage(requestPayload);
        (
         ,
        uint8 channelState,
         ,
        uint256 poolContribution,
         ,
         ,
         ,
         ,
         ,
        uint256 channelWeight,
         
        ) = coreProxy.channelInfo(toWormholeFormat(actor.bob_channel_owner));
        assertEq(coreProxy.CHANNEL_POOL_FUNDS(), CHANNEL_POOL_FUNDS - refundableAmount,"Channel Pool Funcds");
        assertEq(channelState, 2, "Channel State");
        assertEq(poolContribution, MIN_POOL_CONTRIBUTION, "Pool contribution " );
        assertEq(channelWeight, (MIN_POOL_CONTRIBUTION * ADJUST_FOR_FLOAT)/MIN_POOL_CONTRIBUTION, "Channel Weight");
    }
    function test_whenTokensAreTransferred() external {
        amount = ADD_CHANNEL_MIN_FEES;
        (_payload, requestPayload) = getSpecificPayload(
            CrossChainRequestTypes.CrossChainFunction.DeactivateChannel,
            BaseHelper.addressToBytes32(actor.bob_channel_owner),
            amount,
            0,
            percentage,
            0,
            "",
            "",
            BaseHelper.addressToBytes32(actor.bob_channel_owner)
        );

        changePrank(actor.bob_channel_owner);
        vm.recordLogs();
        commProxy.createCrossChainRequest{ value: 1e18 }(
            CrossChainRequestTypes.CrossChainFunction.DeactivateChannel, _payload, amount, GasLimit
        );        
        
        (address sourceNttManager, bytes32 recipient, uint256 _amount, uint16 recipientChain) =
            getMessagefromLog(vm.getRecordedLogs());

        bytes[] memory a;
        (bytes memory transceiverMessage, bytes32 hash) =
            getRequestPayload(_amount, recipient, recipientChain, sourceNttManager);
        
        setUpDestChain();
        uint balanceCoreBefore = pushToken.balanceOf(address(coreProxy));

        changePrank(DestChain.WORMHOLE_RELAYER_DEST);
        DestChain.wormholeTransceiverChain2.receiveWormholeMessages(
            transceiverMessage, // Verified
            a, // Should be zero
            bytes32(uint256(uint160(address(SourceChain.wormholeTransceiverChain1)))), // Must be a wormhole peers
            10_003, // ChainID from the call
            hash // Hash of the VAA being used
        );

        assertEq(pushToken.balanceOf(address(coreProxy)), balanceCoreBefore + amount, "Tokens in Core");    
    }
}
