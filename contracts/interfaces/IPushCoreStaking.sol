pragma solidity ^0.8.20;


interface IPushCoreStaking {
    function sendFunds(address _user, uint256 _amount) external;

    function PROTOCOL_POOL_FEES() external view returns (uint256);
}
