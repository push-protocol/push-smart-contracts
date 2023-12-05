// // SPDX-License-Identifier: SEE LICENSE IN LICENSE
// pragma solidity ^0.8.20;

/// @title Errors
/// @notice Library that includes all custom errors that any contract might use to revert with.
library Errors {

    /* ***************
        Global Errors
    *************** */
    error InvalidCaller();

    error InvalidCallerParam(string err);
    error InvalidChannel();
    error InvalidArgument(string err);
    error InvalidAmount();
    error InvalidLogic(string err);
    error InvalidEpoch(string err);

    error InvalidSignature(string err);
    error InvalidSubscriber(string err);

}
