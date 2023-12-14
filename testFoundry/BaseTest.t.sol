pragma solidity ^0.8.20;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";

import "contracts/token/EPNS.sol";
import "contracts/interfaces/IUniswapV2Router.sol";
import { PushCoreV2_5 } from "contracts/PushCore/PushCoreV2_5.sol";
import { EPNSCoreProxy } from "contracts/PushCore/EPNSCoreProxy.sol";
import { EPNSCoreAdmin } from "contracts/PushCore/EPNSCoreAdmin.sol";
import { PushCommV2_5 } from "contracts/PushComm/PushCommV2_5.sol";
import { EPNSCommProxy } from "contracts/PushComm/EPNSCommProxy.sol";
import { EPNSCommAdmin } from "contracts/PushComm/EPNSCommAdmin.sol";

import { Actors } from "./utils/Actors.sol";
import { CoreEvents } from "./utils/CoreEvents.sol";
import { Constants } from "./utils/Constants.sol";

abstract contract BaseTest is Test, Constants, CoreEvents {
    EPNS public pushToken;
    PushCoreV2_5 public core;
    PushCoreV2_5 public coreProxy;
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

    /* ***************
       Initializing Set-Up for Push Contracts
     *************** */

    function setUp() public virtual {
        tokenDistributor = makeAddr("tokenDistributor");

        pushToken = new EPNS(tokenDistributor);
        core = new PushCoreV2_5();
        comm = new PushCommV2_5();
        uniV2Router = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

        actor = Actors({
            admin: createActor("admin"),
            governance: createActor("governance"),
            bob_channel_owner: createActor("bob_channel_owner"),
            alice_channel_owner: createActor("alice_channel_owner"),
            charlie_channel_owner: createActor("charlie_channel_owner"),
            dan_push_holder: createActor("dan_push_holder"),
            tim_push_holder: createActor("tim_push_holder")
        });

        // Initialize core proxy admin and coreProxy contract
        epnsCoreProxyAdmin = new EPNSCoreAdmin(actor.admin);
        epnsCoreProxy = new EPNSCoreProxy(
            address(core),
            address(epnsCoreProxyAdmin),
            actor.admin,
            address(pushToken),
            address(0), // WETH Address
            address(uniV2Router), // Uniswap_Router
            address(0), // Lending_Pool_Aave
            address(0), // Dai_Address
            address(0), // aDai address
            0
        );
        coreProxy = PushCoreV2_5(address(epnsCoreProxy));

        // Initialize comm proxy admin and commProxy contract
        epnsCommProxyAdmin = new EPNSCommAdmin(actor.admin);
        epnsCommProxy = new EPNSCommProxy(
            address(comm),
            address(epnsCommProxyAdmin),
            actor.admin,
            "FOUNDRY_TEST_NETWORK"
        );
        commProxy = PushCommV2_5(address(epnsCommProxy));

        // Set-up Core Address in Comm & Vice-Versa
        vm.startPrank(actor.admin);
        commProxy.setEPNSCoreAddress(address(coreProxy));
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
        address payable actor = payable(makeAddr(name));
        // Transfer 50 eth to every actor
        vm.deal({ account: actor, newBalance: 50 ether });
        // Transfer 50K PUSH Tokens for every actor
        vm.prank(tokenDistributor);
        pushToken.transfer(actor, 50_000 ether);
        return actor;
    }
}
