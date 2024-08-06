// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { console2, Script } from "forge-std/Script.sol";
import { PushMigrationHelper } from "contracts/token/PushMigration.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { DeployBase } from "./helpers/DeployBase.s.sol";

contract UpgradePushMigration is DeployBase {
    struct ConfigParams {
        address pushMigrationProxyAddr;
    }

    PushMigrationHelper public pushMigrationImpl;
    ProxyAdmin public pushMigrationProxyAdmin;
    ITransparentUpgradeableProxy public pushMigrationProxy;

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // Sanity check deployment parameters.
        ConfigParams memory configParams = _readEnvVariables();

        // Deploy new PushMigrationHelper implementation
        _deployPushMigrationImplementation();

        // Upgrade the proxy to use the new implementation
        _upgradePushMigrationProxy(configParams);

        vm.stopBroadcast();
    }

    function _deployPushMigrationImplementation() internal {
        console2.log("Deploying new PushMigrationHelper Implementation...");
        pushMigrationImpl = new PushMigrationHelper();
        console2.log("PushMigrationHelper Implementation deployed at: ", address(pushMigrationImpl));
    }

    function _upgradePushMigrationProxy(ConfigParams memory configParams) internal {
        console2.log("Upgrading PushMigrationHelper Proxy...");

        _upgradeContract(configParams.pushMigrationProxyAddr, address(pushMigrationImpl));

        console2.log("PushMigrationHelper Proxy upgraded to new implementation at: ", address(pushMigrationImpl));
    }

    function _readEnvVariables() internal view returns (ConfigParams memory configParams) {
        console2.log("Reading environment variables...");
        configParams.pushMigrationProxyAddr = vm.envAddress("PUSH_MIGRATION_PROXY");
        if (configParams.pushMigrationProxyAddr == address(0)) {
            console2.log("Invalid PUSH_MIGRATION_PROXY: ", configParams.pushMigrationProxyAddr);
            revert InvalidAddress();
        }
        console2.log("PUSH_MIGRATION_PROXY: ", configParams.pushMigrationProxyAddr);
    }
}
