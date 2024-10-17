// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { BaseWalletSharesStaking } from "../../BaseWalletSharesStaking.t.sol";
import { StakingTypes } from "../../../../../contracts/libraries/DataTypes.sol";
import {console2} from "forge-std/console2.sol";
import { Errors } from "contracts/libraries/Errors.sol";

contract ClaimRewardsTest is BaseWalletSharesStaking {

    function setUp() public virtual override {
        BaseWalletSharesStaking.setUp();
    }

}