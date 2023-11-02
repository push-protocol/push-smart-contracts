pragma solidity ^0.8.20;

interface IEPNSCommV1 {
    function subscribeViaCore(address _channel, address _user) external returns (bool);
    function unSubscribeViaCore(address _channel, address _user) external returns (bool);
}
