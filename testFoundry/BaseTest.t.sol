pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "contracts/token/EPNS.sol";
import "contracts/PushCore/PushCoreStorageV2.sol";
import "contracts/interfaces/IUniswapV2Router.sol";
import "contracts/PushCore/PushCoreStorageV1_5.sol";
import { PushCoreV2 } from "contracts/PushCore/PushCoreV2.sol";
import { PushCommV2 } from "contracts/PushComm/PushCommV2.sol";

import { Actors } from "./utils/Actors.sol";
import { Constants } from "./utils/Constants.sol";

abstract contract BaseTest is Test, Constants {
    EPNS public pushToken;
    PushCoreV2 public core;
    PushCommV2 public comm;
    IUniswapV2Router public uniV2Router;

    /* ***************
        Main Actors in Test
     *************** */
    Actors internal actor;
    address tokenDistributor;

    /* ***************
       Initializing Set-Up for Push Contracts
     *************** */

    function setUp() public virtual {
        tokenDistributor = makeAddr("tokenDistributor");

        pushToken = new EPNS(tokenDistributor);
        core = new PushCoreV2();
        comm = new PushCommV2();
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

        // Initialize Core Contract
        core.initialize(
            actor.admin,
            address(pushToken),
            address(0), // WETH Address
            address(uniV2Router), // Uniswap_Router
            address(0), // Lending_Pool_Aave
            address(0), // Dai_Address
            address(0), // aDai address
            0
        );

        // Initialize Comm Contract
        comm.initialize(actor.admin, "FOUNDRY_TEST_NETWORK");

        // Set-up Core Address in Comm & Vice-Versa
        vm.startPrank(actor.admin);
        comm.setEPNSCoreAddress(address(core));
        core.setEpnsCommunicatorAddress(address(comm));
        vm.stopPrank();
        // Wrapping to exact timestamp of Core and Comm Deployment
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
        // Approve tokens for Core Contract
        approveTokens(actor, address(core), 50_000 ether);
        return actor;
    }
}
