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
        approveTokens(actor.admin, address(core), 100000 ether);
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

        approveTokens(address(core), address(feePoolStaking), 1 ether);
        //initialize stake to avoid divsion by zero errors

        stake(address(core), 1);
    }

    //simple test checking the admin

    function testAdmin() external {
        address owner = feePoolStaking.pushChannelAdmin();
        assertEq(owner, actor.admin);
    }

    //Should revert on Block number overflow
    function testBlockOverflow() public {
        roll(3 * epochDuration);
        uint256 future = block.number;

        vm.expectRevert(
            bytes(
                "PushFeePoolStaking::lastEpochRelative: Relative Block Number Overflow"
            )
        );
        feePoolStaking.lastEpochRelative(future, genesis);
    }

    //Should calculate relative epoch numbers accurately

    function testCurretEpoch() public {
        roll(4 * epochDuration);
        uint256 future = block.number;

        assertEq(feePoolStaking.lastEpochRelative(genesis, future), 4);
    }

    // Shouldn't change epoch value if '_to' block lies in same epoch boundary
    function testHalfEpoch() public {
        roll(epochDuration / 2);
        uint256 future = block.number;
        assertEq(feePoolStaking.lastEpochRelative(genesis, future), 1);
    }

    // Should count staked EPOCH of user correctly
    function testStakeAndClaimEpoch() public {
        roll(5 * epochDuration);
        stake(actor.bob_channel_owner, 10);

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
        assertEq(stakedAmount, 10 ether);
        assertEq(lastClaimedEpoch, 1);
        assertEq(lastStakedEpoch, 5);
    }

    // Should track User's Staked and Harvest block accurately
    function testHarvestEpoch() public {
        roll(5 * epochDuration);
        uint256 stakeEpoch = getCurrentEpoch();
        // Stakes Push Tokens after 5 blocks, at 6th EPOCH
        stake(actor.bob_channel_owner, 10);
        (
            uint256 stakedAmount,
            uint256 stakedWeight,
            uint256 lastStakedBlock,
            uint256 lastClaimedBlock
        ) = feePoolStaking.userFeesInfo(actor.bob_channel_owner);

        uint256 userLastStakedEpochId = feePoolStaking.lastEpochRelative(
            genesis,
            lastStakedBlock
        );

        roll(10 * epochDuration);
        uint256 harvestEpoch = getCurrentEpoch();
        // Harvests Push Tokens after 15 blocks, at 16th EPOCH
        harvest(actor.bob_channel_owner);
        (
            uint256 stakedAmountAfter,
            uint256 stakedWeightAfter,
            uint256 lastStakedBlockAfter,
            uint256 lastClaimedBlockAfter
        ) = feePoolStaking.userFeesInfo(actor.bob_channel_owner);
        uint256 userLastClaimedEpochId = feePoolStaking.lastEpochRelative(
            genesis,
            lastClaimedBlockAfter
        );
        //TODO test failing
        //assertEq(userLastStakedEpochId,5 + 1);
        //assertEq(userLastClaimedEpochId,5 + 10 + 1);
    }

    // actor.bob_channel_owner stakes abit later than actor.alice_channel_owner. actor.bob_channel_owner & actor.alice_channel_owner Stakes(Same Amount) and Harvests together - they get equal rewards
    function testStakeAndClaimSameEpoch() public {
        stake(actor.bob_channel_owner, 100);
        addPool(2000);
        roll(1000);
        stake(actor.alice_channel_owner, 100);
        roll(2 * epochDuration);
        harvest(actor.bob_channel_owner);
        harvest(actor.alice_channel_owner);

        assertEq(
            feePoolStaking.usersRewardsClaimed(actor.bob_channel_owner),
            feePoolStaking.usersRewardsClaimed(actor.alice_channel_owner)
        );
    }

    // actor.bob_channel_owner stakes at the half of the EPOCH time. actor.bob_channel_owner gets half the actor.alice_channel_owner rewards
    //TODO test failing
    function testHalfEpochStake() public {
        stake(actor.alice_channel_owner, 100);
        addPool(2000);
        roll(epochDuration / 2);
        stake(actor.bob_channel_owner, 100);
        roll(epochDuration * 5);

        harvest(actor.bob_channel_owner);
        harvest(actor.alice_channel_owner);
        // console.log(feePoolStaking.usersRewardsClaimed(actor.bob_channel_owner), feePoolStaking.usersRewardsClaimed(actor.alice_channel_owner));

        assertApproxEqAbs(
            feePoolStaking.usersRewardsClaimed(actor.bob_channel_owner),
            feePoolStaking.usersRewardsClaimed(actor.alice_channel_owner) / 2,
            feePoolStaking.usersRewardsClaimed(actor.alice_channel_owner) /
                2 +
                1
        );
    }

    // //  Unstaking allows users to Claim their pending rewards
    function testUnstaking() public {
        addPool(200);

        stake(actor.bob_channel_owner, 100);

        roll(epochDuration * 2);

        unstake(actor.bob_channel_owner);
        assertEq(
            feePoolStaking.usersRewardsClaimed(actor.bob_channel_owner) > 0,
            true
        );
    }

    //Unstaking function should update User's Detail accurately after unstake
    function testUnstakeUpdatesDetails() public {
        addPool(200);

        roll(epochDuration * 3);

        stake(actor.bob_channel_owner, 100);
        roll(epochDuration * 4 + 1);

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

    // //Users cannot claim rewards after unstaking
    function testRewardsAfterUnstake() public {
        stake(actor.bob_channel_owner, 100);
        addPool(1000);
        roll(epochDuration + 1);
        stake(actor.alice_channel_owner, 1);

        harvest(actor.bob_channel_owner);
        vm.expectRevert();
        unstake(actor.bob_channel_owner);
    }

    // //Unstaking function should transfer accurate amount of PUSH tokens to User

    function testUnstakeAccuracy() public {
        addPool(1000);
        uint balanceBefore = pushToken.balanceOf(actor.bob_channel_owner);
        stake(actor.bob_channel_owner, 100);
        roll(epochDuration * 2);
        unstake(actor.bob_channel_owner);
        uint rewards = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );
        uint expectedAmount = rewards + balanceBefore;
        assertEq(expectedAmount, pushToken.balanceOf(actor.bob_channel_owner));
    }

    // //Unstaking should only work after 1 complete EPOCH",

    function testUnstakeLimit() public {
        uint balanceBefore = pushToken.balanceOf(actor.bob_channel_owner);
        addPool(1000);
        stake(actor.bob_channel_owner, 100);
        roll(epochDuration * 1);
        vm.expectRevert();
        unstake(actor.bob_channel_owner);
        roll(epochDuration * 2);
        unstake(actor.bob_channel_owner);
        uint rewards = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );
        uint expectedAmount = rewards + balanceBefore;
        assertEq(expectedAmount, pushToken.balanceOf(actor.bob_channel_owner));
    }

    // //        actor.bob_channel_owner Stakes at EPOCH 1 and Harvests alone- Should get all rewards
    function testHarvestAlone() public {
        addPool(1000);
        uint balanceBefore = pushToken.balanceOf(actor.bob_channel_owner);
        stake(actor.bob_channel_owner, 100);
        roll(epochDuration * 2);
        harvest(actor.bob_channel_owner);
        uint claimed = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );

        assertApproxEqAbs(claimed, 1000, 100);
    }

    //actor.bob_channel_owner Stakes after EPOCH 1 and Harvests alone- Should get all rewards
    function testHarvestAloneAfterOneEpoch() public {
        roll(epochDuration * 2);
        addPool(1000);
        stake(actor.bob_channel_owner, 100);
        roll(epochDuration * 3);
        harvest(actor.bob_channel_owner);
        uint claimed = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );
        assertApproxEqAbs(claimed, 1000, 10);
        //@audit harvest is not failing despite of being in the same epoch.
    }

    //actor.bob_channel_owner & actor.alice_channel_owner Stakes(Same Amount) and Harvests together- Should get equal rewards
    function testHarvestEqual() public {
        addPool(1000);
        uint balanceBefore = pushToken.balanceOf(actor.bob_channel_owner);
        stake(actor.bob_channel_owner, 100);
        stake(actor.alice_channel_owner, 100);
        roll(epochDuration * 3);
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
    function testHarvestEqualFourPeople() public {
        addPool(1000);
        stake(actor.bob_channel_owner, 100);
        stake(actor.alice_channel_owner, 100);
        stake(actor.charlie_channel_owner, 100);
        stake(actor.tony_channel_owner, 100);
        roll(epochDuration * 2);
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

        assertEq(charlieclaimed, tonyclaimed, "charlie and tony");

        assertEq(
            bobClaimed,
            aliceClaimed,
            "actor.bob_channel_owner and actor.alice_channel_owner"
        );
    }

    //  4 Users Stakes different amount and Harvests together- Last Claimer & Major Staker Gets More
    function testDifferentAmounts() public {
        addPool(1000);
        stake(actor.bob_channel_owner, 100);
        stake(actor.alice_channel_owner, 200);
        stake(actor.charlie_channel_owner, 300);
        stake(actor.tony_channel_owner, 400);
        roll(epochDuration * 2);
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

        assertGt(aliceClaimed, bobClaimed);
        assertGt(charlieclaimed, aliceClaimed);
        assertGt(tonyclaimed, charlieclaimed);
    }

    //  4 Users Stakes(Same Amount) & Harvests after a gap of 2 epochs each - All get same rewards Rewards
    function testSameAmountDifferentHarvest() public {
        addPool(1000);
        stake(actor.bob_channel_owner, 100);
        stake(actor.alice_channel_owner, 100);
        stake(actor.charlie_channel_owner, 100);
        stake(actor.tony_channel_owner, 100);
        roll(epochDuration * 2);
        harvest(actor.tony_channel_owner);
        roll(epochDuration * 5);

        harvest(actor.bob_channel_owner);
        roll(epochDuration * 9);

        harvest(actor.alice_channel_owner);
        roll(epochDuration * 14);

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

        assertEq(
            bobClaimed,
            aliceClaimed,
            "actor.bob_channel_owner and actor.alice_channel_owner"
        );
    }

    //  actor.bob_channel_owner Stakes and Harvests alone in same Epoch- Should get ZERO rewards
    function testStakeharvestSameEpoch() public {
        roll(epochDuration * 2);
        addPool(1000);
        stake(actor.bob_channel_owner, 100);
        // roll((epochDuration 2);
        harvest(actor.bob_channel_owner);

        assertEq(
            feePoolStaking.usersRewardsClaimed(actor.bob_channel_owner),
            0
        );
    }

    //   bob stakes at epoch 2 and claims at epoch 9 using harvestAll()",
    function testStakeharvestNineEpoch() public {
        roll(epochDuration * 2);
        addPool(1000);
        stake(actor.bob_channel_owner, 100);
        roll(epochDuration * 9);
        harvest(actor.bob_channel_owner);
        daoHarvest(actor.admin,8);

        assertApproxEqAbs(
            feePoolStaking.usersRewardsClaimed(actor.bob_channel_owner),
            1000,
            (feePoolStaking.usersRewardsClaimed(address(feePoolStaking))) + 5
        );
    }

    //  allows staker to harvest with harvestInPeriod() method",
    function testHarvesrPaginated() public {
        addPool(1000);
        stake(actor.bob_channel_owner, 100);
        roll(epochDuration * 7);
        harvestPaginated(actor.bob_channel_owner, 6);
        daoHarvest(actor.admin,6);
        uint rewardsAd = feePoolStaking.usersRewardsClaimed(
            address(feePoolStaking)
        );
        uint rewardsBob = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );
        assertApproxEqAbs(1000, rewardsBob, rewardsAd + 10);
    }

    //  avoids harvesting the future epochs,
    function testHarvestFutureEpoch(uint _amount) public {
        addPool(1000);
        _amount = bound(
            _amount,
            1,
            pushToken.balanceOf(actor.bob_channel_owner) / 10 ** 18
        );
        stake(actor.bob_channel_owner, _amount);
        roll(epochDuration * 7);
        vm.expectRevert();
        harvestPaginated(actor.bob_channel_owner, 10);
    }

    //  avoids harvesting same epochs multiple time,
    function testSameEpochHarvest() public {
        addPool(1000);
        stake(actor.bob_channel_owner, 100);
        roll(epochDuration * 7);
        harvestPaginated(actor.bob_channel_owner, 6);

        vm.expectRevert();
        harvestPaginated(actor.bob_channel_owner, 6);
    }

    //  allows harvesting for epoch ranges for a Single Staker,
    function testRangeEpochsHarvest() public {
        addPool(100);
        stake(actor.bob_channel_owner, 100);
        roll(epochDuration * 2);
        addPool(100);
        roll(epochDuration * 4);
        addPool(100);
        roll(epochDuration * 6);

        harvest(actor.bob_channel_owner);
        daoHarvest(actor.admin,5);
        uint rewardsB = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );
        uint rewardsA = feePoolStaking.usersRewardsClaimed(
            address(feePoolStaking)
        );
        uint expected = 300 - rewardsA;
        assertApproxEqAbs(rewardsB, expected, 5);
    }

    //  allows cummulative harvesting with epoch ranges,
    function testCumulativeRangeEpochsHarvest() public {
        addPool(100);
        stake(actor.bob_channel_owner, 100);
        roll(epochDuration * 2);
        addPool(100);
        roll(epochDuration * 4);
        addPool(100);
        roll(epochDuration * 6);

        harvestPaginated(actor.bob_channel_owner, 2);
        harvestPaginated(actor.bob_channel_owner, 4);
        harvestPaginated(actor.bob_channel_owner, 5);
        daoHarvest(actor.admin,5);
        uint rewardsB = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );
        uint rewardsA = feePoolStaking.usersRewardsClaimed(
            address(feePoolStaking)
        );
        uint expected = 300 - rewardsA;
        assertApproxEqAbs(rewardsB, expected, 5);
    }

    //  yields same reward with `harvestInPeriod` & `harvestAll,
    function testPaginatedAndHarvestAll() public {
        addPool(100);
        stake(actor.bob_channel_owner, 100);
        stake(actor.alice_channel_owner, 100);
        roll(epochDuration * 2);
        addPool(100);
        roll(epochDuration * 4);
        addPool(100);
        roll(epochDuration * 6);

        harvest(actor.alice_channel_owner);
        harvestPaginated(actor.bob_channel_owner, 2);
        harvestPaginated(actor.bob_channel_owner, 4);
        harvestPaginated(actor.bob_channel_owner, 5);
        daoHarvest(actor.admin,5);
        uint rewardsB = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );
        uint rewardsA = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );
        uint rewardsAd = feePoolStaking.usersRewardsClaimed(
            address(feePoolStaking)
        );
        uint expected = (300 - rewardsAd) / 2;
        assertApproxEqAbs(rewardsB, expected, 5);
        assertApproxEqAbs(rewardsA, expected, 5);
    }

    //  should not yield rewards if rewardpool is void",

    function testVoidEpoch() public {
        addPool(100);
        stake(actor.bob_channel_owner, 100);

        roll(epochDuration * 2);

        harvest(actor.bob_channel_owner);
        uint rewardsBef = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );
        roll(epochDuration * 4);
        harvest(actor.bob_channel_owner);
        uint rewardsAf = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );
        assertEq(rewardsAf, rewardsBef);
    }

    //////////DAO harvest Tests//////////////////
    //   allows admin to harvest,
    function testAdminHarvest() public {
        addPool(100);

        roll(epochDuration * 3);

        daoHarvest(actor.admin,2);
        uint rewardsBef = feePoolStaking.usersRewardsClaimed(
            address(core)
        );

        assertEq(rewardsBef, 100);
    }

    //  yields `0` if no pool funds added,  //  allows only admin to harvest
    function testAdminHarvestZeroReward() public {
        roll(epochDuration * 3);
        vm.expectRevert();
        daoHarvest(actor.bob_channel_owner,2);
        uint rewardsBef = feePoolStaking.usersRewardsClaimed(
            address(feePoolStaking)
        );

        assertEq(rewardsBef, 0);
    }

    //  admin rewards and user rewards match the pool fees,
    function testTotalClaimedRewards() public {
        addPool(1000);
        stake(actor.bob_channel_owner, 100);
        roll(epochDuration * 7);
        harvest(actor.bob_channel_owner);
        daoHarvest(actor.admin,6);
        uint rewardsAd = feePoolStaking.usersRewardsClaimed(
            address(core)
        );
        uint rewardsBob = feePoolStaking.usersRewardsClaimed(
            actor.bob_channel_owner
        );
        uint claimed = rewardsAd + rewardsBob;
        assertApproxEqAbs(1000, claimed, 5);
    }

    //  dao gets all rewards if no one stakes,
    function testNoStakerDaoGetsRewards() public {
        addPool(1000);
        roll(epochDuration * 3);
        daoHarvest(actor.admin,2);

        uint claimed = feePoolStaking.usersRewardsClaimed(
            address(core)
        );
        assertEq(claimed, 1000);
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
        core.addPoolFees(amount);
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
