pragma solidity >=0.6.0 <0.7.0;

/* @notice - A temproary storage contract that keeps track of channels whose
*            new poolContribution and weight has been updated
*
*            This helps us flag the already adjusted channels and ensure that
*            they are not repeated in the for loop.
*
*/
contract TempStorage{
    mapping(address=>bool) public _isChannelUpdated;
    address public Core_Address = 0x66329Fdd4042928BfCAB60b179e1538D56eeeeeE;

    function isChannelAdjusted(address _channelAddress) external view returns(bool) {
        return _isChannelUpdated[_channelAddress];
    }

    function setChannelAdjusted(address _channelAddress) external {
         require(msg.sender == Core_Address, "Can only be called via Core");
        _isChannelUpdated[_channelAddress] = true;
    }
}
