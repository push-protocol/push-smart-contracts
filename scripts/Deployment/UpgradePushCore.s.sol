// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { console2, Script } from "forge-std/Script.sol";
import { PushCoreV3 } from "contracts/PushCore/PushCoreV3.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { EPNSCoreAdmin } from "contracts/PushCore/EPNSCoreAdmin.sol";
import { DeployBase } from "./helpers/DeployBase.s.sol";

contract UpgradePushCore is DeployBase {
    struct ConfigParams {
        address pushCoreProxyAddr;
    }

    PushCoreV3 public pushCoreImpl;
    EPNSCoreAdmin public pushCoreProxyAdmin;
    ITransparentUpgradeableProxy public pushCoreProxy;

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // Sanity check deployment parameters.
        ConfigParams memory configParams = _readEnvVariables();

        // Deploy new PushCoreV3 implementation
        _deployPushCoreImplementation();

        // Upgrade the proxy to use the new implementation
        _upgradePushCoreProxy(configParams);

        vm.stopBroadcast();
    }

    function _deployPushCoreImplementation() internal {
        console2.log("Deploying new PushCoreV3 Implementation...");
        pushCoreImpl = new PushCoreV3();
        console2.log("PushCoreV3 Implementation deployed at: ", address(pushCoreImpl));
    }

    function _upgradePushCoreProxy(ConfigParams memory configParams) internal {
        console2.log("Upgrading PushCore Proxy...");

        _upgradeContract(configParams.pushCoreProxyAddr, address(pushCoreImpl));

        console2.log("PushCore Proxy upgraded to new implementation at: ", address(pushCoreImpl));
    }

    function _readEnvVariables() internal view returns (ConfigParams memory configParams) {
        console2.log("Reading environment variables...");
        configParams.pushCoreProxyAddr = vm.envAddress("PUSH_CORE_PROXY");
        if (configParams.pushCoreProxyAddr == address(0)) {
            console2.log("Invalid PUSH_CORE_PROXY: ", configParams.pushCoreProxyAddr);
            revert InvalidAddress();
        }
        console2.log("PUSH_CORE_PROXY: ", configParams.pushCoreProxyAddr);
    }
}
