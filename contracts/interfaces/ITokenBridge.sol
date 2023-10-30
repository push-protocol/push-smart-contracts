pragma solidity ^0.8.20;

interface ITokenBridge {
    function completeTransferWithPayload(bytes memory encodedVm) external returns (bytes memory);
}
