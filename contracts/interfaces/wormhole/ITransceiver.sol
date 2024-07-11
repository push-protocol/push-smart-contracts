// SPDX-License-Identifier: Apache 2
pragma solidity >=0.8.8 <0.9.0;

import "../../libraries/wormhole-lib/TransceiverStructs.sol";

interface ITransceiver {
    /// @notice The caller is not the deployer.
    /// @dev Selector: 0xc68a0e42.
    /// @param deployer The address of the deployer.
    /// @param caller The address of the caller.
    error UnexpectedDeployer(address deployer, address caller);

    /// @notice The caller is not the NttManager.
    /// @dev Selector: 0xc5aa6153.
    /// @param caller The address of the caller.
    error CallerNotNttManager(address caller);

    /// @notice Error when trying renounce transceiver ownership.
    ///         Ensures the owner of the transceiver is in sync with
    ///         the owner of the NttManager.
    /// @dev Selector: 0x66791dd6.
    /// @param currentOwner he current owner of the transceiver.
    error CannotRenounceTransceiverOwnership(address currentOwner);

    /// @notice Error when trying to transfer transceiver ownership.
    /// @dev Selector: 0x306239eb.
    /// @param currentOwner The current owner of the transceiver.
    /// @param newOwner The new owner of the transceiver.
    error CannotTransferTransceiverOwnership(address currentOwner, address newOwner);

    /// @notice Error when the recipient NttManager address is not the
    ///         corresponding manager of the transceiver.
    /// @dev Selector: 0x73bdd322.
    /// @param recipientNttManagerAddress The address of the recipient NttManager.
    /// @param expectedRecipientNttManagerAddress The expected address of the recipient NttManager.
    error UnexpectedRecipientNttManagerAddress(
        bytes32 recipientNttManagerAddress, bytes32 expectedRecipientNttManagerAddress
    );

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

    /// @dev Send a message to another chain.
    /// @param recipientChain The Wormhole chain ID of the recipient.
    /// @param instruction An additional Instruction provided by the Transceiver to be
    /// executed on the recipient chain.
    /// @param nttManagerMessage A message to be sent to the nttManager on the recipient chain.
    function sendMessage(
        uint16 recipientChain,
        TransceiverStructs.TransceiverInstruction memory instruction,
        bytes memory nttManagerMessage,
        bytes32 recipientNttManagerAddress,
        bytes32 refundAddress
    )
        external
        payable;

    /// @notice Upgrades the transceiver to a new implementation.
    function upgrade(address newImplementation) external;

    /// @notice Transfers the ownership of the transceiver to a new address.
    function transferTransceiverOwnership(address newOwner) external;
}
