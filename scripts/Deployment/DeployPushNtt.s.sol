// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console2 } from "forge-std/Script.sol";
import { Push } from "contracts/token/Push.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { DeployBase } from './helpers/DeployBase.sol';

contract DeployPushNtt is Script, DeployBase {
    Push public pushNttImpl;
    ProxyAdmin public pushNttProxyAdmin;
    TransparentUpgradeableProxy public pushNttProxy;

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // Deploy PushNtt and its Proxy
        _deployPushNtt();

        vm.stopBroadcast();
    }

    function _deployPushNtt() internal {
        console2.log("Deploying PushNtt Implementation...");
        pushNttImpl = new Push();
        console2.log("PushNtt Implementation deployed at: ", address(pushNttImpl));

        console2.log("Deploying ProxyAdmin...");
        pushNttProxyAdmin = new ProxyAdmin();
        console2.log("ProxyAdmin deployed at: ", address(pushNttProxyAdmin));

        console2.log("Deploying PushNtt Proxy...");
        pushNttProxy = new TransparentUpgradeableProxy(
            address(pushNttImpl),
            address(pushNttProxyAdmin),
            abi.encodeWithSignature("initialize()")
        );
        console2.log("PushNtt Proxy deployed at: ", address(pushNttProxy));

        console2.log("All contracts deployed:");
        console2.log("PushNtt Implementation: ", address(pushNttImpl));
        console2.log("ProxyAdmin: ", address(pushNttProxyAdmin));
        console2.log("PushNtt Proxy: ", address(pushNttProxy));
    }
}
