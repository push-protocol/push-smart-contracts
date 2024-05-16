pragma solidity ^0.8.20;

contract PushCoreStorageV3 {
    /* *** V3 State variables *** */
    // WORMHOLE Cross-Chain State

    address public wormholeRelayer;
    mapping(bytes32 => bool) public processedMessages;
    mapping(uint16 => bytes32) public registeredSenders;
    mapping(address => uint256) public arbitraryReqFees;
}
