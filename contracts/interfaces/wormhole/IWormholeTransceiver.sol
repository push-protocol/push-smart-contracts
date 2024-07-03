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

    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory additionalMessages,
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 deliveryHash
    ) external payable;

    function setWormholePeer(uint16 chainId, bytes32 peerContract) external payable;
    function setIsWormholeEvmChain(uint16 chainId, bool isEvm) external;
}
