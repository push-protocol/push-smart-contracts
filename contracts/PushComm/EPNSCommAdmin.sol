// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract EPNSCommAdmin is ProxyAdmin {
    constructor(address _pushChannelAdmin) public ProxyAdmin(_pushChannelAdmin){} 
}
