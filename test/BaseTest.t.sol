pragma solidity ^0.8.20;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";

import "contracts/token/EPNS.sol";
import "contracts/interfaces/uniswap/IUniswapV2Router.sol";
import { PushCoreV3 } from "contracts/PushCore/PushCoreV3.sol";
import { PushCoreMock } from "contracts/mocks/PushCoreMock.sol";
import { EPNSCoreProxy, ITransparentUpgradeableProxy } from "contracts/PushCore/EPNSCoreProxy.sol";
import { EPNSCoreAdmin } from "contracts/PushCore/EPNSCoreAdmin.sol";
import { PushCommV2_5 } from "contracts/PushComm/PushCommV2_5.sol";
import { EPNSCommProxy } from "contracts/PushComm/EPNSCommProxy.sol";
import { EPNSCommAdmin } from "contracts/PushComm/EPNSCommAdmin.sol";

import { Actors } from "./utils/Actors.sol";
import { Events } from "./utils/Events.sol";
import { Constants } from "./utils/Constants.sol";

abstract contract BaseTest is Test, Constants, Events {
    EPNS public pushToken;
    PushCoreMock public coreMock;
    PushCoreV3 public coreProxy;
    PushCommV2_5 public comm;
    PushCommV2_5 public commProxy;
    IUniswapV2Router public uniV2Router;
    EPNSCoreProxy public epnsCoreProxy;
    EPNSCoreAdmin public epnsCoreProxyAdmin;
    EPNSCommProxy public epnsCommProxy;
    EPNSCommAdmin public epnsCommProxyAdmin;

    /* ***************
        Main Actors in Test
     *************** */
    Actors internal actor;
    address tokenDistributor;

    /* ***************
        State Variables
     *************** */
    uint256 ADD_CHANNEL_MIN_FEES = 50 ether;
    uint256 ADD_CHANNEL_MAX_POOL_CONTRIBUTION = 250 ether;
    uint256 FEE_AMOUNT = 10 ether;
    uint256 MIN_POOL_CONTRIBUTION = 50 ether;
    uint256 ADJUST_FOR_FLOAT = 10 ** 7;
    mapping(address => uint256) privateKeys;

    /* ***************
       Initializing Set-Up for Push Contracts
     *************** */

    function setUp() public virtual {
        tokenDistributor = makeAddr("tokenDistributor");

        pushToken = new EPNS(tokenDistributor);
        coreMock = new PushCoreMock();
        coreProxy = new PushCoreV3();
        comm = new PushCommV2_5();
        uniV2Router = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

        actor = Actors({
            admin: createActor("admin"),
            governance: createActor("governance"),
            bob_channel_owner: createActor("bob_channel_owner"),
            alice_channel_owner: createActor("alice_channel_owner"),
            charlie_channel_owner: createActor("charlie_channel_owner"),
            tony_channel_owner: createActor("tony_channel_owner"),
            dan_push_holder: createActor("dan_push_holder"),
            tim_push_holder: createActor("tim_push_holder")
        });

        // Initialize coreMock proxy admin and coreProxy contract
        epnsCoreProxy = new EPNSCoreProxy(
            address(coreMock),
            actor.admin,
            actor.admin,
            address(pushToken),
            address(0), // WETH Address
            address(uniV2Router), // Uniswap_Router
            address(0), // Lending_Pool_Aave
            address(0), // Dai_Address
            address(0), // aDai address
            0
        );
        address admin = address(
            uint160(
                uint256(
                    vm.load(address(epnsCoreProxy), 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103)
                )
            )
        );
        vm.prank(actor.admin);
        EPNSCoreAdmin(admin).upgradeAndCall(
            ITransparentUpgradeableProxy(address(epnsCoreProxy)), address(coreProxy), ""
        );

        coreProxy = PushCoreV3(address(epnsCoreProxy));
        vm.prank(tokenDistributor);
        pushToken.transfer(address(coreProxy), 1 ether);

        // Initialize comm proxy admin and commProxy contract
        epnsCommProxyAdmin = new EPNSCommAdmin(actor.admin);
        epnsCommProxy =
            new EPNSCommProxy(address(comm), address(epnsCommProxyAdmin), actor.admin, "FOUNDRY_TEST_NETWORK");
        commProxy = PushCommV2_5(address(epnsCommProxy));

        // Set-up Core Address in Comm & Vice-Versa
        vm.startPrank(actor.admin);
        commProxy.setEPNSCoreAddress(address(coreProxy));
        commProxy.setPushTokenAddress(address(pushToken));
        coreProxy.setEpnsCommunicatorAddress(address(commProxy));
        vm.stopPrank();

        // Approve tokens of actors now to core contract proxy address
        approveTokens(actor.admin, address(coreProxy), 50_000 ether);
        approveTokens(actor.governance, address(coreProxy), 50_000 ether);
        approveTokens(actor.bob_channel_owner, address(coreProxy), 50_000 ether);
        approveTokens(actor.alice_channel_owner, address(coreProxy), 50_000 ether);
        approveTokens(actor.charlie_channel_owner, address(coreProxy), 50_000 ether);
        approveTokens(actor.dan_push_holder, address(coreProxy), 50_000 ether);
        approveTokens(actor.tim_push_holder, address(coreProxy), 50_000 ether);
        vm.warp(DEC_27_2021);
    }

    /* ***************
       Core Contract Helper Functions
    *************** */

    function roll(uint256 num) internal {
        vm.roll(num);
    }

    function approveTokens(address from, address to, uint256 amount) internal {
        vm.startPrank(from);
        pushToken.approve(to, amount);
        pushToken.setHolderDelegation(to, true);
        vm.stopPrank();
    }

    function createActor(string memory name) internal returns (address payable) {
        address actor;
        uint256 Private;
        (actor, Private) = makeAddrAndKey(name);
        address payable _actor = payable(actor);
        privateKeys[actor] = Private;
        // Transfer 50 eth to every actor
        vm.deal({ account: _actor, newBalance: 50 ether });
        // Transfer 50K PUSH Tokens for every actor
        vm.prank(tokenDistributor);
        pushToken.transfer(_actor, 50_000 ether);
        return _actor;
    }
}
