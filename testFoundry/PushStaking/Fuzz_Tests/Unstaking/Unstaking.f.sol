pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;
import {BaseFuzzStaking} from "../BaseFuzzStaking.f.sol";

contract Unstaking_test is BaseFuzzStaking {
    function setUp() public virtual override {
        BaseFuzzStaking.setUp();
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

    function test_UnstakeLimit(
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
}
