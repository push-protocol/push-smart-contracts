// SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import { PushCoreV3 } from "contracts/PushCore/PushCoreV3.sol";
import { PushCoreMock } from "contracts/mocks/PushCoreMock.sol";
import { EPNSCoreProxy, ITransparentUpgradeableProxy } from "contracts/PushCore/EPNSCoreProxy.sol";
import { EPNSCoreAdmin } from "contracts/PushCore/EPNSCoreAdmin.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/**
 * Command
 * forge script ./scripts/deployment/DeployPushCore.s.sol --verify --etherscan-api-key GJ9ASUPXHA4TH7H36C29878Y95MFKVNJJ3 --fork-url https://1rpc.io/sepolia --private-key [PRIVATE_KEY] --broadcast
 */

contract DeployPushCore is Test {
    PushCoreMock public coreMock;
    PushCoreV3 public coreProxy;
    EPNSCoreProxy public epnsCoreProxy;
    EPNSCoreAdmin public epnsCoreProxyAdmin;

    address public pushToken = 0xe1327FE9b457Ad1b4601FdD2afcAdAef198d6BA6; // sepolia token

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        address account = vm.addr(vm.envUint("PRIVATE_KEY"));

        coreMock = new PushCoreMock();
        coreProxy = new PushCoreV3();

        epnsCoreProxyAdmin = new EPNSCoreAdmin(account);

        epnsCoreProxy = new EPNSCoreProxy(
            address(coreMock),
            address(epnsCoreProxyAdmin),
            account,
            address(pushToken),
            address(0), // WETH Address
            address(0), // Uniswap_Router
            address(0), // Lending_Pool_Aave
            address(0), // Dai_Address
            address(0), // aDai address
            0
        );
        // address admin = address(
        //     uint160(
        //         uint256(
        //             vm.load(address(epnsCoreProxy), 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103)
        //         )
        //     )
        // );
        epnsCoreProxyAdmin.upgrade(ITransparentUpgradeableProxy(address(epnsCoreProxy)), address(coreProxy));
        // EPNSCoreAdmin(admin).upgradeAndCall(
        //     ITransparentUpgradeableProxy(address(epnsCoreProxy)), address(coreProxy), ""
        // );

        coreProxy = PushCoreV3(address(epnsCoreProxy));

        vm.stopBroadcast();
    }
}
