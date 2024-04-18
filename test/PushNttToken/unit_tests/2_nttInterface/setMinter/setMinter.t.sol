// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { BaseTest } from "../../../../BaseTest.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";

contract SetMinter_Test is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    modifier onlyOwner() {
        _;
    }

    function test_Revertwhen_CallerNotOwner() public onlyOwner {
        vm.prank(actor.dan_push_holder);
        vm.expectRevert(abi.encodeWithSelector(Errors.OwnableUnauthorizedAccount.selector, actor.dan_push_holder));
        pushNttToken.setMinter(actor.admin);
    }

    function test_Revertwhen_ZeroAddressPassed() public onlyOwner {
        vm.prank(actor.admin);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidMinterZeroAddress.selector));
        pushNttToken.setMinter(address(0));
    }

    function test_SetMinter() public onlyOwner {
        address minterBefore = pushNttToken.minter();

        vm.expectEmit(true, false, false, true, address(pushNttToken));
        emit NewMinter(actor.dan_push_holder);

        vm.prank(actor.admin);
        pushNttToken.setMinter(actor.dan_push_holder);
        address minterAfter = pushNttToken.minter();

        assertEq(minterAfter, actor.dan_push_holder);
        assertEq(minterBefore, address(0));
    }
}
