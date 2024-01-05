pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;
import {BaseFuzzStaking} from "../BaseFuzzStaking.f.sol";

contract UserHarvest_test is BaseFuzzStaking {
    function setUp() public virtual override {
        BaseFuzzStaking.setUp();
    }

    // actor.bob_channel_owner Stakes at EPOCH 1 and Harvests alone- Should get all rewards
    function test_HarvestAlone(
        uint _fee,
        uint _amount,
        uint _passEpoch
    ) public {
        uint balanceBefore = pushToken.balanceOf(actor.bob_channel_owner);

        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        _amount = bound(_amount, 1, balanceBefore / 1e18);
        _passEpoch = bound(_passEpoch, 2, 22);

        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);
        roll(epochDuration * _passEpoch);
        harvest(actor.bob_channel_owner);
        daoHarvest(actor.admin, _passEpoch - 1);
        uint adminClaimed = feePoolStaking.usersRewardsClaimed(
            address(coreProxy)
        );
        uint claimed = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );

        assertApproxEqAbs(claimed, _fee * 1e18, (adminClaimed) * 1e18);
    }

    //actor.bob_channel_owner Stakes after EPOCH 1 and Harvests alone- Should get all rewards
    function test_HarvestAloneAfterOneEpoch(
        uint _fee,
        uint _amount,
        uint _passEpoch
    ) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        _amount = bound(
            _amount,
            1,
            pushToken.balanceOf(actor.bob_channel_owner) / 1e18
        );
        _passEpoch = bound(_passEpoch, 2, 22);

        roll(epochDuration * _passEpoch);
        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);
        roll(epochDuration * (_passEpoch + 1));
        harvest(actor.bob_channel_owner);
        daoHarvest(actor.admin, _passEpoch);
        uint adminClaimed = feePoolStaking.usersRewardsClaimed(
            address(coreProxy)
        );
        uint claimed = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );
        assertApproxEqAbs(claimed, _fee * 1e18, adminClaimed + 1e18);
    }

    //  actor.bob_channel_owner Stakes and Harvests alone in same Epoch- Should get ZERO rewards
    function test_StakeharvestSameEpoch(
        uint _amount,
        uint _fee,
        uint _passEpoch
    ) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        _amount = bound(
            _amount,
            1,
            pushToken.balanceOf(actor.bob_channel_owner) / 1e18
        );

        _passEpoch = bound(_passEpoch, 2, 22);
        roll(epochDuration * _passEpoch);
        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);
        harvest(actor.bob_channel_owner);

        assertEq(
            feePoolStaking.usersRewardsClaimed(actor.bob_channel_owner),
            0
        );
    }

    //   bob stakes at epoch 2 and claims at epoch 9 using harvestAll()",
    function test_StakeharvestNineEpoch(
        uint _amount,
        uint _fee,
        uint _passEpoch
    ) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        _amount = bound(
            _amount,
            1,
            pushToken.balanceOf(actor.bob_channel_owner) / 1e18
        );

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

    //actor.bob_channel_owner & actor.alice_channel_owner Stakes(Same Amount) and Harvests together- Should get equal rewards
    function test_HarvestEqual(
        uint _fee,
        uint _amount,
        uint _passEpoch
    ) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        vm.assume(
            _amount <= pushToken.balanceOf(actor.bob_channel_owner) / 1e18 &&
                _amount <= pushToken.balanceOf(actor.alice_channel_owner) / 1e18
        );
        _passEpoch = bound(_passEpoch, 2, 22);

        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);
        stake(actor.alice_channel_owner, _amount);
        roll(epochDuration * _passEpoch);
        harvest(actor.bob_channel_owner);
        harvest(actor.alice_channel_owner);
        uint bobClaimed = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );
        uint aliceClaimed = feePoolStaking.usersRewardsClaimed(
            actor.alice_channel_owner
        );
        assertEq(bobClaimed, aliceClaimed);
    }

        // actor.bob_channel_owner stakes abit later than actor.alice_channel_owner. actor.bob_channel_owner & actor.alice_channel_owner Stakes(Same Amount) and Harvests together - they get equal rewards
    function test_StakeAndClaimSameEpoch(
        uint _amount,
        uint _fee,
        uint _passEpoch,
        uint _passBlocks
    ) public {
        vm.assume(
            _amount <= pushToken.balanceOf(actor.bob_channel_owner) / 1e18 &&
                _amount <= pushToken.balanceOf(actor.alice_channel_owner) / 1e18
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
    function test_HarvestEqualFourPeople(
        uint _fee,
        uint _amount,
        uint _passEpoch
    ) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        vm.assume(
            _amount <= pushToken.balanceOf(actor.bob_channel_owner) / 1e18 &&
                _amount <= pushToken.balanceOf(actor.alice_channel_owner) / 1e18
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
        uint bobClaimed = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );
        uint aliceClaimed = feePoolStaking.usersRewardsClaimed(
            actor.alice_channel_owner
        );
        uint charlieclaimed = feePoolStaking.usersRewardsClaimed(
            actor.charlie_channel_owner
        );
        uint tonyclaimed = feePoolStaking.usersRewardsClaimed(
            actor.tony_channel_owner
        );

        assertTrue(
            charlieclaimed == tonyclaimed &&
                bobClaimed == aliceClaimed &&
                bobClaimed == charlieclaimed
        );
    }

    //  4 Users Stakes different amount and Harvests together- Last Claimer & Major Staker Gets More
    function test_DifferentAmounts(
        uint _fee,
        uint _amount,
        uint _passEpoch
    ) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        vm.assume(
            _amount <= pushToken.balanceOf(actor.bob_channel_owner) / 1e18 &&
                _amount <=
                (pushToken.balanceOf(actor.alice_channel_owner) / 1e18) + 100 &&
                _amount <=
                (pushToken.balanceOf(actor.charlie_channel_owner) / 1e18) +
                    200 &&
                _amount <=
                (pushToken.balanceOf(actor.tony_channel_owner) / 1e18) + 300
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
        uint bobClaimed = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );
        uint aliceClaimed = feePoolStaking.usersRewardsClaimed(
            actor.alice_channel_owner
        );
        uint charlieclaimed = feePoolStaking.usersRewardsClaimed(
            actor.charlie_channel_owner
        );
        uint tonyclaimed = feePoolStaking.usersRewardsClaimed(
            actor.tony_channel_owner
        );

        assertTrue(
            tonyclaimed > charlieclaimed &&
                charlieclaimed > aliceClaimed &&
                aliceClaimed > bobClaimed
        );
    }

    //  4 Users Stakes(Same Amount) & Harvests after a gap of 2 epochs each - All get same rewards
    function test_SameAmountDifferentHarvest(
        uint _fee,
        uint _amount,
        uint _passEpoch
    ) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        vm.assume(
            _amount <= pushToken.balanceOf(actor.bob_channel_owner) / 1e18 &&
                _amount <=
                (pushToken.balanceOf(actor.alice_channel_owner) / 1e18) &&
                _amount <=
                (pushToken.balanceOf(actor.charlie_channel_owner) / 1e18) &&
                _amount <=
                (pushToken.balanceOf(actor.tony_channel_owner) / 1e18)
        );
        _passEpoch = bound(_passEpoch, 2, 22);

        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);
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
        uint bobClaimed = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );
        uint aliceClaimed = feePoolStaking.usersRewardsClaimed(
            actor.alice_channel_owner
        );
        uint charlieclaimed = feePoolStaking.usersRewardsClaimed(
            actor.charlie_channel_owner
        );
        uint tonyclaimed = feePoolStaking.usersRewardsClaimed(
            actor.tony_channel_owner
        );

        assertEq(charlieclaimed, tonyclaimed, "charlie and tony");
        assertEq(bobClaimed, aliceClaimed, "bob and alice");
    }

    //  allows staker to harvest with harvestPaginated() method
    function test_HarvestPaginated(
        uint _amount,
        uint _fee,
        uint _passEpoch
    ) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        _amount = bound(
            _amount,
            1,
            pushToken.balanceOf(actor.bob_channel_owner) / 1e18
        );

        _passEpoch = bound(_passEpoch, 2, 22);

        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);
        roll(epochDuration * _passEpoch);
        harvestPaginated(actor.bob_channel_owner, _passEpoch - 1);
        daoHarvest(actor.admin, _passEpoch - 1);
        uint rewardsAd = feePoolStaking.usersRewardsClaimed(address(coreProxy));
        uint rewardsBob = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );
        assertApproxEqAbs(_fee * 1e18, rewardsBob, rewardsAd * 1e18);
    }

    //  avoids harvesting the future epochs,
    function test_HarvestFutureEpoch(
        uint _amount,
        uint _fee,
        uint _passEpoch
    ) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        _amount = bound(
            _amount,
            1,
            pushToken.balanceOf(actor.bob_channel_owner) / 1e18
        );

        _passEpoch = bound(_passEpoch, 2, 22);

        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);
        roll(epochDuration * _passEpoch);
        vm.expectRevert();
        harvestPaginated(actor.bob_channel_owner, _passEpoch + 1);
    }

    //  avoids harvesting same epochs multiple time,
    function test_SameEpochHarvest(
        uint _amount,
        uint _fee,
        uint _passEpoch
    ) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        _amount = bound(
            _amount,
            1,
            pushToken.balanceOf(actor.bob_channel_owner) / 1e18
        );

        _passEpoch = bound(_passEpoch, 2, 22);

        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);
        roll(epochDuration * _passEpoch);
        harvestPaginated(actor.bob_channel_owner, _passEpoch - 1);

        vm.expectRevert();
        harvestPaginated(actor.bob_channel_owner, _passEpoch - 1);
    }

    //  allows harvesting for epoch ranges for a Single Staker,
    function test_RangeEpochsHarvest(
        uint _amount,
        uint _fee,
        uint _passEpoch
    ) public {
        _fee = bound(_fee, 10, pushToken.balanceOf(actor.admin) / 3e18);
        _amount = bound(
            _amount,
            1,
            pushToken.balanceOf(actor.bob_channel_owner) / 1e18
        );

        _passEpoch = bound(_passEpoch, 2, 22);

        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);
        roll(epochDuration * (_passEpoch));
        addPool(_fee);
        roll(epochDuration * (_passEpoch + 2));
        addPool(_fee);

        roll(epochDuration * (_passEpoch + 4));

        harvest(actor.bob_channel_owner);
        daoHarvest(actor.admin, _passEpoch - 1);
        uint rewardsB = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );
        uint rewardsA = feePoolStaking.usersRewardsClaimed(address(coreProxy));
        uint expected = _fee * 3e18 - rewardsA;
        assertApproxEqAbs(rewardsB, expected, _fee * 1e18);
    }

    //  allows cummulative harvesting with epoch ranges,
    function test_CumulativeRangeEpochsHarvest(
        uint _amount,
        uint _fee,
        uint _passEpoch
    ) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 3e18);
        _amount = bound(
            _amount,
            1,
            pushToken.balanceOf(actor.bob_channel_owner) / 1e18
        );

        _passEpoch = bound(_passEpoch, 2, 22);

        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);
        roll(epochDuration * _passEpoch);
        addPool(_fee);
        roll(epochDuration * (_passEpoch + 2));
        addPool(_fee);
        roll(epochDuration * (_passEpoch + 4));

        harvestPaginated(actor.bob_channel_owner, _passEpoch);
        harvestPaginated(actor.bob_channel_owner, _passEpoch + 2);
        harvestPaginated(actor.bob_channel_owner, _passEpoch + 3);

        daoHarvest(actor.admin, _passEpoch + 3);
        uint rewardsB = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );
        uint rewardsA = feePoolStaking.usersRewardsClaimed(address(coreProxy));
        uint expected = _fee * 3e18 - rewardsA;
        assertApproxEqAbs(rewardsB, expected, 5 ether);
    }

    //  yields same reward with `harvestPaginated` & `harvestAll,
    function test_PaginatedAndHarvestAll(
        uint _fee,
        uint _amount,
        uint _passEpoch
    ) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 3e18);
        vm.assume(
            _amount <= pushToken.balanceOf(actor.bob_channel_owner) / 1e18 &&
                _amount <=
                (pushToken.balanceOf(actor.alice_channel_owner) / 1e18)
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
        uint rewardsB = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );
        uint rewardsA = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );
        uint rewardsAd = feePoolStaking.usersRewardsClaimed(address(coreProxy));
        uint expected = (_fee * 3e18 - rewardsAd) / 2;
        assertApproxEqAbs(rewardsB, expected, 5 ether);
        assertApproxEqAbs(rewardsA, expected, 5 ether);
    }

    //  should not yield rewards if rewardpool is void",

    function test_VoidEpoch(uint _amount, uint _fee, uint _passEpoch) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 3e18);
        _amount = bound(
            _amount,
            1,
            pushToken.balanceOf(actor.bob_channel_owner) / 1e18
        );

        _passEpoch = bound(_passEpoch, 2, 22);

        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);

        roll(epochDuration * _passEpoch);

        harvest(actor.bob_channel_owner);
        uint rewardsBef = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );
        roll(epochDuration * _passEpoch + 2);
        harvest(actor.bob_channel_owner);
        uint rewardsAf = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );
        assertEq(rewardsAf, rewardsBef);
    }
}
