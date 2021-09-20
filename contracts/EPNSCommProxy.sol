// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

contract EPNSCommProxy is TransparentUpgradeableProxy {


    constructor(
      address _logic,
      address _governance,
      address _pushChannelAdmin
    ) public payable TransparentUpgradeableProxy(_logic, _governance, abi.encodeWithSignature('initialize(address)', _pushChannelAdmin)) {}

}
