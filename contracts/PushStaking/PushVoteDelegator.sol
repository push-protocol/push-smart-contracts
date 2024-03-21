// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import { IPUSH } from "../interfaces/IPUSH.sol";

/// @title PushVoteDelegator
/// @author Inspired by Scopelif's DelegationSurrogate contract
/// @notice A dead-simple contract whose only purpose is to hold governance tokens on behalf of
/// users while delegating voting power to one specific delegatee. This is needed because a single
/// address can only delegate its (full) token weight to a single address at a time. Thus, when a
/// contract holds governance tokens in a pool on behalf of disparate token holders, those holders
/// are typically disenfranchised from their governance rights.
///
/// If a pool contract deploys a DelegationSurrogate for each delegatee, and transfers each
/// depositor's tokens to the appropriate  surrogate—or deploys it on their behalf—users can retain
/// their governance rights.
///
/// The pool contract deploying the surrogates must handle all accounting. The surrogate simply
/// delegates its voting weight and max-approves its deployer to allow tokens to be reclaimed.
contract PushVoteDelegator {
  /// @param _token The governance token that will be held by this surrogate
  /// @param _delegatee The address of the would-be voter to which this surrogate will delegate its
  /// voting weight. 100% of all voting tokens held by this surrogate will be delegated to this
  /// address.
  constructor(IPUSH _token, address _delegatee) {
    _token.delegate(_delegatee);
    _token.approve(msg.sender, type(uint256).max);
  }
}
