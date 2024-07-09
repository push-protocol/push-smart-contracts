// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.0;

// import { BaseCCRTest } from "../BaseCCR.t.sol";
// import { CoreTypes } from "../../../../contracts/libraries/DataTypes.sol";
// import { Errors } from ".././../../../contracts/libraries/Errors.sol";
// import { console } from "forge-std/console.sol";

// import { INttManager } from "./../../../../contracts/interfaces/wormhole/INttManager.sol";
// import {WormholeSimulator} from "wormhole-solidity-sdk/testing/helpers/WormholeSimulator.sol";
// import {IWormhole} from "wormhole-solidity-sdk/interfaces/IWormhole.sol";

// import {Vm} from "forge-std/Vm.sol";

// import {TransceiverStructs} from "./../../../contracts/libraries/wormhole-lib/TransceiverStructs.sol";
// import "./../../../contracts/libraries/wormhole-lib/TrimmedAmount.sol";
// contract CreateChannelCCR is BaseCCRTest {
//     // using TrimmedAmount for TrimmedAmount;
//     uint256 constant DEVNET_GUARDIAN_PK =
//         0xedc2d60cdb193aac203bea0be0f5f1b016bf4381f92231ca0320fc01a57bcae5;
//     WormholeSimulator guardian;

//     function setUp() public override {
//         BaseCCRTest.setUp();
//         sourceAddress = toWormholeFormat(address(commProxy));

//     }
//     function test_tokenTransferSuccessful() external {
//         // test_WhenAllChecksPasses();
//         vm.deal(ArbSepolia.PushHolder, 1e18);
//         vm.recordLogs();
//         changePrank(ArbSepolia.PushHolder);
//         pushNttToken.approve(address(ArbSepolia.NTT_MANAGER), 100e18);

//         INttManager(ArbSepolia.NTT_MANAGER).transfer{ value:  12260834040000 }(
//             100e18,
//             EthSepolia.DestChainId,
//             toWormholeFormat(actor.bob_channel_owner)
//         );


//         vm.allowCheatcodes(0x4ffC7624ED9810967c5bB8491e4F6748c41C56A5);
//         guardian = new WormholeSimulator(address(ArbSepolia.wormhole), DEVNET_GUARDIAN_PK);

//         bytes[] memory encodedVMs = _getWormholeMessage(guardian, vm.getRecordedLogs(), ArbSepolia.SourceChainId);
//         IWormhole.VM memory vaa = ArbSepolia.wormhole.parseVM(encodedVMs[0]);

//         setUpChain2(EthSepolia.rpc);

//         bytes[] memory a;
//         changePrank(EthSepolia.WORMHOLE_RELAYER_DEST);
//         EthSepolia.wormholeTransceiverChain2.receiveWormholeMessages(
//             vaa.payload, // Verified
//             a, // Should be zero
//             bytes32(uint256(uint160(address(ArbSepolia.wormholeTransceiverChain1)))), // Must be a wormhole peers
//             vaa.emitterChainId, // ChainID from the call
//             vaa.hash // Hash of the VAA being used
//         );

//     }

//     function _getWormholeMessage(
//         WormholeSimulator _guardian,
//         Vm.Log[] memory logs,
//         uint16 emitterChain
//     ) internal view returns (bytes[] memory) {
//         Vm.Log[] memory entries = _guardian.fetchWormholeMessageFromLog(logs);
//         bytes[] memory encodedVMs = new bytes[](entries.length);
//         for (uint256 i = 0; i < encodedVMs.length; i++) {
//             encodedVMs[i] = _guardian.fetchSignedMessageFromLogs(entries[i], emitterChain);
//         }

//         return encodedVMs;
//     }
// }
