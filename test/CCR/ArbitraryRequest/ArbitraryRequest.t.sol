// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import {BaseCCRTest} from "../BaseCCR.t.sol";
import {CoreTypes, CrossChainRequestTypes} from "../../../../contracts/libraries/DataTypes.sol";
import {Errors} from ".././../../../contracts/libraries/Errors.sol";
import {console} from "forge-std/console.sol";
import "../../../../contracts/interfaces/wormhole/IWormholeRelayer.sol";
import {WormholeSimulator} from "wormhole-solidity-sdk/testing/helpers/WormholeSimulator.sol";
import {IWormhole} from "wormhole-solidity-sdk/interfaces/IWormhole.sol";
import {IWormholeTransceiver} from "./../../../../contracts/interfaces/wormhole/IWormholeTransceiver.sol";
import {Vm} from "forge-std/Vm.sol";

contract ArbitraryRequesttsol is BaseCCRTest {

         bytes4 functionSig;
        uint8 feeId;
        uint8 feePercentage;
        
        
    address amountRecipient = actor.charlie_channel_owner;
    uint256 amount = ADD_CHANNEL_MIN_FEES;

    CrossChainRequestTypes.ArbitraryRequestPayload _payload =
        CrossChainRequestTypes.ArbitraryRequestPayload(
            functionSig,
            feeId,
            feePercentage,
            actor.charlie_channel_owner,
            amount
    
        );

    function setUp() public override {
        BaseCCRTest.setUp();
    }

    modifier whenCreateRequestWithFeeIdIsCalled() {
        _;
    }

    function test_WhenContractIsPaused() external whenCreateRequestWithFeeIdIsCalled {
        // it should Revert
    }

    function test_RevertWhen_AmountNotGreaterThanZero() external whenCreateRequestWithFeeIdIsCalled {
        // it should revert
    }

    function test_RevertWhen_FeePercentageIsGreaterThanHundred() external whenCreateRequestWithFeeIdIsCalled {
        // it should revert
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