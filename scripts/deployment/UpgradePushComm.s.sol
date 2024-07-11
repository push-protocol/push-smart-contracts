// SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import { PushCommV3 } from "contracts/PushComm/PushCommV3.sol";
import { ITransparentUpgradeableProxy } from "contracts/PushComm/EPNSCommProxy.sol";
import { EPNSCommAdmin } from "contracts/PushComm/EPNSCommAdmin.sol";

contract UpgradePushComm is Test {
    PushCommV3 public comm;
    EPNSCommAdmin public epnsCommProxyAdmin;
    ITransparentUpgradeableProxy public proxyComm;

    address commProxy = 0x2ddB499C3a35a60c809d878eFf5Fa248bb5eAdbd; // arb comm proxy 
    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        address account = vm.addr(vm.envUint("PRIVATE_KEY"));

        comm = new PushCommV3();
        proxyComm = ITransparentUpgradeableProxy(payable(commProxy));

        address proxyAdmin = address(
            uint160(
                uint256(
                    vm.load(
                        commProxy,
                        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
                    )
                )
            )
        );

        epnsCommProxyAdmin = EPNSCommAdmin(payable(proxyAdmin));
        epnsCommProxyAdmin.upgrade(proxyComm, address(comm));

        vm.stopBroadcast();
    }
}
