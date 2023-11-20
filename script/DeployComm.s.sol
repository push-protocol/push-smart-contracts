import "forge-std/Script.sol";
import "forge-std/console.sol";

import "contracts/PushComm/EPNSCommProxy.sol";
import "contracts/PushComm/PushCommV2_5.sol";

contract DeployComm is Script {
    function run() public {
        uint pvkey = vm.envUint("PRIVATE");
        address acc = vm.addr(pvkey);
        vm.startBroadcast(pvkey);
        PushCommV2_5 implementation = new PushCommV2_5();

        EPNSCommProxy proxy = new EPNSCommProxy(
            address(implementation),
            acc,
            acc,
            "goerli"
        );
        vm.stopBroadcast();

        console.log(address(implementation), address(proxy));
    }
}
