// SPDX-License-Identifier: Apache 2
pragma solidity ^0.8.20;

interface IWormholeTransceiver {
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
}
