pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import { BasePushCoreTest } from "../BasePushCoreTest.t.sol";

contract BaseIncentivizedChatRequest is BasePushCoreTest {
    function setUp() public virtual override {
        BasePushCoreTest.setUp();

        vm.startPrank(actor.admin);
        commProxy.setPushCoreAddress(address(coreProxy));
        commProxy.setPushTokenAddress(address(pushToken));
        vm.stopPrank();
    }
}
