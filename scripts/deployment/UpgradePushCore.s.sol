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
    
    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        address account = vm.addr(vm.envUint("PRIVATE_KEY"));

        core = new PushCoreV3();

        address proxyAdmin = address(
            uint160(
                uint256(
                    vm.load(
                        coreProxy,
                        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
                    )
                )
            )
        );

        epnsCoreProxyAdmin = EPNSCoreAdmin(payable(proxyAdmin));
        proxyCore = ITransparentUpgradeableProxy(payable(coreProxy));

        epnsCoreProxyAdmin.upgrade(proxyCore, address(core));

        vm.stopBroadcast();
    }
}
