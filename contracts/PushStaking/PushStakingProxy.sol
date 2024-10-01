// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract PushStakingProxy is TransparentUpgradeableProxy {
    constructor(
        address _logic,
        address _governance,
        address _pushChannelAdmin,
        address _core,
        address _pushTokenAddress
    )
        payable
        TransparentUpgradeableProxy(
            _logic,
            _governance,
            abi.encodeWithSignature(
                "initialize(address,address,address,uint256,uint256,uint256,uint256,uint256)",
                _pushChannelAdmin,
                _core,
                _pushTokenAddress
            )
        )
    { }
}
