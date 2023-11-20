import "forge-std/Script.sol";
import "forge-std/console.sol";

import "contracts/PushCore/EPNSCoreProxy.sol";
import "contracts/PushCore/PushCoreV2_Temp.sol";

contract DeployCore is Script {
    address SepoliaPushToken = 0x37c779a1564DCc0e3914aB130e0e787d93e21804;
    address GoerliPushToken = 0x2b9bE9259a4F5Ba6344c1b1c07911539642a2D33;
    address MainnetPushToken = 0x2b9bE9259a4F5Ba6344c1b1c07911539642a2D33;
    address _wethAddress = address(0);
    address _uniswapRouterAddress = address(0);
    address _lendingPoolProviderAddress = address(0);
    address _daiAddress = address(0);
    address _aDaiAddress = address(0);
    uint256 _referralCode = 0;

    function run() public {
        uint pvkey = vm.envUint("PRIVATE");
        address acc = vm.addr(pvkey);
        vm.startBroadcast(pvkey);
        PushCoreV2_Temp implementation = new PushCoreV2_Temp();

        EPNSCoreProxy proxy = new EPNSCoreProxy(
            address(implementation),
            acc,
            acc,
            SepoliaPushToken,
            _wethAddress,
            _uniswapRouterAddress,
            _lendingPoolProviderAddress,
            _daiAddress,
            _aDaiAddress,
            _referralCode
        );
        vm.stopBroadcast();
        console.log(address(implementation), address(proxy));
    }
}
