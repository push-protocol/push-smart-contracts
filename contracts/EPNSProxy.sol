// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

contract EPNSProxy is TransparentUpgradeableProxy {


    constructor(
        address _logic,
        address _governance,
        address _lendingPoolProviderAddress,
        address _daiAddress,
        address _aDaiAddress,
        uint _referralCode
    ) public payable TransparentUpgradeableProxy(_logic, _governance, abi.encodeWithSignature('initialize(address,address,address,address,uint256)', _governance, _lendingPoolProviderAddress, _daiAddress, _aDaiAddress, _referralCode)) {}

}