// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseCCRTest } from "../BaseCCR.t.sol";

import { console } from "forge-std/console.sol";

import { WormholeSimulator } from "wormhole-solidity-sdk/testing/helpers/WormholeSimulator.sol";
import "./../../../contracts/libraries/wormhole-lib/TrimmedAmount.sol";
import { INttManager } from "./../../../contracts/interfaces/wormhole/INttManager.sol";

import { Vm } from "forge-std/Vm.sol";

contract NttTransfer_Test is BaseCCRTest {
    // using TrimmedAmount for TrimmedAmount;
    uint256 constant DEVNET_GUARDIAN_PK = 0xedc2d60cdb193aac203bea0be0f5f1b016bf4381f92231ca0320fc01a57bcae5;
    WormholeSimulator guardian;

    function setUp() public override {
        BaseCCRTest.setUp();
        sourceAddress = toWormholeFormat(address(commProxy));
    }

    function test_tokenTransferSuccessful() external {
        vm.deal(SourceChain.PushHolder, 1e18);
        vm.recordLogs();
        changePrank(SourceChain.PushHolder);
        pushNttToken.approve(address(SourceChain.NTT_MANAGER), 100e18);

        uint256 costOfTransfer = commProxy.quoteTokenBridgingCost();

        INttManager(SourceChain.NTT_MANAGER).transfer{ value: costOfTransfer }(
            100e18, DestChain.DestChainId, toWormholeFormat(actor.bob_channel_owner)
        );
        (address sourceNttManager, bytes32 recipient, uint256 _amount, uint16 recipientChain) =
            getMessagefromLog(vm.getRecordedLogs());

        setUpDestChain();
        bytes[] memory a;

        (bytes memory transceiverMessage, bytes32 hash) =
            getRequestPayload(_amount, recipient, recipientChain, sourceNttManager);

        changePrank(DestChain.WORMHOLE_RELAYER_DEST);
        DestChain.wormholeTransceiverChain2.receiveWormholeMessages(
            transceiverMessage, // Verified
            a, // Should be zero
            bytes32(uint256(uint160(address(SourceChain.wormholeTransceiverChain1)))), // Must be a wormhole peers
            SourceChain.SourceChainId, // ChainID from the call
            hash // Hash of the VAA being used
        );

        console.log(pushNttToken.balanceOf(actor.bob_channel_owner));
    }
}
