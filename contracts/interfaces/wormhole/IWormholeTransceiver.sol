// SPDX-License-Identifier: Apache 2
pragma solidity ^0.8.20;

import "./ITransceiver.sol";

interface IWormholeTransceiver is ITransceiver {
    /// @notice The instruction for the WormholeTransceiver contract
    ///         to skip delivery via the relayer.
    struct WormholeTransceiverInstruction {
        bool shouldSkipRelayerSend;
    }

    /// @notice Encodes the `WormholeTransceiverInstruction` into a byte array.
    /// @param instruction The `WormholeTransceiverInstruction` to encode.
    /// @return encoded The encoded instruction.
    function encodeWormholeTransceiverInstruction(WormholeTransceiverInstruction memory instruction)
        external
        pure
        returns (bytes memory);

    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory additionalMessages,
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 deliveryHash
    )
        external
        payable;
}
