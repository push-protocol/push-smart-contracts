// // SPDX-License-Identifier: SEE LICENSE IN LICENSE
// pragma solidity ^0.8.20;

/// @title Errors
/// @notice Library that includes all custom errors that any contract might use to revert with.
library Errors {
    /* ***************
        Global Errors
    *************** */

    /// @notice Reverts when `msg.sender` is not the admin of the contract.
    error CallerNotAdmin();
    /// @notice Reverts when `msg.sender` is not the governance.
    error CallerNotGovernance();
    /// @notice Reverts when `msg.sender` is not the admin of the contract.
    error UnauthorizedCaller(address caller);
    /// @notice Reverts when address argument is zero address or invalid for the function.
    error InvalidArgument_WrongAddress(address user);
    /// @notice Reverts when arrays passed as argument have a mismatch of their length.
    error InvalidArg_ArrayLengthMismatch();
    /// @notice Reverts when uint256 argument passed is more than expected value.
    error InvalidArg_MoreThanExpected(uint256 max_threshold, uint256 actual_value);
    /// @notice Reverts when uint256 argument passed is less than expected value.
    error InvalidArg_LessThanExpected(uint256 min_threshold, uint256 actual_value);
    /// @notice Reverts when operation failed because the contract is paused.
    error EnforcedPause();

    /* ***************
        CORE Errors
    *************** */
    /// @notice Core Contract Error: Reverts when the Channel doesn't fit the required function calling criteria.
    error Core_InvalidChannel();
    /// @notice Core Contract Error: Reverts when the Channel Type doesn't fit the required function calling criteria.
    error Core_InvalidChannelType();
    /// @notice Core Contract Error: Reverts whenever the expiry time is not in the future.
    error Core_InvalidExpiryTime();

    /* ***************
        COMM Errors
    *************** */
    /// @notice Comm Contract Error: Reverts whenever the nonce is invalid.
    error Comm_InvalidNonce();
    /// @notice Comm Contract Error: Reverts whenever the caller is an invalid subscriber.
    error Comm_InvalidSubscriber();
    /// @notice Comm Contract Error: Reverts whenever the current time has exceeded the expected end time of a
    /// particular function logic.
    error Comm_TimeExpired(uint256 endTime, uint256 currentTime);
    /// @notice Comm Contract Error: Reverts whenever the signature is invalid from EIP-712 perspective.
    error Comm_InvalidSignature_FromEOA();
    /// @notice Comm Contract Error: Reverts whenever the signature is invalid from EIP-1271 perspective.
    error Comm_InvalidSignature_FromContract();

    /* ***************
        Push STAKING Errors
    *************** */
    /// @notice PushStaking Contract Error: Reverts only when migration-related functions are called even though
    /// migration is completed.
    error PushStaking_MigrationCompleted();
    /// @notice PushStaking Contract Error: Reverts only when the Epoch is more than actually required for a partcular
    /// staking-related action.
    error PushStaking_InvalidEpoch_MoreThanExpected();
    /// @notice PushStaking Contract Error: Reverts only when the Epoch is less than actually required for a partcular
    /// staking-related action.
    error PushStaking_InvalidEpoch_LessThanExpected();
}
