// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { console2, Script } from "forge-std/Script.sol";
import { Push } from "contracts/token/Push.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { DeployBase } from "./helpers/DeployBase.sol";

contract UpgradePushNtt is Script, DeployBase {
    struct ConfigParams {
        address pushNttProxyAddr;
    }

    Push public pushNttImpl;
    ProxyAdmin public pushNttProxyAdmin;
    ITransparentUpgradeableProxy public pushNttProxy;

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // Sanity check deployment parameters.
        ConfigParams memory configParams = _readEnvVariables();

        // Deploy new PushNtt implementation
        _deployPushNttImplementation();

        // Upgrade the proxy to use the new implementation
        _upgradePushNttProxy(configParams);

        vm.stopBroadcast();
    }

    function _deployPushNttImplementation() internal {
        console2.log("Deploying new PushNtt Implementation...");
        pushNttImpl = new Push();
        console2.log("PushNtt Implementation deployed at: ", address(pushNttImpl));
    }

    function _upgradePushNttProxy(ConfigParams memory configParams) internal {
        console2.log("Upgrading PushNtt Proxy...");

        // Load the ProxyAdmin address from the proxy contract's storage
        address proxyAdmin = address(
            uint160(
                uint256(
                    vm.load(
                        configParams.pushNttProxyAddr,
                        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
                    )
                )
            )
        );
        pushNttProxyAdmin = ProxyAdmin(payable(proxyAdmin));
        pushNttProxy = ITransparentUpgradeableProxy(payable(configParams.pushNttProxyAddr));

        // Upgrade the proxy to the new implementation
        pushNttProxyAdmin.upgrade(pushNttProxy, address(pushNttImpl));

        console2.log("PushNtt Proxy upgraded to new implementation at: ", address(pushNttImpl));
    }

    function _readEnvVariables() internal view returns (ConfigParams memory configParams) {
        console2.log("Reading environment variables...");
        configParams.pushNttProxyAddr = vm.envAddress("PUSH_NTT_PROXY");
        if (configParams.pushNttProxyAddr == address(0)) {
            console2.log("Invalid PUSH_NTT_PROXY: ", configParams.pushNttProxyAddr);
            revert InvalidAddress();
        }
        console2.log("PUSH_NTT_PROXY: ", configParams.pushNttProxyAddr);
    }
}
