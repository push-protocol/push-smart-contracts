// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseCCRTest } from "../BaseCCR.t.sol";

import { console } from "forge-std/console.sol";

import {WormholeSimulator} from "wormhole-solidity-sdk/testing/helpers/WormholeSimulator.sol";
import {TransceiverStructs} from "./../../../contracts/libraries/wormhole-lib/TransceiverStructs.sol";
import "./../../../contracts/libraries/wormhole-lib/TrimmedAmount.sol";
contract CreateChannelCCR is BaseCCRTest {
    // using TrimmedAmount for TrimmedAmount;
    uint256 constant DEVNET_GUARDIAN_PK =
        0xedc2d60cdb193aac203bea0be0f5f1b016bf4381f92231ca0320fc01a57bcae5;
    WormholeSimulator guardian;

    function setUp() public override {
        BaseCCRTest.setUp();
        sourceAddress = toWormholeFormat(address(commProxy));

    }
    function test_tokenTransferSuccessful() external {
        setUpDestChain(EthSepolia.rpc);


        bytes[] memory a;
        TrimmedAmount _amt = _trimTransferAmount(100e18);
        bytes memory tokenTransferMessage = TransceiverStructs.encodeNativeTokenTransfer(
            TransceiverStructs.NativeTokenTransfer({
                amount: _amt,
                sourceToken: toWormholeFormat(address(ArbSepolia.PUSH_NTT_SOURCE)),
                to: toWormholeFormat(actor.bob_channel_owner),
                toChain: EthSepolia.DestChainId
            })
        );

        console.log(pushNttToken.balanceOf(actor.bob_channel_owner));
        console.log(pushNttToken.balanceOf(actor.bob_channel_owner));
        
        bytes memory transceiverMessage;
        TransceiverStructs.NttManagerMessage memory nttManagerMessage;
        (nttManagerMessage, transceiverMessage) = buildTransceiverMessageWithNttManagerPayload(
            0,
            toWormholeFormat(address(ArbSepolia.PushHolder)),
            toWormholeFormat(ArbSepolia.NTT_MANAGER),
            toWormholeFormat(EthSepolia.NTT_MANAGER),
            tokenTransferMessage
        );
        bytes32 hash = TransceiverStructs.nttManagerMessageDigest(
            10003, nttManagerMessage
        );
        changePrank(EthSepolia.WORMHOLE_RELAYER_DEST);
        EthSepolia.wormholeTransceiverChain2.receiveWormholeMessages(
            transceiverMessage, // Verified
            a, // Should be zero
            bytes32(uint256(uint160(address(ArbSepolia.wormholeTransceiverChain1)))), // Must be a wormhole peers
            10003, // ChainID from the call
            hash // Hash of the VAA being used
        );

        console.log(pushNttToken.balanceOf(actor.bob_channel_owner));

    }
}
