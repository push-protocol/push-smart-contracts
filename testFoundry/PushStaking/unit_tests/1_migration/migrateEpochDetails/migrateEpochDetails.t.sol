pragma solidity ^0.8.20;

import "forge-std/console.sol";

import { BasePushFeePoolStaking } from "../../../BasePushFeePoolStaking.t.sol";

contract MigrateEpochDetails_Test is BasePushFeePoolStaking {
    // uint256 _currentEpoch = 5;
    // uint[5] public _epochRewards = [100, 200, 300, 400, 500];
    // uint[5] public _epochToTotalStakedWeight = [150000, 250000, 350000, 450000, 550000];

    uint256 _currentEpoch = 3;
    uint256[] _epochRewardss;
    uint256[] _epochToTotalStakedWeights;

    function setUp() public virtual override {
        BasePushFeePoolStaking.setUp();

        _epochRewardss.push(uint256(100));
        _epochRewardss.push(uint256(200));
        _epochRewardss.push(uint256(300));

        _epochToTotalStakedWeights.push(uint256(19_999));
        _epochToTotalStakedWeights.push(uint256(29_999));
        _epochToTotalStakedWeights.push(uint256(39_999));
    }

    modifier whenCallerIsAdmin() {
        _;
    }

    modifier whenMigrationComplete() {
        _;
    }

    modifier whenMigrationNotComplete() {
        _;
    }

    function test_Revertwhen_MigrationCallerNotAdmin() public {
        vm.expectRevert(bytes("PushFeePoolStaking::onlyPushChannelAdmin: Invalid Caller"));

        changePrank(actor.bob_channel_owner);
        feePoolStaking.migrateEpochDetails(_currentEpoch, _epochRewardss, _epochToTotalStakedWeights);
    }

    function test_Revertwhen_MigratePostMigrationCompleted() public whenCallerIsAdmin whenMigrationComplete {
        feePoolStaking.setMigrationComplete();
        vm.expectRevert(bytes("PushFeePoolStaking::isMigrated: Migration Completed"));
        feePoolStaking.migrateEpochDetails(_currentEpoch, _epochRewardss, _epochToTotalStakedWeights);
    }

    function test_Revertwhen_UnequalArrayLengthBeforeMigrationCompleted() public whenCallerIsAdmin whenMigrationComplete {
        uint256 _testEpoch = _currentEpoch - 1;
        vm.expectRevert(bytes("Invalid Length"));
        feePoolStaking.migrateEpochDetails(_testEpoch, _epochRewardss, _epochToTotalStakedWeights);
    }

    function test_MigrateBeforeMigrationCompleted() public whenCallerIsAdmin whenMigrationNotComplete {
        feePoolStaking.migrateEpochDetails(_currentEpoch, _epochRewardss, _epochToTotalStakedWeights);

        // Verifying epochRewards
        uint256 expectedEpochReward_2ndIndex = _epochRewardss[1];
        uint256 actualEpochReward_2ndIndex = feePoolStaking.epochRewards(2);
        assertEq(actualEpochReward_2ndIndex, expectedEpochReward_2ndIndex);

        // Verifying epochToTotalStakedWeight
        uint256 expectEdepochToTotalStakedWeight_3rdIndex = _epochToTotalStakedWeights[2];
        uint256 actualEpochToTotalStakedWeight_3rdIndex = feePoolStaking.epochToTotalStakedWeight(3);
        assertEq(actualEpochToTotalStakedWeight_3rdIndex, expectEdepochToTotalStakedWeight_3rdIndex);
    }
}
