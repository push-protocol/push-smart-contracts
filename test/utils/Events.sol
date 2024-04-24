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
    event ChannelVerified(address indexed channel, address indexed verifier);
    event ChannelVerificationRevoked(address indexed channel, address indexed revoker);
    event ChannelStateUpdate(address indexed channel, uint256 amountRefunded, uint256 amountDeposited);
}

abstract contract CommEvents {
    event IncentivizeChatReqInitiated(
        address requestSender, address requestReceiver, uint256 amountDeposited, uint256 timestamp
    );
    event Subscribe(address indexed channel, address indexed user);
    event Unsubscribe(address indexed channel, address indexed user);
}

abstract contract ProxyEvents {
    event Paused(address account);
    event Unpaused(address account);
}

abstract contract MigrationEvents {
    event TokenMigrated(address indexed _tokenHolder, address indexed _tokenReceiver, uint256 _amountMigrated);
    event TokenUnmigrated(address indexed _tokenHolder, uint256 _amountUnmigrated);
}

abstract contract PushTokenEvents {
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event NewMinter(address indexed newMinter);
}

abstract contract Events is CoreEvents, CommEvents, ProxyEvents, PushTokenEvents, MigrationEvents { }
