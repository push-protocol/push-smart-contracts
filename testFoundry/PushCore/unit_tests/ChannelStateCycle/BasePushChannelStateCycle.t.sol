pragma solidity ^0.8.20;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";

import {BasePushCoreTest} from "../BasePushCoreTest.t.sol";
import {PushCoreStorageV1_5} from "contracts/PushCore/PushCoreStorageV1_5.sol";

contract BasePushChannelStateCycle is BasePushCoreTest {
    
    function setUp() public virtual override {
        BasePushCoreTest.setUp();

        _createChannel(actor.bob_channel_owner);
    }
}
