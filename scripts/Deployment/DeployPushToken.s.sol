// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console2 } from "forge-std/Script.sol";
import { EPNS } from "contracts/token/EPNS.sol";
import { DeployBase } from './helpers/DeployBase.s.sol';

contract DeployPushToken is DeployBase {
    EPNS public pushToken;

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // Deploy PushToken
        _deployPushToken();

        vm.stopBroadcast();
    }

    function _deployPushToken() internal {
        address account = vm.addr(vm.envUint("PRIVATE_KEY"));

        console2.log("Deploying Push Token...");
        pushToken = new EPNS(account);
        console2.log("Push Token deployed at: ", address(pushToken));
    }
}
