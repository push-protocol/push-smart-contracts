pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;
import {BaseFuzzStaking} from "../BaseFuzzStaking.f.sol";

contract StateVariables_test is BaseFuzzStaking {

    function setUp() public virtual override {
        BaseFuzzStaking.setUp();

    }

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

    function test_CurrentEpoch(uint _passEpoch) public {
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
}
