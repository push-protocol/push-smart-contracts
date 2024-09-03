// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { BaseTest } from "../../../BaseTest.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";

contract Burn_Test is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    function test_BurnFuzz(address user, uint256 balanceAmount, uint256 burnAmount) public {
        vm.assume(user != address(0) && user != address(nttProxyAdmin));
        balanceAmount = bound(balanceAmount, 1, 100_000_000e18);
        burnAmount = bound(burnAmount, 0, balanceAmount);

        vm.prank(actor.governance);
        pushNttToken.mint(actor.admin, balanceAmount);

        vm.prank(actor.admin);
        pushNttToken.transfer(user, balanceAmount);

        uint256 userBalanceBefore = pushNttToken.balanceOf(user);
        uint256 totalSupplyBefore = pushNttToken.totalSupply();

        vm.prank(user);
        pushNttToken.burn(burnAmount);
        uint256 userBalanceAfter = pushNttToken.balanceOf(user);
        uint256 totalSupplyAfter = pushNttToken.totalSupply();

        assertEq(userBalanceBefore - userBalanceAfter, burnAmount);
        assertEq(totalSupplyBefore - totalSupplyAfter, burnAmount);
    }
}
