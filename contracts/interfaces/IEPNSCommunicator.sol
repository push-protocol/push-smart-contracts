pragma solidity >=0.6.0 <0.7.0;

interface IEPNSCommunicator {
 	function subscribeViaCore(address _channel, address _user) external returns(bool);
}