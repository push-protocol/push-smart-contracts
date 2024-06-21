// SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "contracts/token/Push.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * Command
 * forge script ./scripts/deployment/DeployNttToken.s.sol --verify --etherscan-api-key GJ9ASUPXHA4TH7H36C29878Y95MFKVNJJ3 --fork-url https://1rpc.io/sepolia --private-key [PRIVATE_KEY] --broadcast
 */
contract DeployNttToken is Test {
    Push public pushNtt;
    Push public pushNttToken;
    ProxyAdmin public nttProxyAdmin;
    TransparentUpgradeableProxy public pushNttProxy;

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        address account = vm.addr(vm.envUint("PRIVATE_KEY"));

        pushNtt = new Push();
        nttProxyAdmin = new ProxyAdmin();
        pushNttProxy = new TransparentUpgradeableProxy(
            address(pushNtt),
            address(nttProxyAdmin),
            abi.encodeWithSignature("initialize()")
        );

        vm.stopBroadcast();
    }
}
