pragma solidity ^0.8.20;
import {CoreTypes} from "../../contracts/libraries/DataTypes.sol";


abstract contract CoreEvents {
    event AddChannel(address indexed channel, CoreTypes.ChannelType indexed channelType, bytes identity);
    event ReactivateChannel(address indexed channel, uint256 indexed amountDeposited);
    event DeactivateChannel(address indexed channel, uint256 indexed amountRefunded);
    event ChannelBlocked(address indexed channel);
}