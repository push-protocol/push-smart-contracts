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
    bytes4 functionSig = 0x00000000;
    uint8 feeId = 1;
    uint8 feePercentage = 20;

    address amountRecipient = actor.charlie_channel_owner;
    uint256 amount = 100e18;

    CrossChainRequestTypes.ArbitraryRequestPayload _payload = CrossChainRequestTypes.ArbitraryRequestPayload(
        functionSig, feeId, feePercentage, actor.charlie_channel_owner, amount
    );

    function setUp() public override {
        BaseCCRTest.setUp();
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
        _payload =
            CrossChainRequestTypes.ArbitraryRequestPayload(functionSig, feeId, 101, actor.charlie_channel_owner, amount);
        vm.expectRevert("Invalid Fee Percentage");
        changePrank(actor.bob_channel_owner);
        commProxy.createRequestWithFeeId(_payload, amount, 10_000_000);
    }

    function test_RevertWhen_EtherPassedIsLess() external whenCreateRequestWithFeeIdIsCalled {
        // it should revert
    }

    function test_WhenAllChecksPasses() external whenCreateRequestWithFeeIdIsCalled {
        // it should successfully create the CCR
    }

    function test_WhenTheCoreContractReceivesAccurateData() external whenCreateRequestWithFeeIdIsCalled {
        // it should execute the requested function
    }
}
