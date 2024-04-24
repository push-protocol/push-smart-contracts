// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { BaseTest } from "../../../BaseTest.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";

contract MigratePushTokensTo_Test is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();

        // Set newToken in pushMigration
        vm.prank(actor.admin);
        pushMigrationHelperProxy.setNewPushToken(address(pushNttToken));

        vm.prank(actor.governance);
        pushNttToken.mint(address(pushMigrationHelperProxy), 1_000_000 ether);
    }

    modifier whenNotPaused() {
        _;
    }

    function test_Revertwhen_AllowanceNotEnough() public whenNotPaused {
        vm.prank(actor.dan_push_holder);
        vm.expectRevert(bytes("Push::transferFrom: transfer amount exceeds spender allowance"));
        pushMigrationHelperProxy.migratePushTokensTo(actor.tim_push_holder, 100 ether);
    }

    function test_Revertwhen_BalanceNotEnough() public whenNotPaused {
        approveTokens(actor.dan_push_holder, address(pushMigrationHelperProxy), 100_000 ether);

        vm.prank(actor.dan_push_holder);
        vm.expectRevert(bytes("Push::_transferTokens: transfer amount exceeds balance"));
        pushMigrationHelperProxy.migratePushTokensTo(actor.tim_push_holder, 100_000 ether);
    }

    function test_Revertwhen_RecipientZeroAddress() public whenNotPaused {
        approveTokens(actor.dan_push_holder, address(pushMigrationHelperProxy), 5_000 ether);

        vm.prank(actor.dan_push_holder);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArgument_WrongAddress.selector, address(0)));
        pushMigrationHelperProxy.migratePushTokensTo(address(0), 5000 ether);
    }

    function test_MigratePushTokensTo() public whenNotPaused {
        uint256 migrationTokenAmount = 5_000 ether;
        address recipient = actor.tim_push_holder;
        approveTokens(actor.dan_push_holder, address(pushMigrationHelperProxy), migrationTokenAmount);

        uint256 danOldPushTokenBalanceBefore = pushToken.balanceOf(actor.dan_push_holder);
        uint256 migrationHelperOldPushTokenBalanceBefore = pushToken.balanceOf(address(pushMigrationHelperProxy));
        uint256 danNewPushTokenBalanceBefore = pushNttToken.balanceOf(actor.dan_push_holder);
        uint256 migrationHelperNewPushTokenBalanceBefore = pushNttToken.balanceOf(address(pushMigrationHelperProxy));
        uint256 recipientNewPushTokenBalanceBefore = pushNttToken.balanceOf(recipient);

        vm.expectEmit(true, true, false, true, address(pushMigrationHelperProxy));
        emit TokenMigrated(actor.dan_push_holder, recipient, migrationTokenAmount);

        vm.prank(actor.dan_push_holder);
        pushMigrationHelperProxy.migratePushTokensTo(recipient, migrationTokenAmount);

        uint256 danOldPushTokenBalanceAfter = pushToken.balanceOf(actor.dan_push_holder);
        uint256 migrationHelperOldPushTokenBalanceAfter = pushToken.balanceOf(address(pushMigrationHelperProxy));
        uint256 danNewPushTokenBalanceAfter = pushNttToken.balanceOf(actor.dan_push_holder);
        uint256 migrationHelperNewPushTokenBalanceAfter = pushNttToken.balanceOf(address(pushMigrationHelperProxy));
        uint256 recipientNewPushTokenBalanceAfter = pushNttToken.balanceOf(recipient);

        assertEq(danOldPushTokenBalanceBefore - danOldPushTokenBalanceAfter, migrationTokenAmount);
        assertEq(migrationHelperOldPushTokenBalanceAfter - migrationHelperOldPushTokenBalanceBefore, migrationTokenAmount);
        assertEq(danNewPushTokenBalanceAfter, danNewPushTokenBalanceBefore);
        assertEq(migrationHelperNewPushTokenBalanceBefore - migrationHelperNewPushTokenBalanceAfter, migrationTokenAmount);
        assertEq(recipientNewPushTokenBalanceAfter - recipientNewPushTokenBalanceBefore, migrationTokenAmount);
    }
}
