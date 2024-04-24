// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { BaseTest } from "../../../../BaseTest.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";

contract Burn_Test is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();

        vm.prank(actor.governance);
        pushNttToken.mint(actor.admin, 1e5 ether);
    }

    function test_Revertwhen_AmountExceedsLimit() public {
        vm.prank(actor.admin);
        pushNttToken.transfer(actor.dan_push_holder, 10 ether);

        vm.prank(actor.dan_push_holder);
        vm.expectRevert(bytes("Push::burn: amount exceeds 96 bits"));
        pushNttToken.burn(UINT256_MAX);
    }

    function test_Revertwhen_AmountExceedsBalance() public {
        vm.prank(actor.admin);
        pushNttToken.transfer(actor.dan_push_holder, 10 ether);

        vm.prank(actor.dan_push_holder);
        vm.expectRevert(bytes("Push::burn: burn amount exceeds balance"));
        pushNttToken.burn(15 ether);
    }

    function test_Burn() public {
        vm.prank(actor.admin);
        pushNttToken.transfer(actor.dan_push_holder, 10 ether);

        uint256 danBalanceBefore = pushNttToken.balanceOf(actor.dan_push_holder);
        uint256 totalSupplyBefore = pushNttToken.totalSupply();

        vm.expectEmit(true, true, false, true, address(pushNttToken));
        emit Transfer(actor.dan_push_holder, address(0), 5 ether);

        vm.prank(actor.dan_push_holder);
        pushNttToken.burn(5 ether);
        uint256 danBalanceAfter = pushNttToken.balanceOf(actor.dan_push_holder);
        uint256 totalSupplyAfter = pushNttToken.totalSupply();

        assertEq(danBalanceBefore - danBalanceAfter, 5 ether);
        assertEq(totalSupplyBefore - totalSupplyAfter, 5 ether);
    }
}
