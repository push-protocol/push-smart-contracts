// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseCCRTest } from "../BaseCCR.t.sol";
import { Errors } from ".././../../../contracts/libraries/Errors.sol";
import { console } from "forge-std/console.sol";

import { Vm } from "forge-std/Vm.sol";

contract ArbitraryRequesttsol is BaseCCRTest {
    uint256 amount = 100e18;

    function setUp() public override {
        BaseCCRTest.setUp();
        (_arbitraryPayload, requestPayload) = getArbitraryPayload(0x00000000, 1, 20, actor.charlie_channel_owner, amount);
    }

    modifier whenCreateRequestWithFeeIdIsCalled() {
        _;
    }

    function test_WhenContractIsPaused() external whenCreateRequestWithFeeIdIsCalled {
        // it should Revert
        changePrank(actor.admin);
        commProxy.pauseContract();
        vm.expectRevert("Pausable: paused");
        changePrank(actor.bob_channel_owner);
        commProxy.createRequestWithFeeId(_arbitraryPayload, amount, 10_000_000);
    }

    function test_RevertWhen_AmountNotGreaterThanZero() external whenCreateRequestWithFeeIdIsCalled {
        // it should revert
        vm.expectRevert("Invalid Amount");
        changePrank(actor.bob_channel_owner);
        commProxy.createRequestWithFeeId(_arbitraryPayload, amount - amount, 10_000_000);
    }

    function test_RevertWhen_FeePercentageIsGreaterThanHundred() external whenCreateRequestWithFeeIdIsCalled {
        // it should revert
        (_arbitraryPayload,) = getArbitraryPayload(0x00000000, 1, 20 + 100, actor.charlie_channel_owner, amount);

        vm.expectRevert("Invalid Fee Percentage");
        changePrank(actor.bob_channel_owner);
        commProxy.createRequestWithFeeId(_arbitraryPayload, amount, 10_000_000);
    }

    function test_RevertWhen_EtherPassedIsLess() external whenCreateRequestWithFeeIdIsCalled {
        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientFunds.selector));
        changePrank(actor.bob_channel_owner);
        commProxy.createRequestWithFeeId(_arbitraryPayload, amount, 10_000_000);
    }

    function test_WhenAllChecksPasses() public whenCreateRequestWithFeeIdIsCalled {
        // it should successfully create the CCR
        vm.expectEmit(true, false, false, false);
        emit LogMessagePublished(ArbSepolia.WORMHOLE_RELAYER_SOURCE, 2105, 0, requestPayload, 15);
        changePrank(actor.bob_channel_owner);
        commProxy.createRequestWithFeeId{ value: 1e18 }(_arbitraryPayload, amount, 10_000_000);
    }

    modifier whenReceiveFunctionIsCalledInCore() {
        _;
    }

    function test_WhenSenderIsNotRegistered() external whenReceiveFunctionIsCalledInCore {
        // it should Revert
        test_WhenAllChecksPasses();

        setUpChain2(EthSepolia.rpc);
        //set sender to zero address
        coreProxy.setRegisteredSender(ArbSepolia.SourceChainId, toWormholeFormat(address(0)));

        vm.expectRevert("Not registered sender");
        changePrank(EthSepolia.WORMHOLE_RELAYER_DEST);
        coreProxy.receiveWormholeMessages(requestPayload, additionalVaas, sourceAddress, ArbSepolia.SourceChainId, deliveryHash);
    }

    function test_WhenSenderIsNotRelayer() external whenReceiveFunctionIsCalledInCore {
        // it should Revert
        test_WhenAllChecksPasses();

        setUpChain2(EthSepolia.rpc);
        coreProxy.setWormholeRelayer(address(0));
        changePrank(EthSepolia.WORMHOLE_RELAYER_DEST);
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotAdmin.selector));
        coreProxy.receiveWormholeMessages(requestPayload, additionalVaas, sourceAddress, ArbSepolia.SourceChainId, deliveryHash);
    }

    function test_WhenDeliveryHashIsUsedAlready() external whenReceiveFunctionIsCalledInCore {
        // it should Revert

        setUpChain2(EthSepolia.rpc);

        changePrank(EthSepolia.WORMHOLE_RELAYER_DEST);
        coreProxy.receiveWormholeMessages(requestPayload, additionalVaas, sourceAddress, ArbSepolia.SourceChainId, deliveryHash);
        vm.expectRevert(abi.encodeWithSelector(Errors.Payload_Duplicacy_Error.selector));
        coreProxy.receiveWormholeMessages(requestPayload, additionalVaas, sourceAddress, ArbSepolia.SourceChainId, deliveryHash);
    }

    function test_WhenAllChecksPass() external whenReceiveFunctionIsCalledInCore {
        // it should emit event and update storage
        test_WhenAllChecksPasses();

        setUpChain2(EthSepolia.rpc);
        uint256 PROTOCOL_POOL_FEES = coreProxy.PROTOCOL_POOL_FEES();
        uint256 arbitraryFees = coreProxy.arbitraryReqFees(actor.charlie_channel_owner);
        changePrank(EthSepolia.WORMHOLE_RELAYER_DEST);

        (uint256 poolFunds, uint256 poolFees) = getPoolFundsAndFees(amount);

        vm.expectEmit(true, true, false, true);
        emit ArbitraryRequest(actor.bob_channel_owner, actor.charlie_channel_owner, amount, 20, 1);

        coreProxy.receiveWormholeMessages(requestPayload, additionalVaas, sourceAddress, ArbSepolia.SourceChainId, deliveryHash);

        uint256 feeAmount = amount * 20 / 100;

        // Update states based on Fee Percentage calculation
        assertEq(coreProxy.PROTOCOL_POOL_FEES(), PROTOCOL_POOL_FEES + feeAmount);
        assertEq(coreProxy.arbitraryReqFees(actor.charlie_channel_owner), arbitraryFees + amount - feeAmount);
    }
}
