// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { BaseTest } from "../../../BaseTest.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import "forge-std/console.sol";

contract MigratePushTokens_Test is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();

        // Set newToken in pushMigration
        vm.prank(actor.admin);
        pushMigrationHelperProxy.setNewPushToken(address(pushNttToken));

        vm.prank(actor.admin);
        pushNttToken.transfer(address(pushMigrationHelperProxy), 1_000_000 ether);
    }

    modifier whenUnMigrationIsAllowed() {
        _;
    }

    function test_Revertwhen_AllowanceNotEnough() public whenUnMigrationIsAllowed {
        vm.prank(actor.dan_push_holder);
        vm.expectRevert(bytes("Push::transferFrom: transfer amount exceeds spender allowance"));
        pushMigrationHelperProxy.unmigratePushTokens(100 ether);
    }

    function test_Revertwhen_BalanceNotEnough() public whenUnMigrationIsAllowed {
        approveNttTokens(actor.dan_push_holder, address(pushMigrationHelperProxy), 100_000 ether);

        vm.prank(actor.dan_push_holder);
        vm.expectRevert(bytes("Push::_transferTokens: transfer amount exceeds balance"));
        pushMigrationHelperProxy.unmigratePushTokens(100_000 ether);
    }

    function test_UnMigrateTokens() public whenUnMigrationIsAllowed {
        uint256 migrationTokenAmount = 5_000 ether;
        // migrate tokens
        approveTokens(actor.dan_push_holder, address(pushMigrationHelperProxy), migrationTokenAmount);
        vm.prank(actor.dan_push_holder);
        pushMigrationHelperProxy.migratePushTokens(migrationTokenAmount);
        approveNttTokens(actor.dan_push_holder, address(pushMigrationHelperProxy), migrationTokenAmount);

        uint256 danOldPushTokenBalanceBefore = pushToken.balanceOf(actor.dan_push_holder);
        uint256 migrationHelperOldPushTokenBalanceBefore = pushToken.balanceOf(address(pushMigrationHelperProxy));
        uint256 danNewPushTokenBalanceBefore = pushNttToken.balanceOf(actor.dan_push_holder);
        uint256 migrationHelperNewPushTokenBalanceBefore = pushNttToken.balanceOf(address(pushMigrationHelperProxy));

        vm.expectEmit(true, true, false, true, address(pushMigrationHelperProxy));
        emit TokenUnmigrated(actor.dan_push_holder, migrationTokenAmount);

        vm.prank(actor.dan_push_holder);
        pushMigrationHelperProxy.unmigratePushTokens(migrationTokenAmount);

        uint256 danOldPushTokenBalanceAfter = pushToken.balanceOf(actor.dan_push_holder);
        uint256 migrationHelperOldPushTokenBalanceAfter = pushToken.balanceOf(address(pushMigrationHelperProxy));
        uint256 danNewPushTokenBalanceAfter = pushNttToken.balanceOf(actor.dan_push_holder);
        uint256 migrationHelperNewPushTokenBalanceAfter = pushNttToken.balanceOf(address(pushMigrationHelperProxy));

        assertEq(danOldPushTokenBalanceAfter - danOldPushTokenBalanceBefore, migrationTokenAmount);
        assertEq(migrationHelperOldPushTokenBalanceBefore - migrationHelperOldPushTokenBalanceAfter, migrationTokenAmount);
        assertEq(danNewPushTokenBalanceBefore - danNewPushTokenBalanceAfter, migrationTokenAmount);
        assertEq(migrationHelperNewPushTokenBalanceAfter - migrationHelperNewPushTokenBalanceBefore, migrationTokenAmount);
    }
}
