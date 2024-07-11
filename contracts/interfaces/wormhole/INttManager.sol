// SPDX-License-Identifier: Apache 2
pragma solidity ^0.8.20;

import "../../libraries/wormhole-lib/TransceiverStructs.sol";
import "../../libraries/wormhole-lib/TrimmedAmount.sol";

import "./IManagerBase.sol";

interface INttManager is IManagerBase {
    /// @dev The peer on another chain.
    struct NttManagerPeer {
        bytes32 peerAddress;
        uint8 tokenDecimals;
    }

    /// @notice Emitted when a message is sent from the nttManager.
    /// @dev Topic0
    ///      0xe54e51e42099622516fa3b48e9733581c9dbdcb771cafb093f745a0532a35982.
    /// @param recipient The recipient of the message.
    /// @param refundAddress The address on the destination chain to which the
    ///                      refund of unused gas will be paid
    /// @param amount The amount transferred.
    /// @param fee The amount of ether sent along with the tx to cover the delivery fee.
    /// @param recipientChain The chain ID of the recipient.
    /// @param msgSequence The unique sequence ID of the message.
    event TransferSent(
        bytes32 recipient, bytes32 refundAddress, uint256 amount, uint256 fee, uint16 recipientChain, uint64 msgSequence
    );

    /// @notice Emitted when the peer contract is updated.
    /// @dev Topic0
    ///      0x1456404e7f41f35c3daac941bb50bad417a66275c3040061b4287d787719599d.
    /// @param chainId_ The chain ID of the peer contract.
    /// @param oldPeerContract The old peer contract address.
    /// @param oldPeerDecimals The old peer contract decimals.
    /// @param peerContract The new peer contract address.
    /// @param peerDecimals The new peer contract decimals.
    event PeerUpdated(
        uint16 indexed chainId_,
        bytes32 oldPeerContract,
        uint8 oldPeerDecimals,
        bytes32 peerContract,
        uint8 peerDecimals
    );

    /// @notice Emitted when a transfer has been redeemed
    ///         (either minted or unlocked on the recipient chain).
    /// @dev Topic0
    ///      0x504e6efe18ab9eed10dc6501a417f5b12a2f7f2b1593aed9b89f9bce3cf29a91.
    /// @param digest The digest of the message.
    event TransferRedeemed(bytes32 indexed digest);

    /// @notice Emitted when an outbound transfer has been cancelled
    /// @dev Topic0
    ///      0xf80e572ae1b63e2449629b6c7d783add85c36473926f216077f17ee002bcfd07.
    /// @param sequence The sequence number being cancelled
    /// @param recipient The canceller and recipient of the funds
    /// @param amount The amount of the transfer being cancelled
    event OutboundTransferCancelled(uint256 sequence, address recipient, uint256 amount);

    /// @notice The transfer has some dust.
    /// @dev Selector 0x71f0634a
    /// @dev This is a security measure to prevent users from losing funds.
    ///      This is the result of trimming the amount and then untrimming it.
    /// @param  amount The amount to transfer.
    error TransferAmountHasDust(uint256 amount, uint256 dust);

    /// @notice The mode is invalid. It is neither in LOCKING or BURNING mode.
    /// @dev Selector 0x66001a89
    /// @param mode The mode.
    error InvalidMode(uint8 mode);

    /// @notice Error when trying to execute a message on an unintended target chain.
    /// @dev Selector 0x3dcb204a.
    /// @param targetChain The target chain.
    /// @param thisChain The current chain.
    error InvalidTargetChain(uint16 targetChain, uint16 thisChain);

    /// @notice Error when the transfer amount is zero.
    /// @dev Selector 0x9993626a.
    error ZeroAmount();

    /// @notice Error when the recipient is invalid.
    /// @dev Selector 0x9c8d2cd2.
    error InvalidRecipient();

    /// @notice Error when the recipient is invalid.
    /// @dev Selector 0xe2fe2726.
    error InvalidRefundAddress();

    /// @notice Error when the amount burned is different than the balance difference,
    ///         since NTT does not support burn fees.
    /// @dev Selector 0x02156a8f.
    /// @param burnAmount The amount burned.
    /// @param balanceDiff The balance after burning.
    error BurnAmountDifferentThanBalanceDiff(uint256 burnAmount, uint256 balanceDiff);

    /// @notice The caller is not the deployer.
    error UnexpectedDeployer(address expectedOwner, address owner);

    /// @notice Peer for the chain does not match the configuration.
    /// @param chainId ChainId of the source chain.
    /// @param peerAddress Address of the peer nttManager contract.
    error InvalidPeer(uint16 chainId, bytes32 peerAddress);

    /// @notice Peer chain ID cannot be zero.
    error InvalidPeerChainIdZero();

    /// @notice Peer cannot be the zero address.
    error InvalidPeerZeroAddress();

    /// @notice Peer cannot have zero decimals.
    error InvalidPeerDecimals();

    /// @notice Staticcall reverted
    /// @dev Selector 0x1222cd83
    error StaticcallFailed();

    /// @notice Error when someone other than the original sender tries to cancel a queued outbound transfer.
    /// @dev Selector 0xceb40a85.
    /// @param canceller The address trying to cancel the transfer.
    /// @param sender The original sender that initiated the transfer that was queued.
    error CancellerNotSender(address canceller, address sender);

