pragma solidity >=0.6.0 <0.7.0;

interface IEPNSCommunicator {
 	function subscribeViaCore(address _channel, address _user) external returns(bool);
 	function addDelegate(address _delegate) external returns(bool);
 	function removeDelegate(address _delegate) external returns(bool);

}