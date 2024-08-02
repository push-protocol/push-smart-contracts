// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console2 } from "forge-std/Script.sol";
import { EPNS } from "contracts/token/EPNS.sol";
import { DeployBase } from './helpers/DeployBase.sol';

contract DeployPushToken is Script, DeployBase {
    EPNS public pushToken;

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // Deploy PushNtt and its Proxy
        _deployPushToken();

        vm.stopBroadcast();
    }

    function _deployPushToken() internal {
        console2.log("Deploying Push Token...");
        pushToken = new EPNS();
        console2.log("Push Token deployed at: ", address(pushToken));
    }
}
