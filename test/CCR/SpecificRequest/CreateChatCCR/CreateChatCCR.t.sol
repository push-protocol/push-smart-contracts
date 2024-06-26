// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseCCRTest } from "../../BaseCCR.t.sol";
import { CrossChainRequestTypes } from "../../../../contracts/libraries/DataTypes.sol";
import { Errors } from ".././../../../contracts/libraries/Errors.sol";
import { console } from "forge-std/console.sol";

contract CreateChatCCR is BaseCCRTest {
    CrossChainRequestTypes.SpecificRequestPayload _payload;
    bytes requestPayload;
    uint256 amount = 100e18;

    bytes[] additionalVaas;
    bytes32 sourceAddress;
    uint16 sourceChain = chainId1;
    bytes32 deliveryHash = 0x97f309914aa8b670f4a9212ba06670557b0c92a7ad853b637be8a9a6c2ea6447;

    function setUp() public override {
        BaseCCRTest.setUp();
        sourceAddress = toWormholeFormat(address(commProxy));
        (_payload, requestPayload) = getSpecificPayload(
            coreProxy.handleChatRequestData.selector, actor.charlie_channel_owner, amount, "channleStr"
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
        changePrank(actor.bob_channel_owner);
        commProxy.createIncentivizedChatRequest(_payload, amount, 10_000_000);
    }

    function test_RevertWhen_AmountIsLessThanMinimumFees() external whenCreateChannelIsCalled {
        // it should revert
        amount = amount - amount;
        vm.expectRevert("Invalid Amount");
        changePrank(actor.bob_channel_owner);
        commProxy.createIncentivizedChatRequest(_payload, amount, 10_000_000);
    }

    function test_RevertWhen_EtherPassedIsLess() external whenCreateChannelIsCalled {
        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientFunds.selector));
        changePrank(actor.bob_channel_owner);
        commProxy.createIncentivizedChatRequest(_payload, amount, 10_000_000);
    }

    function test_WhenAllChecksPasses() public whenCreateChannelIsCalled {
        // it should successfully create the CCR
        vm.expectEmit(true, false, false, false);
        emit LogMessagePublished(WORMHOLE_RELAYER, 2105, 0, requestPayload, 15);
        changePrank(actor.bob_channel_owner);
        commProxy.createIncentivizedChatRequest{ value: 1e18 }(_payload, amount, 10_000_000);
    }

    modifier whenReceiveFunctionIsCalledInCore() {
        _;
    }

    function test_WhenSenderIsNotRegistered() external whenReceiveFunctionIsCalledInCore {
        // it should Revert
        test_WhenAllChecksPasses();

        setUpChain2(EthSepolia);
        //set sender to zero address
        coreProxy.setRegisteredSender(chainId1, toWormholeFormat(address(0)));

        vm.expectRevert("Not registered sender");
        changePrank(WORMHOLE_RELAYER_SEPOLIA);
        coreProxy.receiveWormholeMessages(requestPayload, additionalVaas, sourceAddress, sourceChain, deliveryHash);
    }

    function test_WhenSenderIsNotRelayer() external whenReceiveFunctionIsCalledInCore {
        // it should Revert
        test_WhenAllChecksPasses();

        setUpChain2(EthSepolia);
        coreProxy.setWormholeRelayer(address(0));
        changePrank(WORMHOLE_RELAYER_SEPOLIA);
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotAdmin.selector));
        coreProxy.receiveWormholeMessages(requestPayload, additionalVaas, sourceAddress, sourceChain, deliveryHash);
    }

    function test_WhenDeliveryHashIsUsedAlready() external whenReceiveFunctionIsCalledInCore {
        // it should Revert
        test_WhenAllChecksPasses();

        setUpChain2(EthSepolia);
        changePrank(WORMHOLE_RELAYER_SEPOLIA);
        coreProxy.receiveWormholeMessages(requestPayload, additionalVaas, sourceAddress, sourceChain, deliveryHash);
        vm.expectRevert(abi.encodeWithSelector(Errors.Payload_Duplicacy_Error.selector));
        coreProxy.receiveWormholeMessages(requestPayload, additionalVaas, sourceAddress, sourceChain, deliveryHash);
    }

    function test_WhenAllChecksPass() external whenReceiveFunctionIsCalledInCore {
        // it should emit event and create Channel

        setUpChain2(EthSepolia);

        uint256 poolFeeAmount = coreProxy.FEE_AMOUNT();
        uint256 userFundsPre = coreProxy.celebUserFunds(actor.charlie_channel_owner);
        uint256 PROTOCOL_POOL_FEES = coreProxy.PROTOCOL_POOL_FEES();

        changePrank(WORMHOLE_RELAYER_SEPOLIA);

        vm.expectEmit(false, false, false, true);
        emit IncentivizeChatReqReceived(
            actor.bob_channel_owner, actor.charlie_channel_owner, amount - poolFeeAmount, poolFeeAmount, block.timestamp
        );

        coreProxy.receiveWormholeMessages(requestPayload, additionalVaas, sourceAddress, sourceChain, deliveryHash);

        assertEq(coreProxy.celebUserFunds(actor.charlie_channel_owner), userFundsPre + amount - poolFeeAmount);
        assertEq(coreProxy.PROTOCOL_POOL_FEES(), PROTOCOL_POOL_FEES + poolFeeAmount);
    }
}
