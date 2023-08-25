pragma solidity >=0.6.0 <0.7.0;

interface IPushCore {
    function handleChatRequestData(address requestSender, address requestReceiver, uint256 amount) external;
    function PROTOCOL_POOL_FEES() external view returns(uint);
    function updateProtocolPoolFee(uint _amount) external;
    function approveStaker(uint _amount) external;
}
