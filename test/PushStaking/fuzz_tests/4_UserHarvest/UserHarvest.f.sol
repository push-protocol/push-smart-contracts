pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import { BaseFuzzStaking } from "../BaseFuzzStaking.f.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { PushVoteDelegator } from "contracts/PushStaking/PushVoteDelegator.sol";

contract UserHarvest_test is BaseFuzzStaking {
    function setUp() public virtual override {
        BaseFuzzStaking.setUp();
    }

    // actor.bob_channel_owner Stakes at EPOCH 1 and Harvests alone- Should get all rewards
    function test_HarvestAlone(uint256 _fee, uint256 _amount, uint256 _passEpoch) public {
        uint256 balanceBefore = pushToken.balanceOf(actor.bob_channel_owner);

        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        _amount = bound(_amount, 1, balanceBefore / 1e18);
        _passEpoch = bound(_passEpoch, 2, 22);

        changePrank(actor.bob_channel_owner);
        pushToken.delegate(actor.bob_channel_owner);
        uint256 beforeVotes = pushToken.getCurrentVotes(actor.bob_channel_owner);

        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);
        changePrank(actor.bob_channel_owner);
        PushVoteDelegator _voteDelegator = feePoolStaking.preserveVotingPower(actor.bob_channel_owner);
        assertEq(pushToken.balanceOf(address(_voteDelegator)), _amount * 1e18);

        roll(epochDuration * _passEpoch);
        harvest(actor.bob_channel_owner);
        daoHarvest(actor.admin, _passEpoch - 1);
        uint256 adminClaimed = feePoolStaking.usersRewardsClaimed(address(coreProxy));
        uint256 claimed = feePoolStaking.usersRewardsClaimed(actor.bob_channel_owner);

        changePrank(actor.bob_channel_owner);
        pushToken.delegate(actor.bob_channel_owner);
        uint256 afterVotes = pushToken.getCurrentVotes(actor.bob_channel_owner);
        assertEq(afterVotes, claimed + beforeVotes, "Unequal Votes");

        assertApproxEqAbs(claimed, _fee * 1e18, (adminClaimed) * 1e18);
    }

    //actor.bob_channel_owner Stakes after EPOCH 1 and Harvests alone- Should get all rewards
    function test_HarvestAloneAfterOneEpoch(uint256 _fee, uint256 _amount, uint256 _passEpoch) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        _amount = bound(_amount, 1, pushToken.balanceOf(actor.bob_channel_owner) / 1e18);
        _passEpoch = bound(_passEpoch, 2, 22);

        changePrank(actor.bob_channel_owner);
        pushToken.delegate(actor.bob_channel_owner);
        uint256 beforeVotes = pushToken.getCurrentVotes(actor.bob_channel_owner);
        roll(epochDuration * _passEpoch);
        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);

        PushVoteDelegator _voteDelegator = feePoolStaking.preserveVotingPower(actor.bob_channel_owner);

        roll(epochDuration * (_passEpoch + 1));
        harvest(actor.bob_channel_owner);
        daoHarvest(actor.admin, _passEpoch);
        uint256 adminClaimed = feePoolStaking.usersRewardsClaimed(address(coreProxy));
        uint256 claimed = feePoolStaking.usersRewardsClaimed(actor.bob_channel_owner);
        changePrank(actor.bob_channel_owner);
        pushToken.delegate(actor.bob_channel_owner);
        uint256 afterVotes = pushToken.getCurrentVotes(actor.bob_channel_owner);
        assertEq(afterVotes, claimed + beforeVotes, "Unequal Votes");
        assertApproxEqAbs(claimed, _fee * 1e18, adminClaimed + 1e18);
    }

    //  actor.bob_channel_owner Stakes and Harvests alone in same Epoch- Should get ZERO rewards
    function test_StakeharvestSameEpoch(uint256 _amount, uint256 _fee, uint256 _passEpoch) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        _amount = bound(_amount, 1, pushToken.balanceOf(actor.bob_channel_owner) / 1e18);

        _passEpoch = bound(_passEpoch, 2, 22);
        roll(epochDuration * _passEpoch);
        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);
        harvest(actor.bob_channel_owner);

        assertEq(feePoolStaking.usersRewardsClaimed(actor.bob_channel_owner), 0);
    }

    //   bob stakes at epoch 2 and claims at epoch 9 using harvestAll()",
    function test_StakeharvestNineEpoch(uint256 _amount, uint256 _fee, uint256 _passEpoch) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        _amount = bound(_amount, 1, pushToken.balanceOf(actor.bob_channel_owner) / 1e18);

        _passEpoch = bound(_passEpoch, 2, 12);
        roll(epochDuration * _passEpoch);
        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);
        roll(epochDuration * (_passEpoch + 9));
        harvest(actor.bob_channel_owner);
        daoHarvest(actor.admin, _passEpoch + 8);

        assertApproxEqAbs(
            feePoolStaking.usersRewardsClaimed(actor.bob_channel_owner),
            _fee * 1e18,
            (feePoolStaking.usersRewardsClaimed(address(coreProxy)) + 5) * 1e18
        );
    }

    //actor.bob_channel_owner & actor.alice_channel_owner Stakes(Same Amount) and Harvests together- Should get equal
    // rewards
    function test_HarvestEqual(uint256 _fee, uint256 _amount, uint256 _passEpoch) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        vm.assume(
            _amount <= pushToken.balanceOf(actor.bob_channel_owner) / 1e18
                && _amount <= pushToken.balanceOf(actor.alice_channel_owner) / 1e18
        );
        _passEpoch = bound(_passEpoch, 2, 22);

        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);
        stake(actor.alice_channel_owner, _amount);
        roll(epochDuration * _passEpoch);
        harvest(actor.bob_channel_owner);
        harvest(actor.alice_channel_owner);
        uint256 bobClaimed = feePoolStaking.usersRewardsClaimed(actor.bob_channel_owner);
        uint256 aliceClaimed = feePoolStaking.usersRewardsClaimed(actor.alice_channel_owner);
        assertEq(bobClaimed, aliceClaimed);
    }

    // actor.bob_channel_owner stakes abit later than actor.alice_channel_owner. actor.bob_channel_owner &
    // actor.alice_channel_owner Stakes(Same Amount) and Harvests together - they get equal rewards
    function test_StakeAndClaimSameEpoch(
        uint256 _amount,
        uint256 _fee,
        uint256 _passEpoch,
        uint256 _passBlocks
    )
        public
    {
        vm.assume(
            _amount <= pushToken.balanceOf(actor.bob_channel_owner) / 1e18
                && _amount <= pushToken.balanceOf(actor.alice_channel_owner) / 1e18
        );

        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        _passEpoch = bound(_passEpoch, 2, 22);
        _passBlocks = bound(_passBlocks, 1, epochDuration);

        stake(actor.bob_channel_owner, _amount);
        addPool(_fee);
        roll(_passBlocks);
        stake(actor.alice_channel_owner, _amount);
        roll(_passEpoch * epochDuration);
        harvest(actor.bob_channel_owner);
        harvest(actor.alice_channel_owner);

        assertEq(
            feePoolStaking.usersRewardsClaimed(actor.bob_channel_owner),
            feePoolStaking.usersRewardsClaimed(actor.alice_channel_owner)
        );
    }

    //4 Users Stakes(Same Amount) and Harvests together- Should get equal rewards
    function test_HarvestEqualFourPeople(uint256 _fee, uint256 _amount, uint256 _passEpoch) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        vm.assume(
            _amount <= pushToken.balanceOf(actor.bob_channel_owner) / 1e18
                && _amount <= pushToken.balanceOf(actor.alice_channel_owner) / 1e18
        );
        _passEpoch = bound(_passEpoch, 2, 22);

        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);
        stake(actor.alice_channel_owner, _amount);
        stake(actor.charlie_channel_owner, _amount);
        stake(actor.tony_channel_owner, _amount);
        roll(epochDuration * _passEpoch);
        harvest(actor.bob_channel_owner);
        harvest(actor.alice_channel_owner);
        harvest(actor.charlie_channel_owner);
        harvest(actor.tony_channel_owner);
        uint256 bobClaimed = feePoolStaking.usersRewardsClaimed(actor.bob_channel_owner);
        uint256 aliceClaimed = feePoolStaking.usersRewardsClaimed(actor.alice_channel_owner);
        uint256 charlieclaimed = feePoolStaking.usersRewardsClaimed(actor.charlie_channel_owner);
        uint256 tonyclaimed = feePoolStaking.usersRewardsClaimed(actor.tony_channel_owner);

        assertTrue(charlieclaimed == tonyclaimed && bobClaimed == aliceClaimed && bobClaimed == charlieclaimed);
    }

    //  4 Users Stakes different amount and Harvests together- Last Claimer & Major Staker Gets More
    function test_DifferentAmounts(uint256 _fee, uint256 _amount, uint256 _passEpoch) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        vm.assume(
            _amount <= pushToken.balanceOf(actor.bob_channel_owner) / 1e18
                && _amount <= (pushToken.balanceOf(actor.alice_channel_owner) / 1e18) + 100
                && _amount <= (pushToken.balanceOf(actor.charlie_channel_owner) / 1e18) + 200
                && _amount <= (pushToken.balanceOf(actor.tony_channel_owner) / 1e18) + 300
        );
        _passEpoch = bound(_passEpoch, 2, 22);
        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);
        stake(actor.alice_channel_owner, _amount + 100);
        stake(actor.charlie_channel_owner, _amount + 200);
        stake(actor.tony_channel_owner, _amount + 300);

        roll(epochDuration * _passEpoch);
        harvest(actor.tony_channel_owner);
        harvest(actor.bob_channel_owner);
        harvest(actor.alice_channel_owner);
        harvest(actor.charlie_channel_owner);
        uint256 bobClaimed = feePoolStaking.usersRewardsClaimed(actor.bob_channel_owner);
        uint256 aliceClaimed = feePoolStaking.usersRewardsClaimed(actor.alice_channel_owner);
        uint256 charlieclaimed = feePoolStaking.usersRewardsClaimed(actor.charlie_channel_owner);
        uint256 tonyclaimed = feePoolStaking.usersRewardsClaimed(actor.tony_channel_owner);

        assertTrue(tonyclaimed > charlieclaimed && charlieclaimed > aliceClaimed && aliceClaimed > bobClaimed);
    }

    //  4 Users Stakes(Same Amount) & Harvests after a gap of 2 epochs each - All get same rewards
    function test_SameAmountDifferentHarvest(uint256 _fee, uint256 _amount, uint256 _passEpoch) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        vm.assume(
            _amount > 0 && _amount <= pushToken.balanceOf(actor.bob_channel_owner) / 1e18
                && _amount <= (pushToken.balanceOf(actor.alice_channel_owner) / 1e18)
                && _amount <= (pushToken.balanceOf(actor.charlie_channel_owner) / 1e18)
                && _amount <= (pushToken.balanceOf(actor.tony_channel_owner) / 1e18)
        );
        _passEpoch = bound(_passEpoch, 2, 22);
        changePrank(actor.bob_channel_owner);
        pushToken.delegate(actor.bob_channel_owner);
        uint256 beforeVotes = pushToken.getCurrentVotes(actor.bob_channel_owner);

        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);
        PushVoteDelegator _voteDelegator = feePoolStaking.preserveVotingPower(actor.bob_channel_owner);
        assertEq(pushToken.balanceOf(address(_voteDelegator)), _amount * 1e18);
        stake(actor.alice_channel_owner, _amount);
        stake(actor.charlie_channel_owner, _amount);
        stake(actor.tony_channel_owner, _amount);
        roll(epochDuration * _passEpoch);
        harvest(actor.tony_channel_owner);
        roll(epochDuration * (_passEpoch + 3));

        harvest(actor.bob_channel_owner);
        roll(epochDuration * (_passEpoch + 7));

        harvest(actor.alice_channel_owner);
        roll(epochDuration * (_passEpoch + 12));

        harvest(actor.charlie_channel_owner);
        uint256 bobClaimed = feePoolStaking.usersRewardsClaimed(actor.bob_channel_owner);
        uint256 aliceClaimed = feePoolStaking.usersRewardsClaimed(actor.alice_channel_owner);
        uint256 charlieclaimed = feePoolStaking.usersRewardsClaimed(actor.charlie_channel_owner);
        uint256 tonyclaimed = feePoolStaking.usersRewardsClaimed(actor.tony_channel_owner);
        changePrank(actor.bob_channel_owner);
        pushToken.delegate(actor.bob_channel_owner);
        uint256 afterVotes = pushToken.getCurrentVotes(actor.bob_channel_owner);
        assertEq(afterVotes, bobClaimed + beforeVotes, "Unequal Votes");

        assertEq(charlieclaimed, tonyclaimed, "charlie and tony");
        assertEq(bobClaimed, aliceClaimed, "bob and alice");
    }

    //  allows staker to harvest with harvestPaginated() method
    function test_HarvestPaginated(uint256 _amount, uint256 _fee, uint256 _passEpoch) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        _amount = bound(_amount, 1, pushToken.balanceOf(actor.bob_channel_owner) / 1e18);

        _passEpoch = bound(_passEpoch, 2, 22);
        changePrank(actor.bob_channel_owner);
        pushToken.delegate(actor.bob_channel_owner);
        uint256 beforeVotes = pushToken.getCurrentVotes(actor.bob_channel_owner);

        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);
        PushVoteDelegator _voteDelegator = feePoolStaking.preserveVotingPower(actor.bob_channel_owner);

        roll(epochDuration * _passEpoch);
        harvestPaginated(actor.bob_channel_owner, _passEpoch - 1);
        daoHarvest(actor.admin, _passEpoch - 1);

        uint256 rewardsAd = feePoolStaking.usersRewardsClaimed(address(coreProxy));
        uint256 rewardsBob = feePoolStaking.usersRewardsClaimed(actor.bob_channel_owner);
        assertApproxEqAbs(_fee * 1e18, rewardsBob, rewardsAd * 1e18);

        changePrank(actor.bob_channel_owner);
        pushToken.delegate(actor.bob_channel_owner);
        uint256 afterVotes = pushToken.getCurrentVotes(actor.bob_channel_owner);
        assertEq(afterVotes, rewardsBob + beforeVotes, "Unequal Votes");
    }

    //  avoids harvesting the future epochs,
    function test_HarvestFutureEpoch(uint256 _amount, uint256 _fee, uint256 _passEpoch) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        _amount = bound(_amount, 1, pushToken.balanceOf(actor.bob_channel_owner) / 1e18);

        _passEpoch = bound(_passEpoch, 2, 22);
        changePrank(actor.bob_channel_owner);
        pushToken.delegate(actor.bob_channel_owner);
        uint256 beforeVotes = pushToken.getCurrentVotes(actor.bob_channel_owner);
        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);
        roll(epochDuration * _passEpoch);
        PushVoteDelegator _voteDelegator = feePoolStaking.preserveVotingPower(actor.bob_channel_owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.PushStaking_InvalidEpoch_LessThanExpected.selector));
        harvestPaginated(actor.bob_channel_owner, _passEpoch + 1);
        changePrank(actor.bob_channel_owner);
        pushToken.delegate(actor.bob_channel_owner);
        uint256 afterVotes = pushToken.getCurrentVotes(actor.bob_channel_owner);
        assertEq(afterVotes, beforeVotes, "Unequal Votes");
    }

    //  avoids harvesting same epochs multiple time,
    function test_SameEpochHarvest(uint256 _amount, uint256 _fee, uint256 _passEpoch) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        _amount = bound(_amount, 1, pushToken.balanceOf(actor.bob_channel_owner) / 1e18);

        _passEpoch = bound(_passEpoch, 2, 22);
        changePrank(actor.bob_channel_owner);
        pushToken.delegate(actor.bob_channel_owner);
        uint256 beforeVotes = pushToken.getCurrentVotes(actor.bob_channel_owner);

        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);
        PushVoteDelegator _voteDelegator = feePoolStaking.preserveVotingPower(actor.bob_channel_owner);

        roll(epochDuration * _passEpoch);
        harvestPaginated(actor.bob_channel_owner, _passEpoch - 1);
        (,,, uint256 _lastClaimedBlock) = feePoolStaking.userFeesInfo(actor.bob_channel_owner);
        uint256 _nextFromEpoch = feePoolStaking.lastEpochRelative(genesisEpoch, _lastClaimedBlock);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.InvalidArg_LessThanExpected.selector, _nextFromEpoch, _passEpoch - 1)
        );
        harvestPaginated(actor.bob_channel_owner, _passEpoch - 1);
        changePrank(actor.bob_channel_owner);
        pushToken.delegate(actor.bob_channel_owner);
        uint256 afterVotes = pushToken.getCurrentVotes(actor.bob_channel_owner);
        uint256 rewardsBob = feePoolStaking.usersRewardsClaimed(actor.bob_channel_owner);
        assertEq(afterVotes, rewardsBob + beforeVotes, "Unequal Votes");
    }

    //  allows harvesting for epoch ranges for a Single Staker,
    function test_RangeEpochsHarvest(uint256 _amount, uint256 _fee, uint256 _passEpoch) public {
        _fee = bound(_fee, 10, pushToken.balanceOf(actor.admin) / 3e18);
        _amount = bound(_amount, 1, pushToken.balanceOf(actor.bob_channel_owner) / 1e18);

        _passEpoch = bound(_passEpoch, 2, 22);
        changePrank(actor.bob_channel_owner);
        pushToken.delegate(actor.bob_channel_owner);
        uint256 beforeVotes = pushToken.getCurrentVotes(actor.bob_channel_owner);

        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);
        PushVoteDelegator _voteDelegator = feePoolStaking.preserveVotingPower(actor.bob_channel_owner);
        roll(epochDuration * (_passEpoch));
        addPool(_fee);
        roll(epochDuration * (_passEpoch + 2));
        addPool(_fee);

        roll(epochDuration * (_passEpoch + 4));

        harvest(actor.bob_channel_owner);
        daoHarvest(actor.admin, _passEpoch - 1);
        uint256 rewardsB = feePoolStaking.usersRewardsClaimed(actor.bob_channel_owner);
        uint256 rewardsA = feePoolStaking.usersRewardsClaimed(address(coreProxy));
        uint256 expected = _fee * 3e18 - rewardsA;
        assertApproxEqAbs(rewardsB, expected, _fee * 1e18);

      changePrank(actor.bob_channel_owner);
        pushToken.delegate(actor.bob_channel_owner);
        uint256 afterVotes = pushToken.getCurrentVotes(actor.bob_channel_owner);
    
        assertEq(afterVotes, rewardsB+ beforeVotes, "Unequal Votes");
    }

    //  allows cummulative harvesting with epoch ranges,
    function test_CumulativeRangeEpochsHarvest(uint256 _amount, uint256 _fee, uint256 _passEpoch) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 3e18);
        _amount = bound(_amount, 1, pushToken.balanceOf(actor.bob_channel_owner) / 1e18);

        _passEpoch = bound(_passEpoch, 2, 22);
        changePrank(actor.bob_channel_owner);
        pushToken.delegate(actor.bob_channel_owner);
        uint256 beforeVotes = pushToken.getCurrentVotes(actor.bob_channel_owner);
        
        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);
        PushVoteDelegator _voteDelegator = feePoolStaking.preserveVotingPower(actor.bob_channel_owner);
        uint256 Votes = pushToken.getCurrentVotes(actor.bob_channel_owner);
        assertEq(Votes, beforeVotes, "Unequal Votes");

        roll(epochDuration * _passEpoch);
        addPool(_fee);
        roll(epochDuration * (_passEpoch + 2));
        addPool(_fee);
        roll(epochDuration * (_passEpoch + 4));

        harvestPaginated(actor.bob_channel_owner, _passEpoch);
        harvestPaginated(actor.bob_channel_owner, _passEpoch + 2);
        harvestPaginated(actor.bob_channel_owner, _passEpoch + 3);

        daoHarvest(actor.admin, _passEpoch + 3);
        uint256 rewardsB = feePoolStaking.usersRewardsClaimed(actor.bob_channel_owner);
        uint256 rewardsA = feePoolStaking.usersRewardsClaimed(address(coreProxy));
        uint256 expected = _fee * 3e18 - rewardsA;
        assertApproxEqAbs(rewardsB, expected, 5 ether);
        changePrank(actor.bob_channel_owner);

        pushToken.delegate(actor.bob_channel_owner);
        uint256 afterVotes = pushToken.getCurrentVotes(actor.bob_channel_owner);
    
        assertEq(afterVotes, rewardsB + beforeVotes, "Unequal Votes");
    }

    //  yields same reward with `harvestPaginated` & `harvestAll,
    function test_PaginatedAndHarvestAll(uint256 _fee, uint256 _amount, uint256 _passEpoch) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 3e18);
        vm.assume(
            _amount <= pushToken.balanceOf(actor.bob_channel_owner) / 1e18
                && _amount <= (pushToken.balanceOf(actor.alice_channel_owner) / 1e18)
        );
        _passEpoch = bound(_passEpoch, 2, 22);

        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);
        stake(actor.alice_channel_owner, _amount);
        roll(epochDuration * _passEpoch);
        addPool(_fee);
        roll(epochDuration * (_passEpoch + 2));
        addPool(_fee);
        roll(epochDuration * (_passEpoch + 4));

        harvest(actor.alice_channel_owner);
        harvestPaginated(actor.bob_channel_owner, _passEpoch);
        harvestPaginated(actor.bob_channel_owner, _passEpoch + 2);
        harvestPaginated(actor.bob_channel_owner, _passEpoch + 3);
        daoHarvest(actor.admin, _passEpoch + 3);
        uint256 rewardsB = feePoolStaking.usersRewardsClaimed(actor.bob_channel_owner);
        uint256 rewardsA = feePoolStaking.usersRewardsClaimed(actor.bob_channel_owner);
        uint256 rewardsAd = feePoolStaking.usersRewardsClaimed(address(coreProxy));
        uint256 expected = (_fee * 3e18 - rewardsAd) / 2;
        assertApproxEqAbs(rewardsB, expected, 5 ether);
        assertApproxEqAbs(rewardsA, expected, 5 ether);
    }

    //  should not yield rewards if rewardpool is void",

    function test_VoidEpoch(uint256 _amount, uint256 _fee, uint256 _passEpoch) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 3e18);
        _amount = bound(_amount, 1, pushToken.balanceOf(actor.bob_channel_owner) / 1e18);

        _passEpoch = bound(_passEpoch, 2, 22);

        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);

        roll(epochDuration * _passEpoch);

        harvest(actor.bob_channel_owner);
        uint256 rewardsBef = feePoolStaking.usersRewardsClaimed(actor.bob_channel_owner);
        roll(epochDuration * _passEpoch + 2);
        harvest(actor.bob_channel_owner);
        uint256 rewardsAf = feePoolStaking.usersRewardsClaimed(actor.bob_channel_owner);
        assertEq(rewardsAf, rewardsBef);
    }
}
