// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console2 } from "forge-std/Script.sol";
import { PushCommV3 } from "contracts/PushComm/PushCommV3.sol";
import { EPNSCommProxy } from "contracts/PushComm/EPNSCommProxy.sol";
import { EPNSCommAdmin } from "contracts/PushComm/EPNSCommAdmin.sol";
import { DeployBase } from './helpers/DeployBase.s.sol';

contract DeployPushComm is DeployBase {
    struct ConfigParams {
        address coreProxy;
        address pushToken;
        string chainName;
    }

    PushCommV3 public commImpl;
    EPNSCommProxy public commProxy;
    EPNSCommAdmin public commProxyAdmin;

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        
        // Sanity check deployment parameters.
        ConfigParams memory configParams = _readEnvVariables();

        // Deploy PushComm and its Proxy
        _deployPushComm(configParams);

        vm.stopBroadcast();
    }

    function _deployPushComm(ConfigParams memory configParams) internal {
        address account = vm.addr(vm.envUint("PRIVATE_KEY"));

        console2.log("Deploying PushComm Implementation...");
        commImpl = new PushCommV3();
        console2.log("PushComm Implementation deployed at: ", address(commImpl));

        console2.log("Deploying PushComm ProxyAdmin...");
        commProxyAdmin = new EPNSCommAdmin(account);
        console2.log("PushComm ProxyAdmin deployed at: ", address(commProxyAdmin));

        console2.log("Deploying PushComm Proxy...");
        commProxy = new EPNSCommProxy(
            address(commImpl),
            address(commProxyAdmin),
            account,
            configParams.chainName
        );
        console2.log("PushComm Proxy deployed at: ", address(commProxy));

        console2.log("All contracts deployed:");
        console2.log("PushComm Implementation: ", address(commImpl));
        console2.log("PushComm ProxyAdmin: ", address(commProxyAdmin));
        console2.log("PushComm Proxy: ", address(commProxy));
    }

    function _readEnvVariables() internal view returns (ConfigParams memory configParams) {
        console2.log("Reading environment variables...");
        configParams.chainName = vm.envString('CHAIN_NAME');

        // Validate the addresses
        require(configParams.chainName != "", "Empty CHAIN_NAME");

        console2.log("CHAIN_NAME: ", configParams.chainName);
    }
}
