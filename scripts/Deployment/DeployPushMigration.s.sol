// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console2 } from "forge-std/Script.sol";
import { PushMigrationHelper } from "contracts/token/PushMigration.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { DeployBase } from './helpers/DeployBase.sol';

contract DeployPushMigration is Script, DeployBase {
    struct ConfigParams {
        address oldPushToken;
    }

    PushMigrationHelper public pushMigrationImpl;
    ProxyAdmin public pushMigrationProxyAdmin;
    TransparentUpgradeableProxy public pushMigrationProxy;

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // Sanity check deployment parameters.
        ConfigParams memory configParams = _readEnvVariables();

        // Deploy PushMigration
        _deployPushMigration(configParams);

        vm.stopBroadcast();
    }

    function _deployPushMigration(ConfigParams memory configParams) internal {
        console2.log("Deploying PushMigrationHelper Implementation...");
        pushMigrationImpl = new PushMigrationHelper();
        console2.log("PushMigrationHelper Implementation deployed at: ", address(pushMigrationImpl));

        console2.log("Deploying ProxyAdmin...");
        pushMigrationProxyAdmin = new ProxyAdmin();
        console2.log("ProxyAdmin deployed at: ", address(pushMigrationProxyAdmin));

        console2.log("Deploying PushMigrationHelper Proxy...");
        pushMigrationProxy = new TransparentUpgradeableProxy(
            address(pushMigrationImpl),
            address(pushMigrationProxyAdmin),
            abi.encodeWithSignature("initialize(address)", address(configParams.oldPushToken))
        );
        console2.log("PushMigrationHelper Proxy deployed at: ", address(pushMigrationProxy));

        console2.log("All contracts deployed:");
        console2.log("PushMigrationHelperImpl: ", address(pushMigrationImpl));
        console2.log("ProxyAdmin: ", address(pushMigrationProxyAdmin));
        console2.log("PushMigrationHelperProxy: ", address(pushMigrationProxy));
    }

    function _readEnvVariables() internal view returns (ConfigParams memory configParams) {
        console2.log("Reading environment variables...");
        configParams.oldPushToken = vm.envAddress('OLD_PUSH_TOKEN_ADDRESS');
        if (configParams.oldPushToken == address(0)) {
            console2.log("Invalid OLD_PUSH_TOKEN_ADDRESS: ", configParams.oldPushToken);
            revert InvalidAddress();
        }
        console2.log("OLD_PUSH_TOKEN_ADDRESS: ", configParams.oldPushToken);
    }
}
