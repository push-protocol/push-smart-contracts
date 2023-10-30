pragma solidity >=0.6.0 <0.7.0;

interface IPushCore {
    function handleChatRequestData(address requestSender, address requestReceiver, uint256 amount) external;
    function PROTOCOL_POOL_FEES() external view returns (uint256);
    function sendFunds(address _user, uint256 _amount) external;
}
