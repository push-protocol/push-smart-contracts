// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console2 } from "forge-std/Script.sol";
import { PushCoreV3 } from "contracts/PushCore/PushCoreV3.sol";
import { PushCoreMock } from "contracts/mocks/PushCoreMock.sol";
import { EPNSCoreProxy, ITransparentUpgradeableProxy } from "contracts/PushCore/EPNSCoreProxy.sol";
import { EPNSCoreAdmin } from "contracts/PushCore/EPNSCoreAdmin.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { DeployBase } from './helpers/DeployBase.s.sol';

contract DeployPushNtt is DeployBase {
    struct ConfigParams {
        address pushToken;
        address weth;
        address uniswapV2Router;
        address lendingPoolAave;
        address dai;
        address adai;
        uint256 referralCode;
    }

    PushCoreV3 public pushCoreImpl;
    PushCoreMock public pushCoreMock;
    EPNSCoreProxy public pushCoreProxy;
    EPNSCoreAdmin public pushCoreProxyAdmin;

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        
        // Sanity check deployment parameters.
        ConfigParams memory configParams = _readEnvVariables();

        // Deploy PushCore and its Proxy
        _deployPushCore(configParams);

        vm.stopBroadcast();
    }

    function _deployPushCore(ConfigParams memory configParams) internal {
        address account = vm.addr(vm.envUint("PRIVATE_KEY"));

        console2.log("Deploying PushCore Implementation...");
        pushCoreMock = new PushCoreMock();
        pushCoreImpl = new PushCoreV3();
        console2.log("PushCore Implementation deployed at: ", address(pushCoreImpl));

        console2.log("Deploying PushCore ProxyAdmin...");
        pushCoreProxyAdmin = new EPNSCoreAdmin(account);
        console2.log("PushCore ProxyAdmin deployed at: ", address(pushCoreProxyAdmin));

        console2.log("Deploying PushCore Proxy...");
        pushCoreProxy = new EPNSCoreProxy(
            address(pushCoreMock),
            address(pushCoreProxyAdmin),
            account,
            configParams.pushToken,
            configParams.weth,
            configParams.uniswapV2Router,
            configParams.lendingPoolAave,
            configParams.dai,
            configParams.adai,
            configParams.referralCode
        );
        console2.log("PushCore Proxy deployed at: ", address(pushCoreProxy));

        pushCoreProxyAdmin.upgrade(
            ITransparentUpgradeableProxy(address(pushCoreProxy)),
            address(pushCoreImpl)
        );

        console2.log("All contracts deployed:");
        console2.log("PushCore Implementation: ", address(pushCoreImpl));
        console2.log("PushCore ProxyAdmin: ", address(pushCoreProxyAdmin));
        console2.log("PushCore Proxy: ", address(pushCoreProxy));
    }

    function _readEnvVariables() internal view returns (ConfigParams memory configParams) {
        console2.log("Reading environment variables...");
        configParams.pushToken = vm.envAddress('PUSH_TOKEN_ADDRESS');
        configParams.weth = vm.envAddress('WETH_ADDRESS');
        configParams.uniswapV2Router = vm.envAddress('UNISWAP_V2_ROUTER');
        configParams.lendingPoolAave = vm.envAddress('LENDING_POOL_AAVE');
        configParams.dai = vm.envAddress('DAI_ADDRESS');
        configParams.adai = vm.envAddress('ADAI_ADDRESS');
        configParams.referralCode = vm.envUint('REFERRAL_CODE');

        // Validate the addresses
        require(configParams.pushToken != address(0), "Invalid PUSH_TOKEN_ADDRESS");
        require(configParams.weth != address(0), "Invalid WETH_ADDRESS");
        require(configParams.uniswapV2Router != address(0), "Invalid UNISWAP_V2_ROUTER");
        require(configParams.lendingPoolAave != address(0), "Invalid LENDING_POOL_AAVE");
        require(configParams.dai != address(0), "Invalid DAI_ADDRESS");
        require(configParams.adai != address(0), "Invalid ADAI_ADDRESS");

        console2.log("PUSH_TOKEN_ADDRESS: ", configParams.pushToken);
        console2.log("WETH_ADDRESS: ", configParams.weth);
        console2.log("UNISWAP_V2_ROUTER: ", configParams.uniswapV2Router);
        console2.log("LENDING_POOL_AAVE: ", configParams.lendingPoolAave);
        console2.log("DAI_ADDRESS: ", configParams.dai);
        console2.log("ADAI_ADDRESS: ", configParams.adai);
        console2.log("REFERRAL_CODE: ", configParams.referralCode);
    }
}
