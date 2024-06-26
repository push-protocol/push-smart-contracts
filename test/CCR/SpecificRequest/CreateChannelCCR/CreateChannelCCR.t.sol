// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseCCRTest } from "../../BaseCCR.t.sol";
import { CoreTypes, CrossChainRequestTypes } from "../../../../contracts/libraries/DataTypes.sol";
import { Errors } from ".././../../../contracts/libraries/Errors.sol";
import { console } from "forge-std/console.sol";

contract CreateChannelCCR is BaseCCRTest {
    uint256 amount = ADD_CHANNEL_MIN_FEES;

    CrossChainRequestTypes.SpecificRequestPayload _payload;
    bytes requestPayload;

    bytes[] additionalVaas;
    bytes32 sourceAddress;
    uint16 sourceChain = chainId1;
    bytes32 deliveryHash = 0x97f309914aa8b670f4a9212ba06670557b0c92a7ad853b637be8a9a6c2ea6447;

    function setUp() public override {
        BaseCCRTest.setUp();
        sourceAddress = toWormholeFormat(address(commProxy));
        (_payload, requestPayload) = getSpecificPayload(
            coreProxy.createChannelWithPUSH.selector, address(0), amount, "channleStr"
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
        commProxy.createChannel(_payload, amount, 10_000_000);
    }

    function test_RevertWhen_AmountIsLessThanMinimumFees() external whenCreateChannelIsCalled {
        // it should revert
        amount = 49e18;
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidArg_LessThanExpected.selector, ADD_CHANNEL_MIN_FEES, amount)
        );
        changePrank(actor.bob_channel_owner);
        commProxy.createChannel(_payload, amount, 10_000_000);
    }

    function test_RevertWhen_EtherPassedIsLess() external whenCreateChannelIsCalled {
        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientFunds.selector));
        changePrank(actor.bob_channel_owner);
        commProxy.createChannel(_payload, amount, 10_000_000);
    }

    function test_WhenAllChecksPasses() public whenCreateChannelIsCalled {
        // it should successfully create the CCR

        vm.expectEmit(true, false, false, false);
        emit LogMessagePublished(WORMHOLE_RELAYER, 2105, 0, requestPayload, 15);
        changePrank(actor.bob_channel_owner);
        commProxy.createChannel{ value: 1e18 }(_payload, amount, 10_000_000);
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

        test_WhenAllChecksPasses();

        setUpChain2(EthSepolia);

        changePrank(WORMHOLE_RELAYER_SEPOLIA);

        (uint256 poolFunds, uint256 poolFees) = getPoolFundsAndFees(amount);

        vm.expectEmit(true, true, false, true);
        emit ChannelCreated(
            toWormholeFormat(actor.bob_channel_owner),
            CoreTypes.ChannelType.InterestBearingMutual,
            _testChannelUpdatedIdentity
        );


        coreProxy.receiveWormholeMessages(requestPayload, additionalVaas, sourceAddress, sourceChain, deliveryHash);
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
        ) = coreProxy.channelInfo(toWormholeFormat(actor.bob_channel_owner));

        assertEq(uint8(channelType), uint8(CoreTypes.ChannelType.InterestBearingMutual),"channel Type");
        assertEq(channelState, 1,"channel State");
        assertEq(poolContribution, amount - coreProxy.FEE_AMOUNT(), "Pool Contribution");
        assertEq(channelStartBlock, block.number, "Channel Start Block");
        assertEq(channelUpdateBlock, block.number, "Chanel Update Block");
        assertEq(channelWeight, ((amount - coreProxy.FEE_AMOUNT())* 10 ** 7) / coreProxy.MIN_POOL_CONTRIBUTION(), "Channel Weight");
    }
}
