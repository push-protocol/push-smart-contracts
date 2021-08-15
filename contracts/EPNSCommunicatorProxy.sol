// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

contract EPNSCommunicatorProxy is TransparentUpgradeableProxy {


    constructor(
        address _logic,
        address _admin
    ) public payable TransparentUpgradeableProxy(_logic, _admin, abi.encodeWithSignature('initialize(address)', _admin)) {}

}