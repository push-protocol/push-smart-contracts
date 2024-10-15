pragma solidity ^0.8.20;
pragma experimental ABIEncoderV2;

import { BasePushStaking } from "../BasePushStaking.t.sol";

contract BaseWalletSharesStaking is BasePushStaking {

    function setUp() public virtual override {
        BasePushStaking.setUp();
    }
}
