pragma solidity >=0.6.0 <0.7.0;
contract TempStore{
    mapping(address=>bool) _isChannelUpdated;

    function isChannelAdjusted(address _channelAddress) external view returns(bool) {
        return _isChannelUpdated[_channelAddress];
    }

    function setChannelAdjusted(address _channelAddress)external {
        _isChannelUpdated[_channelAddress] = true;
    }    
}