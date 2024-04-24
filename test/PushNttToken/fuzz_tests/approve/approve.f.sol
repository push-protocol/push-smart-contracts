// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { BaseTest } from "../../../BaseTest.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";

contract Approve_Test is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    function test_ApproveFuzz(address spender, uint256 rawAmount) public {
        uint256 allowanceBefore = pushNttToken.allowance(actor.dan_push_holder, spender);

        vm.prank(actor.dan_push_holder);
        pushNttToken.approve(spender, rawAmount);

        if (rawAmount >= type(uint96).max) {
            rawAmount = type(uint96).max;
        }

        uint256 allowanceAfter = pushNttToken.allowance(actor.dan_push_holder, spender);
        assertEq(allowanceAfter, allowanceBefore + rawAmount);
    }
}
