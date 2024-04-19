// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract PushMigrationAdmin is ProxyAdmin {
    constructor(address _owner) ProxyAdmin(_owner) { }
}
