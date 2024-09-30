// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract PushStakingProxy is TransparentUpgradeableProxy {
    constructor(
        address _logic,
        address _governance,
        address _pushChannelAdmin,
        address _core,
        address _pushTokenAddress,
        uint256 _genesisEpoch,
        uint256 _lastEpochInitialized,
        uint256 _lastTotalStakeEpochInitialized,
        uint256 _totalStakedAmount,
        uint256 _previouslySetEpochRewards
    )
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
    { }
}
