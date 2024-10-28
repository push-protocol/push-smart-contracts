pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import {PushCoreV2} from "../contracts/PushCore/PushCoreV2.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import {EPNS} from "contracts/token/EPNS.sol";
import {console} from "lib/forge-std/src/console.sol";
import {Users} from "./array.sol";

contract ForkTest is Test, Users {
    PushCoreV2 core;
    EPNS pushToken;
    uint genesisEpoch;
    uint epochDuration;
    uint currentEpoch;
    uint totalStakedAmount;

    function setUp() public {
        vm.createSelectFork("https://mainnet.gateway.tenderly.co");
        core = PushCoreV2(0x66329Fdd4042928BfCAB60b179e1538D56eeeeeE);
        pushToken = EPNS(0xf418588522d5dd018b425E472991E52EBBeEEEEE);
        genesisEpoch = core.genesisEpoch();
        epochDuration = core.epochDuration();
        currentEpoch = core.lastEpochRelative(genesisEpoch, block.number);
        console.log(currentEpoch, "currentEpoch");

        for (uint i = currentEpoch; i <= 28; ++i) {
            vm.roll(genesisEpoch + epochDuration * i);

            changePrank(0x68A9832153fd7f95f1a3FA24fcCC3D63a6486E66);
            pushToken.approve(address(core), 50000 ether);
            core.addPoolFees(40000 ether);
            core.stake(100);
        }
        vm.roll(genesisEpoch + epochDuration * 28);

        currentEpoch = core.lastEpochRelative(genesisEpoch, block.number);
        totalStakedAmount = core.totalStakedAmount();
        //random value checks
        console.log(currentEpoch, "currentEpoch");
        console.log(totalStakedAmount, "totalStakedAmount");
        // for (uint i; i <= 10; ++i) {
        //     if (stakedAmount(users[i + 20]) > 0) {
        //         console.log(
        //             i + 20,
        //             "stakedAmount",
        //             stakedAmount(users[i + 20])
        //         );
        //     }
        // }
    }

    function test_HarvestAfter28Epoch() external {
        uint balanceBef = pushToken.balanceOf(users[21]);

        vm.startPrank(users[21]);

        pushToken.setHolderDelegation(address(core), true);
        core.harvestAll();
        assertEq(
            balanceBef + core.usersRewardsClaimed(users[21]),
            pushToken.balanceOf(users[21])
        );
    }

    function test_UnStake() external {
        uint balanceBef = pushToken.balanceOf(users[21]);
        uint stakedAmountBef = stakedAmount(users[21]);

        vm.startPrank(users[21]);
        pushToken.setHolderDelegation(address(core), true);
        core.unstake();
        assertEq(
            balanceBef + core.usersRewardsClaimed(users[21]) + stakedAmountBef,
            pushToken.balanceOf(users[21])
        );
    }

    //Helper functions
    function stakedAmount(address _user) internal returns (uint stakedAmount) {
        (stakedAmount, , , ) = core.userFeesInfo(_user);
    }

    function lastStakedBlock(
        address _user
    ) internal returns (uint lastStakedBlock) {
        (, , lastStakedBlock, ) = core.userFeesInfo(_user);
    }

    function lastClaimedBlock(
        address _user
    ) internal returns (uint lastClaimedBlock) {
        (, , , lastClaimedBlock) = core.userFeesInfo(_user);
    }

    //TODO : No way to detect the claimable rewards, as state only updates after calling harvest
    function claimableRewards(address _user) internal returns (uint) {
        uint rewards;
        uint256 nextFromEpoch = core.lastEpochRelative(
            genesisEpoch,
            lastClaimedBlock(_user)
        );
        for (uint256 i = nextFromEpoch; i <= currentEpoch; i++) {
            console.log("rewards for", i);
            uint256 claimableReward = core.calculateEpochRewards(_user, i);
            rewards += claimableReward;
            console.log(claimableReward);
        }
        return rewards;
    }
}
