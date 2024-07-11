// SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import { PushCoreV3 } from "contracts/PushCore/PushCoreV3.sol";
import { ITransparentUpgradeableProxy } from "contracts/PushComm/EPNSCommProxy.sol";
import { EPNSCoreAdmin } from "contracts/PushCore/EPNSCoreAdmin.sol";

contract UpgradePushCore is Test {
    PushCoreV3 public core;
    EPNSCoreAdmin public epnsCoreProxyAdmin;
    ITransparentUpgradeableProxy public proxyCore;
    address coreProxy = 0x5B9A5152465921307Ca4da7E572bf53f5FA7B671; // sepolia core proxy
    address proxyAdmin = 0x888cb0Ef91c5260C1661803782c45c857521570D; // sepolia proxy admin
    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        address account = vm.addr(vm.envUint("PRIVATE_KEY"));

        core = new PushCoreV3();

        epnsCoreProxyAdmin = EPNSCoreAdmin(payable(proxyAdmin));
        proxyCore = ITransparentUpgradeableProxy(payable(coreProxy));

        epnsCoreProxyAdmin.upgrade(proxyCore, address(core));

        vm.stopBroadcast();
    }
}
