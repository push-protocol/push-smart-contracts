// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

contract PushFeePoolProxy is TransparentUpgradeableProxy {
    constructor(
        address _logic,
        address _governance,
        address _pushChannelAdmin,
        address _core,
        address _pushTokenAddress
    )
        public
        payable
        TransparentUpgradeableProxy(
            _logic,
            _governance,
            abi.encodeWithSignature(
                "initialize(address,address,address)",
                _pushChannelAdmin,
                _core,
                _pushTokenAddress
            )
        )
    {}
}