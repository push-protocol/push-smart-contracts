pragma solidity ^0.8.20;
import {PushCoreStorageV1_5} from "contracts/PushCore/PushCoreStorageV1_5.sol";

abstract contract CoreEvents {
    event AddChannel(address indexed channel, PushCoreStorageV1_5.ChannelType indexed channelType, bytes identity);
    event UpdateChannel(address indexed channel, bytes identity, uint256 indexed amountDeposited);
    event ReactivateChannel(address indexed channel, uint256 indexed amountDeposited);
    event DeactivateChannel(address indexed channel, uint256 indexed amountRefunded);
    event ChannelBlocked(address indexed channel);
    event TimeBoundChannelDestroyed(address indexed channel, uint256 indexed amountRefunded);
}

abstract contract CommEvents {}

abstract contract ProxyEvents {
    event Paused(address account);
    event Unpaused(address account);
}

abstract contract Events is CoreEvents, CommEvents, ProxyEvents {}