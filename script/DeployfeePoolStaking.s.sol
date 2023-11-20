import "forge-std/Script.sol";
import "forge-std/console.sol";

import "contracts/PushStaking/PushFeePoolProxy.sol";
import "contracts/PushStaking/PushFeePoolStaking.sol";

contract DeployStaking is Script {
    address CoreMainnet = 0x66329Fdd4042928BfCAB60b179e1538D56eeeeeE;
    address CoreGoerli = 0xd4E3ceC407cD36d9e3767cD189ccCaFBF549202C;

    address SepoliaPushToken = 0x37c779a1564DCc0e3914aB130e0e787d93e21804;
    address GoerliPushToken = 0x2b9bE9259a4F5Ba6344c1b1c07911539642a2D33;
    address MainnetPushToken = 0x2b9bE9259a4F5Ba6344c1b1c07911539642a2D33;

    uint _genesisEpoch;
    uint _lastEpochInitialized;
    uint _lastTotalStakeEpochInitialized;
    uint _totalStakedAmount;
    uint _previouslySetEpochRewards;

    function run() public {
        uint pvkey = vm.envUint("PRIVATE");
        address acc = vm.addr(pvkey);
        vm.startBroadcast(pvkey);
        PushFeePoolStaking implementation = new PushFeePoolStaking();

        PushFeePoolProxy proxy = new PushFeePoolProxy(
            address(implementation),
            acc,
            acc,
            CoreMainnet,
            SepoliaPushToken,
            _genesisEpoch,
            _lastEpochInitialized,
            _lastTotalStakeEpochInitialized,
            _totalStakedAmount,
            _previouslySetEpochRewards
        );
        vm.stopBroadcast();
        console.log(address(implementation), address(proxy));

        console.log(PushFeePoolStaking(address(proxy)).genesisEpoch());
        console.log(implementation.genesisEpoch());
    }
}
