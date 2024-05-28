// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { BaseTest } from "../../../BaseTest.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";

contract MigrationAdminActions_Test is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();

        vm.prank(actor.governance);
        pushNttToken.mint(address(pushMigrationHelperProxy), 1_000_000 ether);
        vm.prank(tokenDistributor);
        pushToken.transfer(address(pushMigrationHelperProxy), 1_000_000 ether);
    }

    modifier onlyOwner() {
        _;
    }

    function test_Revertwhen_NonAdminCalls_SetNewPushToken() public onlyOwner {
        vm.prank(actor.dan_push_holder);
        vm.expectRevert("Ownable: caller is not the owner");
        pushMigrationHelperProxy.setNewPushToken(address(pushNttToken));
    }

    function test_Revertwhen_newPushToken_ZeroAddress() public onlyOwner {
        vm.prank(actor.admin);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArgument_WrongAddress.selector, address(0)));
        pushMigrationHelperProxy.setNewPushToken(address(0));
    }

    function test_Revertwhen_newPushToken_AlreadySet() public onlyOwner {
        vm.startPrank(actor.admin);
        pushMigrationHelperProxy.setNewPushToken(address(pushNttToken));

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArgument_WrongAddress.selector, address(pushToken)));
        pushMigrationHelperProxy.setNewPushToken(address(pushToken));
        vm.stopPrank();
    }

    function test_SetNewPushToken() public onlyOwner {
        vm.startPrank(actor.admin);
        address newPushTokenBefore = address(pushMigrationHelperProxy.newPushToken());

        pushMigrationHelperProxy.setNewPushToken(address(pushNttToken));
        address newPushTokenAfter = address(pushMigrationHelperProxy.newPushToken());
        vm.stopPrank();

        assertEq(newPushTokenBefore, address(0));
        assertEq(newPushTokenAfter, address(pushNttToken));
    }

    function test_Revertwhen_NonAdminCalls_ToggleUnMigrationStatus() public onlyOwner {
        vm.prank(actor.dan_push_holder);
        vm.expectRevert("Ownable: caller is not the owner");
        pushMigrationHelperProxy.toggleUnMigrationStatus(true);
    }

    function test_ToggleUnMigrationStatus() public onlyOwner {
        bool unmigrationPausedBeforeFirstSet = pushMigrationHelperProxy.unMigrationPaused();
        vm.prank(actor.admin);
        pushMigrationHelperProxy.toggleUnMigrationStatus(true);
        bool unmigrationPausedAfterFirstSet = pushMigrationHelperProxy.unMigrationPaused();

        assertEq(unmigrationPausedBeforeFirstSet, false);
        assertEq(unmigrationPausedAfterFirstSet, true);

        bool unmigrationPausedBeforeSecondSet = pushMigrationHelperProxy.unMigrationPaused();
        vm.prank(actor.admin);
        pushMigrationHelperProxy.toggleUnMigrationStatus(false);
        bool unmigrationPausedAfterSecondSet = pushMigrationHelperProxy.unMigrationPaused();

        assertEq(unmigrationPausedBeforeSecondSet, true);
        assertEq(unmigrationPausedAfterSecondSet, false);
    }

    function test_Revertwhen_NonAdminCalls_BurnOldTokens() public onlyOwner {
        vm.prank(actor.dan_push_holder);
        vm.expectRevert("Ownable: caller is not the owner");
        pushMigrationHelperProxy.burnOldTokens(1000 ether);
    }

    function test_Revertwhen_BurnOldTokens_AmountMoreThanBalance() public onlyOwner {
        vm.prank(actor.admin);
        vm.expectRevert(bytes("Push::_transferTokens: transfer amount exceeds balance"));
        pushMigrationHelperProxy.burnOldTokens(10_000_000 ether);
    }

    function test_BurnOldTokens() public onlyOwner {
        uint256 burnTokenAmount = 100_000 ether;
        address deadAddress = 0x000000000000000000000000000000000000dEaD;

        uint256 deadOldPushTokenBalanceBefore = pushToken.balanceOf(deadAddress);
        uint256 migrationHelperOldPushTokenBalanceBefore = pushToken.balanceOf(address(pushMigrationHelperProxy));

        vm.prank(actor.admin);
        pushMigrationHelperProxy.burnOldTokens(burnTokenAmount);

        uint256 deadOldPushTokenBalanceAfter = pushToken.balanceOf(deadAddress);
        uint256 migrationHelperOldPushTokenBalanceAfter = pushToken.balanceOf(address(pushMigrationHelperProxy));

        assertEq(deadOldPushTokenBalanceAfter - deadOldPushTokenBalanceBefore, burnTokenAmount);
        assertEq(migrationHelperOldPushTokenBalanceBefore - migrationHelperOldPushTokenBalanceAfter, burnTokenAmount);
    }
}
