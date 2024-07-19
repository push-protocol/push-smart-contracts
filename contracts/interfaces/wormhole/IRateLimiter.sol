// SPDX-License-Identifier: Apache 2
pragma solidity ^0.8.20;

import "../../libraries/wormhole-lib/TransceiverStructs.sol";
import "../../libraries/wormhole-lib/TrimmedAmount.sol";

interface IRateLimiter {
    /// @notice Not enough capacity to send the transfer.
    /// @dev Selector 0x26fb55dd.
    /// @param currentCapacity The current capacity.
    /// @param amount The amount of the transfer.
    error NotEnoughCapacity(uint256 currentCapacity, uint256 amount);

    /// @notice Outbound transfer is not longer queued.
    /// @dev Selector 0xbfd5f462.
    /// @param queueSequence The sequence of the queue.
    error OutboundQueuedTransferNotFound(uint64 queueSequence);

    /// @notice Cannot complete the outbound transfer, the transfer is still queued.
    /// @dev Selector 0xc06cf05f.
    /// @param queueSequence The sequence of the queue.
    /// @param transferTimestamp The timestamp of when the transfer was queued.
    error OutboundQueuedTransferStillQueued(uint64 queueSequence, uint256 transferTimestamp);

    /// @notice The inbound transfer is not longer queued.
    /// @dev Selector 0xc06f2bc0.
    /// @param digest The digest of the transfer.
    error InboundQueuedTransferNotFound(bytes32 digest);

    /// @notice The transfer is still queued.
    /// @dev Selector 0xe5b9ce80.
    /// @param digest The digest of the transfer.
    /// @param transferTimestamp The timestamp of the transfer.
    error InboundQueuedTransferStillQueued(bytes32 digest, uint256 transferTimestamp);

    /// @notice The new capacity cannot exceed the limit.
    /// @dev Selector 0x0f85ba52.
    /// @param newCurrentCapacity The new current capacity.
    /// @param newLimit The new limit.
    error CapacityCannotExceedLimit(TrimmedAmount newCurrentCapacity, TrimmedAmount newLimit);

    /// @notice If the rate limiting behaviour isn't explicitly defined in the constructor.
    /// @dev Selector 0xe543ef05.
    error UndefinedRateLimiting();

    /// @notice Parameters used in determining rate limits and queuing.
    /// @dev
    ///    - limit: current rate limit value.
    ///    - currentCapacity: the current capacity left.
    ///    - lastTxTimestamp: the timestamp of when the
    ///                       capacity was previously consumption.
    struct RateLimitParams {
        TrimmedAmount limit;
        TrimmedAmount currentCapacity;
        uint64 lastTxTimestamp;
    }

    /// @notice Parameters for an outbound queued transfer.
    /// @dev
    ///    - recipient: the recipient of the transfer.
    ///    - amount: the amount of the transfer, trimmed.
    ///    - txTimestamp: the timestamp of the transfer.
    ///    - recipientChain: the chain of the recipient.
    ///    - sender: the sender of the transfer.
    ///    - transceiverInstructions: additional instructions to be forwarded to the recipient chain.
    struct OutboundQueuedTransfer {
        bytes32 recipient;
        bytes32 refundAddress;
        TrimmedAmount amount;
        uint64 txTimestamp;
        uint16 recipientChain;
        address sender;
        bytes transceiverInstructions;
    }

    /// @notice Parameters for an inbound queued transfer.
    /// @dev
    ///   - amount: the amount of the transfer, trimmed.
    ///   - txTimestamp: the timestamp of the transfer.
    ///   - recipient: the recipient of the transfer.
    struct InboundQueuedTransfer {
        TrimmedAmount amount;
        uint64 txTimestamp;
        address recipient;
    }

    function getCurrentOutboundCapacity() external view returns (uint256);

    function getOutboundQueuedTransfer(uint64 queueSequence) external view returns (OutboundQueuedTransfer memory);

    function getCurrentInboundCapacity(uint16 chainId) external view returns (uint256);

    function getInboundQueuedTransfer(bytes32 digest) external view returns (InboundQueuedTransfer memory);

    function getInboundLimitParams(uint16 chainId_) external view returns (RateLimitParams memory);

    function getOutboundLimitParams() external pure returns (RateLimitParams memory);
}
