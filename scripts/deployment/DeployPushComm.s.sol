// SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import { PushCoreV3 } from "contracts/PushCore/PushCoreV3.sol";
import { PushCoreMock } from "contracts/mocks/PushCoreMock.sol";
import { EPNSCoreProxy, ITransparentUpgradeableProxy } from "contracts/PushCore/EPNSCoreProxy.sol";
import { EPNSCoreAdmin } from "contracts/PushCore/EPNSCoreAdmin.sol";
import { PushCommV3 } from "contracts/PushComm/PushCommV3.sol";
import { EPNSCommProxy } from "contracts/PushComm/EPNSCommProxy.sol";
import { EPNSCommAdmin } from "contracts/PushComm/EPNSCommAdmin.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployPushComm is Test {
    PushCommV3 public comm;
    PushCommV3 public commProxy;
    EPNSCommProxy public epnsCommProxy;
    EPNSCommAdmin public epnsCommProxyAdmin;

    address public coreProxy = 0x53a3a61D73Cab3e15594ECEdc3eEEEf7978d7020;
    // address public pushToken = 0x70c3C79d33A9b08F1bc1e7DB113D1588Dad7d8Bc; // arb sepolia token
    address public pushToken = 0xff9A15FBa9c0E08683F2599382df551035C1d8C4; // bnb testnet token

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        address account = vm.addr(vm.envUint("PRIVATE_KEY"));

        comm = new PushCommV3();

        epnsCommProxyAdmin = new EPNSCommAdmin(account);
        epnsCommProxy =
            new EPNSCommProxy(address(comm), address(epnsCommProxyAdmin), account, "arb testnet");
        commProxy = PushCommV3(address(epnsCommProxy));

        // epnsCommProxyAdmin = new EPNSCommAdmin(account);
        // epnsCommProxy =
        //     new EPNSCommProxy(address(comm), address(epnsCommProxyAdmin), account, "bnb testnet");
        // commProxy = PushCommV3(address(epnsCommProxy));

        commProxy.setEPNSCoreAddress(coreProxy);
        commProxy.setPushTokenAddress(address(pushToken));

        vm.stopBroadcast();
    }
}
