// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { BaseWalletSharesStaking } from "../../BaseWalletSharesStaking.t.sol";
import { StakingTypes } from "../../../../../contracts/libraries/DataTypes.sol";
import {console2} from "forge-std/console2.sol";
import { Errors } from "contracts/libraries/Errors.sol";

contract DecreaseWalletShareTest is BaseWalletSharesStaking {

    function setUp() public virtual override {
        BaseWalletSharesStaking.setUp();
    }

    function test_Revertwhen_Caller_NotGovernance() public validateShareInvariants {
        changePrank(actor.bob_channel_owner);
        StakingTypes.Percentage memory percentAllocation = StakingTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotGovernance.selector));
        pushStaking.decreaseWalletShare(actor.bob_channel_owner, percentAllocation);
    }

    function test_Revertwhen_WalletAddress_Zero_OrFoundation() public validateShareInvariants {
        changePrank(actor.admin);
        StakingTypes.Percentage memory percentAllocation = StakingTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArgument_WrongAddress.selector, address(0)));
        pushStaking.decreaseWalletShare(address(0), percentAllocation);

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArgument_WrongAddress.selector, actor.admin));
        pushStaking.decreaseWalletShare(actor.admin, percentAllocation);
    }

    function test_Revertwhen_InvalidPercentage() public validateShareInvariants {
        changePrank(actor.admin);
        StakingTypes.Percentage memory percentAllocationZero = StakingTypes.Percentage({ percentageNumber: 0, decimalPlaces: 0 });
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArg_MoreThanExpected.selector, 99, 0));
        pushStaking.decreaseWalletShare(actor.bob_channel_owner, percentAllocationZero);

        StakingTypes.Percentage memory percentAllocationHundred = StakingTypes.Percentage({ percentageNumber: 100, decimalPlaces: 0 });
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArg_MoreThanExpected.selector, 99, 0));
        pushStaking.decreaseWalletShare(actor.bob_channel_owner, percentAllocationHundred);
    }

    function test_Revertwhen_Percentage_GE_Allocated() public validateShareInvariants {
        changePrank(actor.admin);
        StakingTypes.Percentage memory percentAllocation1 = StakingTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });
        pushStaking.decreaseWalletShare(actor.bob_channel_owner, percentAllocation1);

        // revert when new allocation is equal to already allocated shares
        StakingTypes.Percentage memory percentAllocation2 = StakingTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArg_MoreThanExpected.selector, 99, 0));
        pushStaking.decreaseWalletShare(actor.bob_channel_owner, percentAllocation2);

        // revert when new allocation is greater than already allocated shares
        StakingTypes.Percentage memory percentAllocation3 = StakingTypes.Percentage({ percentageNumber: 30, decimalPlaces: 0 });
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArg_MoreThanExpected.selector, 99, 0));
        pushStaking.decreaseWalletShare(actor.bob_channel_owner, percentAllocation3);
    }

    function test_DecreaseWalletShare_SameEpoch() public validateShareInvariants {
        addPool(1000);
        changePrank(actor.admin);
        // Add wallet shares of bob
        StakingTypes.Percentage memory percentAllocationFifty = StakingTypes.Percentage({ percentageNumber: 50, decimalPlaces: 0 });
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocationFifty);
        pushStaking.addWalletShare(actor.charlie_channel_owner, percentAllocationFifty);

        uint256 walletTotalSharesBefore = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesBefore = pushStaking.epochToTotalShares(getCurrentEpoch());
        (uint256 charlieWalletSharesBefore, , uint256 charlieClaimedBlockBefore) = pushStaking.walletShareInfo(actor.charlie_channel_owner);
        (uint256 foundationWalletSharesBefore, , ) = pushStaking.walletShareInfo(actor.admin);

        // Decrease wallet shares of charlie from 50 to 40%
        StakingTypes.Percentage memory newPercentAllocationCharlie = StakingTypes.Percentage({ percentageNumber: 40, decimalPlaces: 0 });
        uint256 expectedCharlieShares = (newPercentAllocationCharlie.percentageNumber * charlieWalletSharesBefore) / percentAllocationFifty.percentageNumber;
        emit SharesDecreased(actor.charlie_channel_owner, charlieWalletSharesBefore, expectedCharlieShares);
        pushStaking.decreaseWalletShare(actor.charlie_channel_owner, newPercentAllocationCharlie);

        uint256 walletTotalSharesAfter = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesAfter = pushStaking.epochToTotalShares(getCurrentEpoch());
        (uint256 charlieWalletSharesAfter, , uint256 charlieClaimedBlockAfter) = pushStaking.walletShareInfo(actor.charlie_channel_owner);
        (uint256 foundationWalletSharesAfter, uint256 foundationStakedBlockAfter, ) = pushStaking.walletShareInfo(actor.admin);

        assertEq(charlieWalletSharesAfter, expectedCharlieShares);
        assertEq(walletTotalSharesBefore, walletTotalSharesAfter);
        assertEq(epochToTotalSharesBefore, epochToTotalSharesAfter);
        assertEq(foundationWalletSharesAfter, foundationWalletSharesBefore + (charlieWalletSharesBefore - charlieWalletSharesAfter));
        assertEq(foundationStakedBlockAfter, block.number);
        assertEq(charlieClaimedBlockAfter, charlieClaimedBlockBefore);
    }

    function test_DecreaseWalletShare_DifferentEpoch() public validateShareInvariants {
        addPool(1000);
        changePrank(actor.admin);
        // Add wallet shares of bob
        StakingTypes.Percentage memory percentAllocationFifty = StakingTypes.Percentage({ percentageNumber: 50, decimalPlaces: 0 });
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocationFifty);
        pushStaking.addWalletShare(actor.charlie_channel_owner, percentAllocationFifty);

        roll(epochDuration * 2);
        addPool(1000);

        uint256 walletTotalSharesBefore = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesBefore = pushStaking.epochToTotalShares(getCurrentEpoch());
        (uint256 charlieWalletSharesBefore, , uint256 charlieClaimedBlockBefore) = pushStaking.walletShareInfo(actor.charlie_channel_owner);
        (uint256 foundationWalletSharesBefore, , ) = pushStaking.walletShareInfo(actor.admin);

        // Decrease wallet shares of charlie from 50 to 40%
        StakingTypes.Percentage memory newPercentAllocationCharlie = StakingTypes.Percentage({ percentageNumber: 40, decimalPlaces: 0 });
        uint256 expectedCharlieShares = (newPercentAllocationCharlie.percentageNumber * charlieWalletSharesBefore) / percentAllocationFifty.percentageNumber;
        emit SharesDecreased(actor.charlie_channel_owner, charlieWalletSharesBefore, expectedCharlieShares);
        pushStaking.decreaseWalletShare(actor.charlie_channel_owner, newPercentAllocationCharlie);

        uint256 walletTotalSharesAfter = pushStaking.WALLET_TOTAL_SHARES();
        uint256 epochToTotalSharesAfter = pushStaking.epochToTotalShares(getCurrentEpoch());
        (uint256 charlieWalletSharesAfter, , uint256 charlieClaimedBlockAfter) = pushStaking.walletShareInfo(actor.charlie_channel_owner);
        (uint256 foundationWalletSharesAfter, uint256 foundationStakedBlockAfter, ) = pushStaking.walletShareInfo(actor.admin);

        assertEq(charlieWalletSharesAfter, expectedCharlieShares);
        assertEq(walletTotalSharesBefore, walletTotalSharesAfter);
        assertEq(epochToTotalSharesBefore, epochToTotalSharesAfter);
        assertEq(foundationWalletSharesAfter, foundationWalletSharesBefore + (charlieWalletSharesBefore - charlieWalletSharesAfter));
        assertEq(foundationStakedBlockAfter, block.number);
        assertEq(charlieClaimedBlockAfter, charlieClaimedBlockBefore);
    }
}
