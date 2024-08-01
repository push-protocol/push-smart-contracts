// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { console2, Script } from "forge-std/Script.sol";
import { PushMigrationHelper } from "contracts/token/PushMigration.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { DeployBase } from "./helpers/DeployBase.sol";

contract UpgradePushMigration is Script, DeployBase {
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

        // Load the ProxyAdmin address from the proxy contract's storage
        address proxyAdmin = address(
            uint160(
                uint256(
                    vm.load(
                        configParams.pushMigrationProxyAddr,
                        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
                    )
                )
            )
        );
        pushMigrationProxyAdmin = ProxyAdmin(payable(proxyAdmin));
        pushMigrationProxy = ITransparentUpgradeableProxy(payable(configParams.pushMigrationProxyAddr));

        // Upgrade the proxy to the new implementation
        pushMigrationProxyAdmin.upgrade(pushMigrationProxy, address(pushMigrationImpl));

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
