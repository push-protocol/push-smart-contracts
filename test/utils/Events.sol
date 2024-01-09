pragma solidity ^0.8.20;

import { CoreTypes } from "../../contracts/libraries/DataTypes.sol";

abstract contract CoreEvents {
    event AddChannel(address indexed channel, CoreTypes.ChannelType indexed channelType, bytes identity);
    event UpdateChannel(address indexed channel, bytes identity, uint256 indexed amountDeposited);
    event ReactivateChannel(address indexed channel, uint256 indexed amountDeposited);
    event DeactivateChannel(address indexed channel, uint256 indexed amountRefunded);
    event ChannelBlocked(address indexed channel);
    event TimeBoundChannelDestroyed(address indexed channel, uint256 indexed amountRefunded);
    event IncentivizeChatReqReceived(
        address requestSender,
        address requestReceiver,
        uint256 amountForReqReceiver,
        uint256 feePoolAmount,
        uint256 timestamp
    );
    event ChatIncentiveClaimed(address indexed user, uint256 indexed amountClaimed);
}

abstract contract CommEvents {
    event IncentivizeChatReqInitiated(
        address requestSender, address requestReceiver, uint256 amountDeposited, uint256 timestamp
    );
}

abstract contract ProxyEvents {
    event Paused(address account);
    event Unpaused(address account);
}

abstract contract Events is CoreEvents, CommEvents, ProxyEvents { }
