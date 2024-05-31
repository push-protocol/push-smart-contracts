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

    address commProxy = 0x96891F643777dF202b153DB9956226112FfA34a9; // arb comm proxy 
    address proxyAdmin = 0x9589262b17A99288Ee575C24a723Ad124cd9e875; // arb proxy admin
    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        address account = vm.addr(vm.envUint("PRIVATE_KEY"));

        comm = new PushCommV3();

        epnsCommProxyAdmin = EPNSCommAdmin(payable(proxyAdmin));
        proxyComm = ITransparentUpgradeableProxy(payable(commProxy));

        epnsCommProxyAdmin.upgrade(proxyComm, address(comm));

        vm.stopBroadcast();
    }
}
