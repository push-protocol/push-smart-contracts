// SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "contracts/token/EPNS.sol";

/**
 * Command
 * forge script ./scripts/deployment/DeployPushToken.s.sol --verify --etherscan-api-key GJ9ASUPXHA4TH7H36C29878Y95MFKVNJJ3 --fork-url https://1rpc.io/sepolia --private-key [PRIVATE_KEY] --broadcast
 */

contract DeployPushToken is Test {
    EPNS public pushToken;

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        address account = vm.addr(vm.envUint("PRIVATE_KEY"));

        pushToken = new EPNS(account);

        vm.stopBroadcast();
    }
}
