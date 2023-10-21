// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

contract PushFeePoolProxy is TransparentUpgradeableProxy {
    constructor(
        address _logic,
        address _governance,
        address _pushChannelAdmin,
        address _core,
        address _pushTokenAddress,
        uint _genesisEpoch,
        uint _lastEpochInitialized,
        uint _lastTotalStakeEpochInitialized,
        uint _totalStakedAmount,
        uint _previouslySetEpochRewards
    )
        public
        payable
        TransparentUpgradeableProxy(
            _logic,
            _governance,
            abi.encodeWithSignature(
                "initialize(address,address,address,uint256,uint256,uint256,uint256,uint256)",
                _pushChannelAdmin,
                _core,
                _pushTokenAddress,
                _genesisEpoch,
                _lastEpochInitialized,
                _lastTotalStakeEpochInitialized,
                _totalStakedAmount,
                _previouslySetEpochRewards
            )
        )
    {}
}