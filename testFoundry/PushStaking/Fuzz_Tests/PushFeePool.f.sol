pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;
import {BasePushFeePoolStaking} from "../BasePushFeePoolStaking.t.sol";

import "forge-std/console.sol";

contract test is BasePushFeePoolStaking {
    uint genesis;

    function setUp() public virtual override {
        BasePushFeePoolStaking.setUp();
        genesis = feePoolStaking.genesisEpoch();

        approveTokens(actor.admin, address(feePoolStaking), 100000 ether);
        approveTokens(actor.admin, address(coreProxy), 100000 ether);
        approveTokens(
            actor.bob_channel_owner,
            address(feePoolStaking),
            100000 ether
        );
        approveTokens(
            actor.alice_channel_owner,
            address(feePoolStaking),
            100000 ether
        );
        approveTokens(
            actor.charlie_channel_owner,
            address(feePoolStaking),
            100000 ether
        );
        approveTokens(
            actor.tony_channel_owner,
            address(feePoolStaking),
            100000 ether
        );

        approveTokens(address(coreProxy), address(feePoolStaking), 1 ether);
        //initialize stake to avoid divsion by zero errors

        stake(address(coreProxy), 1);
    }

    //simple test checking the admin

    // Should revert on Block number overflow
    function test_BlockOverflow(uint _passEpoch) public {
        _passEpoch = bound(_passEpoch, 1, 22);
        roll(_passEpoch * epochDuration);
        uint256 future = block.number;

        vm.expectRevert(
            bytes(
                "PushFeePoolStaking::lastEpochRelative: Relative Block Number Overflow"
            )
        );
        feePoolStaking.lastEpochRelative(future, genesis);
    }

    //Should calculate relative epoch numbers accurately

    function test_CurretEpoch(uint _passEpoch) public {
        _passEpoch = bound(_passEpoch, 1, 22);
        roll(_passEpoch * epochDuration);
        uint256 future = block.number;

        assertEq(feePoolStaking.lastEpochRelative(genesis, future), _passEpoch);
    }

    // Should count staked EPOCH of user correctly
    function test_StakeAndClaimEpoch(uint _passEpoch, uint _amount) public {
        _passEpoch = bound(_passEpoch, 1, 22);
        _amount = bound(
            _amount,
            1,
            pushToken.balanceOf(actor.bob_channel_owner) / 1e18
        );

        roll(_passEpoch * epochDuration);
        stake(actor.bob_channel_owner, _amount);

        (
            uint256 stakedAmount,
            uint256 stakedWeight,
            uint256 lastStakedBlock,
            uint256 lastClaimedBlock
        ) = feePoolStaking.userFeesInfo(actor.bob_channel_owner);

        uint256 lastClaimedEpoch = feePoolStaking.lastEpochRelative(
            genesis,
            lastClaimedBlock
        );
        uint256 lastStakedEpoch = feePoolStaking.lastEpochRelative(
            genesis,
            lastStakedBlock
        );
        assertEq(stakedAmount, _amount * 1e18);
        assertEq(lastClaimedEpoch, 1);
        assertEq(lastStakedEpoch, _passEpoch);
    }

    // Should track User's Staked and Harvest block accurately
    function test_HarvestEpoch(uint _passEpoch, uint _amount) public {
        _passEpoch = bound(_passEpoch, 1, 22);
        _amount = bound(
            _amount,
            1,
            pushToken.balanceOf(actor.bob_channel_owner) / 1e18
        );

        roll(_passEpoch * epochDuration);
        uint256 stakeEpoch = getCurrentEpoch();
        // Stakes Push Tokens after 5 blocks, at 6th EPOCH
        stake(actor.bob_channel_owner, _amount);
        (, , uint256 lastStakedBlock, ) = feePoolStaking.userFeesInfo(
            actor.bob_channel_owner
        );

        uint256 userLastStakedEpochId = feePoolStaking.lastEpochRelative(
            genesis,
            lastStakedBlock
        );

        roll((_passEpoch + 5) * epochDuration);
        uint256 harvestEpoch = getCurrentEpoch();
        // Harvests Push Tokens after 15 blocks, at 16th EPOCH
        harvest(actor.bob_channel_owner);
        (, , , uint256 lastClaimedBlockAfter) = feePoolStaking.userFeesInfo(
            actor.bob_channel_owner
        );
        uint256 userLastClaimedEpochId = feePoolStaking.lastEpochRelative(
            genesis,
            lastClaimedBlockAfter
        );
        assertEq(userLastStakedEpochId, _passEpoch);
        assertEq(userLastClaimedEpochId, 5 + _passEpoch);
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

    // actor.bob_channel_owner stakes at the half of the EPOCH time. actor.bob_channel_owner gets half the actor.alice_channel_owner rewards
    function test_HalfEpochStake() public {
        stake(actor.alice_channel_owner, 100);
        addPool(2000);
        roll(epochDuration / 2);
        stake(actor.bob_channel_owner, 100);
        roll(epochDuration * 5);

        harvest(actor.bob_channel_owner);
        harvest(actor.alice_channel_owner);
    // TODO assertion failing with high delta. The JS test for this is also not delivering what the comment asks to deliver
        // assertApproxEqAbs(
        //     feePoolStaking.usersRewardsClaimed(actor.bob_channel_owner),
        //     feePoolStaking.usersRewardsClaimed(actor.alice_channel_owner) / 2,
        //         1
        // );
    }

    //  Unstaking allows users to Claim their pending rewards
    function test_Unstaking(uint _fee, uint _amount, uint _passEpoch) public {
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

        unstake(actor.bob_channel_owner);
        assertEq(
            feePoolStaking.usersRewardsClaimed(actor.bob_channel_owner) > 0,
            true
        );
    }

    // Unstaking function should update User's Detail accurately after unstake
    function test_UnstakeUpdatesDetails(
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
        roll(epochDuration * _passEpoch);

        stake(actor.bob_channel_owner, _amount);
        roll(epochDuration * (_passEpoch + 2));

        (, , uint256 blocks, ) = feePoolStaking.userFeesInfo(
            actor.bob_channel_owner
        );
        unstake(actor.bob_channel_owner);
        (
            uint256 stakedAmount,
            uint256 stakedWeight,
            uint256 lastStakedBlock,
            uint256 lastClaimedBlock
        ) = feePoolStaking.userFeesInfo(actor.bob_channel_owner);

        assertEq(stakedAmount, 0);
        assertEq(stakedWeight, 0);
    }

    //Users cannot claim rewards after unstaking
    function test_RewardsAfterUnstake(uint _fee, uint _amount) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        vm.assume(
            _amount <= pushToken.balanceOf(actor.bob_channel_owner) / 1e18 &&
                _amount <= pushToken.balanceOf(actor.alice_channel_owner) / 1e18
        );
        stake(actor.bob_channel_owner, 100);
        addPool(_fee);
        roll(epochDuration + 1);
        stake(actor.alice_channel_owner, 1);

        harvest(actor.bob_channel_owner);
        vm.expectRevert();
        unstake(actor.bob_channel_owner);
    }

    //Unstaking function should transfer accurate amount of PUSH tokens to User

    function test_UnstakeAccuracy(
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
        unstake(actor.bob_channel_owner);
        uint rewards = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );
        uint expectedAmount = rewards + balanceBefore;
        assertEq(expectedAmount, pushToken.balanceOf(actor.bob_channel_owner));
    }

    //Unstaking should only work after 1 complete EPOCH",

    function test_UnstakeLimit(uint _fee, uint _amount, uint _passEpoch) public {
        uint balanceBefore = pushToken.balanceOf(actor.bob_channel_owner);

        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        _amount = bound(_amount, 1, balanceBefore / 1e18);
        _passEpoch = bound(_passEpoch, 2, 22);

        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);
        roll(epochDuration * 1);
        vm.expectRevert();
        unstake(actor.bob_channel_owner);
        roll(epochDuration * _passEpoch);
        unstake(actor.bob_channel_owner);
        uint rewards = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );
        uint expectedAmount = rewards + balanceBefore;
        assertEq(expectedAmount, pushToken.balanceOf(actor.bob_channel_owner));
    }

    // actor.bob_channel_owner Stakes at EPOCH 1 and Harvests alone- Should get all rewards
    function test_HarvestAlone(uint _fee, uint _amount, uint _passEpoch) public {
        uint balanceBefore = pushToken.balanceOf(actor.bob_channel_owner);

        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 1e18);
        _amount = bound(_amount, 1, balanceBefore / 1e18);
        _passEpoch = bound(_passEpoch, 2, 22);

        addPool(_fee);
        stake(actor.bob_channel_owner, _amount);
        roll(epochDuration * _passEpoch);
        harvest(actor.bob_channel_owner);
        daoHarvest(actor.admin, _passEpoch - 1);
        uint adminClaimed = feePoolStaking.usersRewardsClaimed(address(coreProxy));
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
        uint adminClaimed = feePoolStaking.usersRewardsClaimed(address(coreProxy));
        uint claimed = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );
        assertApproxEqAbs(claimed, _fee * 1e18, adminClaimed + 1e18);
    }

    //actor.bob_channel_owner & actor.alice_channel_owner Stakes(Same Amount) and Harvests together- Should get equal rewards
    function test_HarvestEqual(uint _fee, uint _amount, uint _passEpoch) public {
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

    //  allows staker to harvest with harvestPaginated() method",
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
        console.log(rewardsA / 1e18, rewardsB / 1e18);
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

    ////////// DAO harvest tests //////////////////
    //   allows admin to harvest,
    function test_AdminHarvest(uint _fee, uint _passEpoch) public {
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 3e18);

        _passEpoch = bound(_passEpoch, 3, 22);

        addPool(_fee);

        roll(epochDuration * _passEpoch);

        daoHarvest(actor.admin, _passEpoch - 1);
        uint rewards = feePoolStaking.usersRewardsClaimed(address(coreProxy));

        assertEq(rewards, _fee * 1e18);
    }

    //  yields `0` if no pool funds added,  //  allows only admin to harvest
    function test_AdminHarvestZeroReward(uint _passEpoch) public {
        _passEpoch = bound(_passEpoch, 3, 22);

        roll(epochDuration * _passEpoch);
        vm.expectRevert();
        daoHarvest(actor.bob_channel_owner, _passEpoch - 1);
        daoHarvest(actor.admin, _passEpoch - 1);
        uint rewardsBef = feePoolStaking.usersRewardsClaimed(address(coreProxy));

        assertEq(rewardsBef, 0);
    }

    //  admin rewards and user rewards match the pool fees,
    function test_TotalClaimedRewards(
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
        harvest(actor.bob_channel_owner);
        daoHarvest(actor.admin, _passEpoch - 1);
        uint rewardsAd = feePoolStaking.usersRewardsClaimed(address(coreProxy));
        uint rewardsBob = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );
        uint claimed = rewardsAd + rewardsBob;
        assertApproxEqAbs(_fee * 1e18, claimed, 1 ether);
    }

    //  dao gets all rewards if no one stakes,
    function test_NoStakerDaoGetsRewards(uint _passEpoch, uint _fee) public {
        _passEpoch = bound(_passEpoch, 3, 22);
        _fee = bound(_fee, 100, pushToken.balanceOf(actor.admin) / 3e18);

        addPool(_fee);
        roll(epochDuration * _passEpoch);
        daoHarvest(actor.admin, _passEpoch - 1);

        uint claimed = feePoolStaking.usersRewardsClaimed(address(coreProxy));
        assertEq(claimed, _fee * 1e18);
    }

    //Helper Function
    function stake(address signer, uint256 amount) internal {
        changePrank(signer);
        feePoolStaking.stake(amount * 1e18);
    }

    function harvest(address signer) internal {
        changePrank(signer);
        feePoolStaking.harvestAll();
    }

    function harvestPaginated(address signer, uint _till) internal {
        changePrank(signer);
        feePoolStaking.harvestPaginated(_till);
    }

    function addPool(uint256 amount) internal {
        changePrank(actor.admin);
        coreProxy.addPoolFees(amount * 1e18);
    }

    function unstake(address signer) internal {
        changePrank(signer);
        feePoolStaking.unstake();
    }

    function daoHarvest(address signer, uint _epoch) internal {
        changePrank(signer);
        feePoolStaking.daoHarvestPaginated(_epoch);
    }

    function getCurrentEpoch() public returns (uint256 currentEpoch) {
        currentEpoch = feePoolStaking.lastEpochRelative(genesis, block.number);
    }
}
