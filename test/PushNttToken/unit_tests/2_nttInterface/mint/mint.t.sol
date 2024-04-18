// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { BaseTest } from "../../../../BaseTest.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";

contract Mint_Test is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    modifier onlyMinter() {
        _;
    }

    function test_Revertwhen_CallerNotMinter() public onlyMinter {
        vm.prank(actor.admin);
        pushNttToken.setMinter(actor.admin);

        vm.prank(actor.dan_push_holder);
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotMinter.selector, actor.dan_push_holder));
        pushNttToken.mint(actor.dan_push_holder, 10 ether);
    }

    function test_Revertwhen_AccountZeroAddress() public onlyMinter {
        vm.startPrank(actor.admin);
        pushNttToken.setMinter(actor.admin);
        vm.expectRevert(bytes("Push::mint: cannot mint tokens to the zero address"));
        pushNttToken.mint(address(0), 10 ether);
        vm.stopPrank();
    }

    function test_Revertwhen_AmountExceedsLimit() public onlyMinter {
        vm.startPrank(actor.admin);
        pushNttToken.setMinter(actor.admin);
        vm.expectRevert(bytes("Push::mint: amount exceeds 96 bits"));
        pushNttToken.mint(actor.dan_push_holder, UINT256_MAX);
        vm.stopPrank();
    }

    function test_Mint() public onlyMinter {
        vm.startPrank(actor.admin);
        pushNttToken.setMinter(actor.admin);

        uint256 danBalanceBefore = pushNttToken.balanceOf(actor.dan_push_holder);
        uint256 totalSupplyBefore = pushNttToken.totalSupply();

        vm.expectEmit(true, true, false, true, address(pushNttToken));
        emit Transfer(address(0), actor.dan_push_holder, 10 ether);

        pushNttToken.mint(actor.dan_push_holder, 10 ether);
        uint256 danBalanceAfter = pushNttToken.balanceOf(actor.dan_push_holder);
        uint256 totalSupplyAfter = pushNttToken.totalSupply();
        vm.stopPrank();

        assertEq(danBalanceAfter - danBalanceBefore, 10 ether);
        assertEq(totalSupplyAfter - totalSupplyBefore, 10 ether);
    }
}
