pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { BasePushFeePoolStaking } from "../../../BasePushFeePoolStaking.t.sol";

contract MigrateUserMappings_Test is BasePushFeePoolStaking {

    uint256 _epoch = 2;
    uint256 startIndex = 0;
    uint256 endIndex = 3;
    address[] _user;
    uint256[] _epochToUserStakedWeight;
    uint256[] _userRewardsClaimed;
    uint256[] _lastStakedBlock;
    uint256[] _lastClaimedBlock;

    function setUp() public virtual override {
        BasePushFeePoolStaking.setUp();

        _user.push(actor.bob_channel_owner);
        _user.push(actor.dan_push_holder);
        _user.push(actor.tim_push_holder);

        _epochToUserStakedWeight.push(uint256(1000));
        _epochToUserStakedWeight.push(uint256(2000));
        _epochToUserStakedWeight.push(uint256(3000));

        _userRewardsClaimed.push(uint256(50));
        _userRewardsClaimed.push(uint256(0));
        _userRewardsClaimed.push(uint256(70));
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
        feePoolStaking.migrateUserMappings(_epoch, startIndex, endIndex, _user, _epochToUserStakedWeight, _userRewardsClaimed);
    }

    function test_Revertwhen_MigratePostMigrationCompleted() public whenCallerIsAdmin whenMigrationComplete {
        feePoolStaking.setMigrationComplete();
        vm.expectRevert(bytes("PushFeePoolStaking::isMigrated: Migration Completed"));
        feePoolStaking.migrateUserMappings(_epoch, startIndex, endIndex, _user, _epochToUserStakedWeight, _userRewardsClaimed);
    }

    function test_Revertwhen_UnequalArrayLengthBeforeMigrationCompleted() public whenCallerIsAdmin whenMigrationComplete {
        address[] memory  _testUserLength = new address[](2);
        _testUserLength[0] = address(actor.dan_push_holder);
        _testUserLength[1] = address(actor.tim_push_holder);

        vm.expectRevert(bytes("Invalid Length"));
        feePoolStaking.migrateUserMappings(_epoch, startIndex, endIndex, _testUserLength, _epochToUserStakedWeight, _userRewardsClaimed);
    }

    function testRevertwhen_EndMoreThanLength() public whenCallerIsAdmin whenMigrationNotComplete() {
        vm.expectRevert();
        uint256 _tempEndIndex = 5;
        feePoolStaking.migrateUserMappings(_epoch, startIndex, _tempEndIndex, _user, _epochToUserStakedWeight, _userRewardsClaimed);
    }

    function test_MigrateBeforeMigrationCompleted() public whenCallerIsAdmin whenMigrationNotComplete {
        feePoolStaking.migrateUserMappings(_epoch, startIndex, endIndex, _user, _epochToUserStakedWeight, _userRewardsClaimed);

        // Verifying user data
        for (uint256 i = startIndex; i < endIndex; ++i) {
            uint256 expectedEpochToUserStakedWeight = _epochToUserStakedWeight[i];

            uint256 actualEpochToUserStakedWeight = getActualEpochToUserStakedWeight(_user[i], _epoch);

            assertEq(actualEpochToUserStakedWeight, expectedEpochToUserStakedWeight);

            if (_userRewardsClaimed.length > 0) {
                uint256 expectedUserRewardsClaimed = _userRewardsClaimed[i];
                uint256 actualUserRewardsClaimed = feePoolStaking.usersRewardsClaimed(_user[i]);
                assertEq(actualUserRewardsClaimed, expectedUserRewardsClaimed);
            } else {
                uint256 expectedUserRewardsClaimed = 0;
                uint256 actualUserRewardsClaimed = feePoolStaking.usersRewardsClaimed(_user[i]);
                assertEq(actualUserRewardsClaimed, expectedUserRewardsClaimed);
            }
        }
    }

    function getActualEpochToUserStakedWeight(address user, uint256 epoch) public returns (uint256 epochToWeightValue) {
        uint256 userFeesInfoMappingSlot = 11;
        bytes32 userFeesInfoSlotHash = keccak256(abi.encode(user, userFeesInfoMappingSlot));

        // Convert bytes32 to uint256
        uint256 convertedHash = uint256(userFeesInfoSlotHash);

        // Add 4 to the converted value
        uint256 epochToUserStakedWeightMappingSlot = convertedHash + 4; // added 4 to get to mapping slot

        bytes32 epochToUserStakedWeightSlotHash = keccak256(abi.encode(epoch, epochToUserStakedWeightMappingSlot));

        bytes32 value = vm.load(address(feePoolStaking), bytes32(epochToUserStakedWeightSlotHash));
        epochToWeightValue = uint256(value);
    }
}
