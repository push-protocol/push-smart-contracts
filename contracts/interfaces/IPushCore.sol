pragma solidity >=0.6.0 <0.7.0;

interface IPushCore {
    function handleChatRequestData(address requestSender, address requestReceiver, uint256 amount) external;
}
