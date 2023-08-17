interface ITokenBridge {

    function completeTransferWithPayload(bytes memory encodedVm) external returns (bytes memory);

}