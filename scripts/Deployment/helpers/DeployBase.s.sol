// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract DeployBase is Script {
    // Custom errors
    error InvalidAddress(); // Error for invalid address

    function _upgradeContract(address _proxyAddr, address _newImplementation) internal {
        // Load the ProxyAdmin address from the proxy contract's storage
        address proxyAdminAddr = address(
            uint160(
                uint256(
                    vm.load(
                        _proxyAddr,
                        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
                    )
                )
            )
        );
        ProxyAdmin proxyAdmin = ProxyAdmin(payable(proxyAdminAddr));
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(_proxyAddr));

        // Upgrade the proxy to the new implementation
        proxyAdmin.upgrade(proxy, address(_newImplementation));
    }
}
