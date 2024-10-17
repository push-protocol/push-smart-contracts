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

    function test_whenUser_claimsIn_stakedEpoch()external validateShareInvariants{
        // gets zero rewards for that epoch
        StakingTypes.Percentage memory percentAllocation = StakingTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });
        addPool(1000);
        changePrank(actor.admin);
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation);

        uint256 balanceBobBefore = pushToken.balanceOf(actor.bob_channel_owner);
        (uint256 bobWalletSharesBefore, uint256 bobStakedBlockBefore,uint256 bobLastClaimedBlock) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);
        
        //Claims in the same epoch as shares issued
        uint256 expectedRewards = 0;
        vm.expectEmit(true, true, false, true);
        emit RewardsHarvested(actor.bob_channel_owner, expectedRewards, pushStaking.lastEpochRelative(genesisEpoch, bobLastClaimedBlock), getCurrentEpoch() - 1);
        changePrank(actor.bob_channel_owner);
        pushStaking.claimShareRewards();

        (uint256 bobWalletSharesAfter, uint256 bobStakedBlockAfter, uint256 bobClaimedBlockAfter) =
        pushStaking.walletShareInfo(actor.bob_channel_owner);

        assertEq(bobWalletSharesBefore, bobWalletSharesAfter, "Shares");
        assertEq(bobStakedBlockBefore, bobStakedBlockAfter, "StakedBlock");
        assertEq(bobClaimedBlockAfter, genesisEpoch + (getCurrentEpoch() - 1) * epochDuration, "ClaimedBlock");

        uint256 claimedRewards = pushStaking.usersRewardsClaimed(actor.bob_channel_owner);
        assertEq(balanceBobBefore + expectedRewards, pushToken.balanceOf(actor.bob_channel_owner), "Balance");
        assertEq(expectedRewards, claimedRewards);
    }

    function test_WhenUserClaims_in_DifferentEpoch() public validateShareInvariants{
        //SHould succesully Claim the reward
        
        StakingTypes.Percentage memory percentAllocation = StakingTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });
        addPool(1000);
        changePrank(actor.admin);
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation);

        uint256 balanceBobBefore = pushToken.balanceOf(actor.bob_channel_owner);
        (uint256 bobWalletSharesBefore, uint256 bobStakedBlockBefore,uint256 bobLastClaimedBlock) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);
        
        //claims in the second epoch
        roll(epochDuration + 1 );
        uint256 expectedRewards = (coreProxy.WALLET_FEE_POOL() * 20) / 100;
        vm.expectEmit(true, true, false, true);
        emit RewardsHarvested(actor.bob_channel_owner, expectedRewards, pushStaking.lastEpochRelative(genesisEpoch, bobLastClaimedBlock), getCurrentEpoch() - 1);
        changePrank(actor.bob_channel_owner);
        changePrank(actor.bob_channel_owner);
        pushStaking.claimShareRewards();

        (uint256 bobWalletSharesAfter, uint256 bobStakedBlockAfter, uint256 bobClaimedBlockAfter) =
        pushStaking.walletShareInfo(actor.bob_channel_owner);

        assertEq(bobWalletSharesBefore, bobWalletSharesAfter, "Shares");
        assertEq(bobStakedBlockBefore, bobStakedBlockAfter, "StakedBlock");
        assertEq(bobClaimedBlockAfter, genesisEpoch + (getCurrentEpoch() - 1) * epochDuration, "ClaimedBlock");

        uint256 claimedRewards = pushStaking.usersRewardsClaimed(actor.bob_channel_owner);
        assertEq(balanceBobBefore + expectedRewards, pushToken.balanceOf(actor.bob_channel_owner), "Balance");
        assertEq(expectedRewards, claimedRewards);


    }

    function test_whenUser_claimsIn_sameClaimedEpoch()external validateShareInvariants{
        test_WhenUserClaims_in_DifferentEpoch();

        uint256 balanceBobBefore = pushToken.balanceOf(actor.bob_channel_owner);
        uint256 claimedRewardsBefore = pushStaking.usersRewardsClaimed(actor.bob_channel_owner);
        (uint256 bobWalletSharesBefore, uint256 bobStakedBlockBefore,uint256 bobLastClaimedBlock) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);

        // claims again in the second epoch
        vm.expectEmit(true, true, false, true);
        emit RewardsHarvested(actor.bob_channel_owner, 0, pushStaking.lastEpochRelative(genesisEpoch, bobLastClaimedBlock), getCurrentEpoch() - 1);
        changePrank(actor.bob_channel_owner);
        pushStaking.claimShareRewards();

        (uint256 bobWalletSharesAfter2, uint256 bobStakedBlockAfter2, uint256 bobClaimedBlockAfter2) =
        pushStaking.walletShareInfo(actor.bob_channel_owner);

        //No changes in balance and claimed rewards
        assertEq(bobWalletSharesBefore, bobWalletSharesAfter2, "Shares");
        assertEq(bobStakedBlockBefore, bobStakedBlockAfter2, "StakedBlock");
        assertEq(bobClaimedBlockAfter2, genesisEpoch + (getCurrentEpoch() - 1) * epochDuration, "ClaimedBlock");

        uint256 claimedRewards = pushStaking.usersRewardsClaimed(actor.bob_channel_owner);
        assertEq(balanceBobBefore , pushToken.balanceOf(actor.bob_channel_owner), "Balance");
        assertEq(claimedRewardsBefore, claimedRewards);
    }

    function test_whenUser_claimsFor_multipleEpochs()external validateShareInvariants{
        //shares issues in epoch one, reward added in subsequent epoch, wallet claims in 4th epoch
        StakingTypes.Percentage memory percentAllocation = StakingTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });
        addPool(1000);
        changePrank(actor.admin);
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation);

        roll(epochDuration + 1);
        addPool(2000);

        roll(epochDuration * 2 + 1);
        addPool(3000);

        roll(epochDuration * 3 + 1);
        addPool(4000);

        roll(epochDuration * 4 + 1);

        uint256 balanceBobBefore = pushToken.balanceOf(actor.bob_channel_owner);
        (uint256 bobWalletSharesBefore, uint256 bobStakedBlockBefore,uint256 bobLastClaimedBlock) =
            pushStaking.walletShareInfo(actor.bob_channel_owner);

        uint256 expectedRewards = (coreProxy.WALLET_FEE_POOL() * 20) / 100;

        vm.expectEmit(true, true, false, true);
        emit RewardsHarvested(actor.bob_channel_owner, expectedRewards, pushStaking.lastEpochRelative(genesisEpoch, bobLastClaimedBlock), getCurrentEpoch() - 1);

        changePrank(actor.bob_channel_owner);
        pushStaking.claimShareRewards();
    
        (uint256 bobWalletSharesAfter, uint256 bobStakedBlockAfter, uint256 bobClaimedBlockAfter2) =
        pushStaking.walletShareInfo(actor.bob_channel_owner);

        //No changes in balance and claimed rewards
        assertEq(bobWalletSharesBefore, bobWalletSharesAfter, "Shares");
        assertEq(bobStakedBlockBefore, bobStakedBlockAfter, "StakedBlock");
        assertEq(bobClaimedBlockAfter2, genesisEpoch + (getCurrentEpoch() - 1) * epochDuration, "ClaimedBlock");

        uint256 claimedRewards = pushStaking.usersRewardsClaimed(actor.bob_channel_owner);

        assertEq(balanceBobBefore + expectedRewards , pushToken.balanceOf(actor.bob_channel_owner), "Balance");
        assertEq(expectedRewards, claimedRewards);
    }

    function test_whenFoundation_ClaimRewards() external validateShareInvariants{
        StakingTypes.Percentage memory percentAllocation = StakingTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });
        addPool(1000);
        changePrank(actor.admin);
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation);
        roll(epochDuration * 2);
        uint256 balanceAdminBefore = pushToken.balanceOf(actor.admin);
        (uint256 adminWalletSharesBefore, uint256 adminStakedBlockBefore,uint256 adminLastClaimedBlock) = pushStaking.walletShareInfo(actor.admin);

        uint256 expectedRewards = (coreProxy.WALLET_FEE_POOL() * 80) / 100;
        vm.expectEmit(true, true, false, true);
        emit RewardsHarvested(actor.admin, expectedRewards, pushStaking.lastEpochRelative(genesisEpoch, adminLastClaimedBlock), getCurrentEpoch() - 1);
        changePrank(actor.admin);
        pushStaking.claimShareRewards();
        (uint256 adminWalletSharesAfter, uint256 adminStakedBlockAfter, uint256 adminClaimedBlockAfter) =
            pushStaking.walletShareInfo(actor.admin);

        assertEq(adminWalletSharesBefore, adminWalletSharesAfter, "Shares");
        assertEq(adminStakedBlockBefore, adminStakedBlockAfter, "StakedBlock");
        assertEq(adminClaimedBlockAfter, genesisEpoch + (getCurrentEpoch() - 1) * epochDuration, "ClaimedBlock");

        uint256 claimedRewards = pushStaking.usersRewardsClaimed(actor.admin);
        assertEq(balanceAdminBefore + expectedRewards, pushToken.balanceOf(actor.admin), "Balance");
        assertEq(expectedRewards, claimedRewards);
    }

}