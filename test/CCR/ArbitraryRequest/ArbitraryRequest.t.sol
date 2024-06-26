// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseCCRTest } from "../BaseCCR.t.sol";
import { CoreTypes, CrossChainRequestTypes } from "../../../../contracts/libraries/DataTypes.sol";
import { Errors } from ".././../../../contracts/libraries/Errors.sol";
import { console } from "forge-std/console.sol";
import "../../../../contracts/interfaces/wormhole/IWormholeRelayer.sol";
import { WormholeSimulator } from "wormhole-solidity-sdk/testing/helpers/WormholeSimulator.sol";
import { IWormhole } from "wormhole-solidity-sdk/interfaces/IWormhole.sol";
import { IWormholeTransceiver } from "./../../../../contracts/interfaces/wormhole/IWormholeTransceiver.sol";
import { Vm } from "forge-std/Vm.sol";

contract ArbitraryRequesttsol is BaseCCRTest {
    uint256 amount = 100e18;

    CrossChainRequestTypes.ArbitraryRequestPayload _payload;
    bytes requestPayload;

    bytes[] additionalVaas;
    bytes32 sourceAddress;
    uint16 sourceChain = chainId1;
    bytes32 deliveryHash = 0x97f309914aa8b670f4a9212ba06670557b0c92a7ad853b637be8a9a6c2ea6447;

    function setUp() public override {
        BaseCCRTest.setUp();
        sourceAddress = toWormholeFormat(address(commProxy));
        (_payload, requestPayload) = getArbitraryPayload(0x00000000, 1, 20, actor.charlie_channel_owner, amount);
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
        commProxy.createRequestWithFeeId(_payload, amount, 10_000_000);
    }

    function test_RevertWhen_AmountNotGreaterThanZero() external whenCreateRequestWithFeeIdIsCalled {
        // it should revert
        vm.expectRevert("Invalid Amount");
        changePrank(actor.bob_channel_owner);
        commProxy.createRequestWithFeeId(_payload, amount - amount, 10_000_000);
    }

    function test_RevertWhen_FeePercentageIsGreaterThanHundred() external whenCreateRequestWithFeeIdIsCalled {
        // it should revert
        (_payload,) = getArbitraryPayload(0x00000000, 1, 20 + 100, actor.charlie_channel_owner, amount);

        vm.expectRevert("Invalid Fee Percentage");
        changePrank(actor.bob_channel_owner);
        commProxy.createRequestWithFeeId(_payload, amount, 10_000_000);
    }

    function test_RevertWhen_EtherPassedIsLess() external whenCreateRequestWithFeeIdIsCalled {
        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientFunds.selector));
        changePrank(actor.bob_channel_owner);
        commProxy.createRequestWithFeeId(_payload, amount, 10_000_000);
    }

    function test_WhenAllChecksPasses() public whenCreateRequestWithFeeIdIsCalled {
        // it should successfully create the CCR
        vm.expectEmit(true, false, false, false);
        emit LogMessagePublished(WORMHOLE_RELAYER, 2105, 0, requestPayload, 15);
        changePrank(actor.bob_channel_owner);
        commProxy.createRequestWithFeeId{ value: 1e18 }(_payload, amount, 10_000_000);
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

        setUpChain2(EthSepolia);

        changePrank(WORMHOLE_RELAYER_SEPOLIA);
        coreProxy.receiveWormholeMessages(requestPayload, additionalVaas, sourceAddress, sourceChain, deliveryHash);
        vm.expectRevert(abi.encodeWithSelector(Errors.Payload_Duplicacy_Error.selector));
        coreProxy.receiveWormholeMessages(requestPayload, additionalVaas, sourceAddress, sourceChain, deliveryHash);
    }

    function test_WhenAllChecksPass() external whenReceiveFunctionIsCalledInCore {
        // it should emit event and update storage
        test_WhenAllChecksPasses();

        setUpChain2(EthSepolia);
        uint256 PROTOCOL_POOL_FEES = coreProxy.PROTOCOL_POOL_FEES();
        uint256 arbitraryFees = coreProxy.arbitraryReqFees(actor.charlie_channel_owner);
        changePrank(WORMHOLE_RELAYER_SEPOLIA);

        (uint256 poolFunds, uint256 poolFees) = getPoolFundsAndFees(amount);

        vm.expectEmit(true, true, false, true);
        emit ArbitraryRequest(actor.bob_channel_owner, actor.charlie_channel_owner, amount, 20, 1);

        coreProxy.receiveWormholeMessages(requestPayload, additionalVaas, sourceAddress, sourceChain, deliveryHash);

        uint256 feeAmount = amount * 20 / 100;

        // Update states based on Fee Percentage calculation
        assertEq(coreProxy.PROTOCOL_POOL_FEES(), PROTOCOL_POOL_FEES + feeAmount);
        assertEq(coreProxy.arbitraryReqFees(actor.charlie_channel_owner), arbitraryFees + amount - feeAmount);
    }
}