    /// @notice An unexpected msg.value was passed with the call
    /// @dev Selector 0xbd28e889.
    error UnexpectedMsgValue();

    /// @notice Peer cannot be on the same chain
    /// @dev Selector 0x20371f2a.
    error InvalidPeerSameChainId();

    /// @notice Transfer a given amount to a recipient on a given chain. This function is called
    ///         by the user to send the token cross-chain. This function will either lock or burn the
    ///         sender's tokens. Finally, this function will call into registered `Endpoint` contracts
    ///         to send a message with the incrementing sequence number and the token transfer payload.
    /// @param amount The amount to transfer.
    /// @param recipientChain The chain ID for the destination.
    /// @param recipient The recipient address.
    function transfer(
        uint256 amount,
        uint16 recipientChain,
        bytes32 recipient
    )
        external
        payable
        returns (uint64 msgId);

    /// @notice Transfer a given amount to a recipient on a given chain. This function is called
    ///         by the user to send the token cross-chain. This function will either lock or burn the
    ///         sender's tokens. Finally, this function will call into registered `Endpoint` contracts
    ///         to send a message with the incrementing sequence number and the token transfer payload.
    /// @dev Transfers are queued if the outbound limit is hit and must be completed by the client.
    /// @param amount The amount to transfer.
    /// @param recipientChain The chain ID for the destination.
    /// @param recipient The recipient address.
    /// @param refundAddress The address to which a refund for unussed gas is issued on the recipient chain.
    /// @param shouldQueue Whether the transfer should be queued if the outbound limit is hit.
    /// @param encodedInstructions Additional instructions to be forwarded to the recipient chain.
    function transfer(
        uint256 amount,
        uint16 recipientChain,
        bytes32 recipient,
        bytes32 refundAddress,
        bool shouldQueue,
        bytes memory encodedInstructions
    )
        external
        payable
        returns (uint64 msgId);

    /// @notice Complete an outbound transfer that's been queued.
    /// @dev This method is called by the client to complete an outbound transfer that's been queued.
    /// @param queueSequence The sequence of the message in the queue.
    /// @return msgSequence The sequence of the message.
    function completeOutboundQueuedTransfer(uint64 queueSequence) external payable returns (uint64 msgSequence);

    /// @notice Cancels an outbound transfer that's been queued.
    /// @dev This method is called by the client to cancel an outbound transfer that's been queued.
    /// @param queueSequence The sequence of the message in the queue.
    function cancelOutboundQueuedTransfer(uint64 queueSequence) external;

    /// @notice Complete an inbound queued transfer.
    /// @param digest The digest of the message to complete.
    function completeInboundQueuedTransfer(bytes32 digest) external;

    /// @notice Called by an Endpoint contract to deliver a verified attestation.
    /// @dev This function enforces attestation threshold and replay logic for messages. Once all
    ///      validations are complete, this function calls `executeMsg` to execute the command specified
    ///      by the message.
    /// @param sourceChainId The chain id of the sender.
    /// @param sourceNttManagerAddress The address of the sender's nttManager contract.
    /// @param payload The VAA payload.
    function attestationReceived(
        uint16 sourceChainId,
        bytes32 sourceNttManagerAddress,
        TransceiverStructs.NttManagerMessage memory payload
    )
        external;

    /// @notice Called after a message has been sufficiently verified to execute
    ///         the command in the message. This function will decode the payload
    ///         as an NttManagerMessage to extract the sequence, msgType, and other parameters.
    /// @dev This function is exposed as a fallback for when an `Transceiver` is deregistered
    ///      when a message is in flight.
    /// @param sourceChainId The chain id of the sender.
    /// @param sourceNttManagerAddress The address of the sender's nttManager contract.
    /// @param message The message to execute.
    function executeMsg(
        uint16 sourceChainId,
        bytes32 sourceNttManagerAddress,
        TransceiverStructs.NttManagerMessage memory message
    )
        external;

    /// @notice Returns the number of decimals of the token managed by the NttManager.
    /// @return decimals The number of decimals of the token.
    function tokenDecimals() external view returns (uint8);

    /// @notice Returns registered peer contract for a given chain.
    /// @param chainId_ chain ID.
    function getPeer(uint16 chainId_) external view returns (NttManagerPeer memory);

    /// @notice Sets the corresponding peer.
    /// @dev The nttManager that executes the message sets the source nttManager as the peer.
    /// @param peerChainId The chain ID of the peer.
    /// @param peerContract The address of the peer nttManager contract.
    /// @param decimals The number of decimals of the token on the peer chain.
    /// @param inboundLimit The inbound rate limit for the peer chain id
    function setPeer(uint16 peerChainId, bytes32 peerContract, uint8 decimals, uint256 inboundLimit) external;

    /// @notice Sets the outbound transfer limit for a given chain.
    /// @dev This method can only be executed by the `owner`.
    /// @param limit The new outbound limit.
    function setOutboundLimit(uint256 limit) external;

    /// @notice Sets the inbound transfer limit for a given chain.
    /// @dev This method can only be executed by the `owner`.
    /// @param limit The new limit.
    /// @param chainId The chain to set the limit for.
    function setInboundLimit(uint256 limit, uint16 chainId) external;
}
