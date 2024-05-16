// SPDX-License-Identifier: Apache 2
pragma solidity >=0.8.8 <0.9.0;

import "../../libraries/wormhole-lib/TransceiverStructs.sol";

interface ITransceiver {
    /// @notice Fetch the delivery price for a given recipient chain transfer.
    /// @param recipientChain The Wormhole chain ID of the target chain.
    /// @param instruction An additional Instruction provided by the Transceiver to be
    ///        executed on the recipient chain.
    /// @return deliveryPrice The cost of delivering a message to the recipient chain,
    ///         in this chain's native token.
    function quoteDeliveryPrice(
        uint16 recipientChain,
        TransceiverStructs.TransceiverInstruction memory instruction
    )
        external
        view
        returns (uint256);
}
