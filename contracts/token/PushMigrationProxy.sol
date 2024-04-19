// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract PushMigrationProxy is TransparentUpgradeableProxy {
    constructor(
        address _logic,
        address _governance,
        address _owner,
        address _oldToken
    )
        payable
        TransparentUpgradeableProxy(
            _logic,
            _governance,
            abi.encodeWithSignature("initialize(address,address)", _owner, _oldToken)
        )
    { }
}
