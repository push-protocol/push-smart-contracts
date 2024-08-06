// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { console2, Script } from "forge-std/Script.sol";
import { PushCommV3 } from "contracts/PushComm/PushCommV3.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { EPNSCommAdmin } from "contracts/PushComm/EPNSCommAdmin.sol";
import { DeployBase } from "./helpers/DeployBase.s.sol";

contract UpgradePushComm is DeployBase {
    struct ConfigParams {
        address pushCommProxyAddr;
    }

    PushCommV3 public pushCommImpl;
    EPNSCommAdmin public pushCommProxyAdmin;
    ITransparentUpgradeableProxy public pushCommProxy;

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // Sanity check deployment parameters.
        ConfigParams memory configParams = _readEnvVariables();

        // Deploy new PushCommV3 implementation
        _deployPushCommImplementation();

        // Upgrade the proxy to use the new implementation
        _upgradePushCommProxy(configParams);

        vm.stopBroadcast();
    }

    function _deployPushCommImplementation() internal {
        console2.log("Deploying new PushCommV3 Implementation...");
        pushCommImpl = new PushCommV3();
        console2.log("PushCommV3 Implementation deployed at: ", address(pushCommImpl));
    }

    function _upgradePushCommProxy(ConfigParams memory configParams) internal {
        console2.log("Upgrading PushComm Proxy...");

        _upgradeContract(configParams.pushCommProxyAddr, address(pushCommImpl));

        console2.log("PushComm Proxy upgraded to new implementation at: ", address(pushCommImpl));
    }

    function _readEnvVariables() internal view returns (ConfigParams memory configParams) {
        console2.log("Reading environment variables...");
        configParams.pushCommProxyAddr = vm.envAddress("PUSH_COMM_PROXY");
        if (configParams.pushCommProxyAddr == address(0)) {
            console2.log("Invalid PUSH_COMM_PROXY: ", configParams.pushCommProxyAddr);
            revert InvalidAddress();
        }
        console2.log("PUSH_COMM_PROXY: ", configParams.pushCommProxyAddr);
    }
}
