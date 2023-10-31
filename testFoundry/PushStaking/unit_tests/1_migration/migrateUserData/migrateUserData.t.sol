pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { BasePushFeePoolStaking } from "../../../BasePushFeePoolStaking.t.sol";

contract MigrateUserData_Test is BasePushFeePoolStaking {

    uint256 start = 0;
    uint256 end = 3;
    address[] _user;
    uint256[] _stakedAmount;
    uint256[] _stakedWeight;
    uint256[] _lastStakedBlock;
    uint256[] _lastClaimedBlock;

    function setUp() public virtual override {
        BasePushFeePoolStaking.setUp();

        _user.push(actor.bob_channel_owner);
        _user.push(actor.dan_push_holder);
        _user.push(actor.tim_push_holder);

        _stakedAmount.push(uint256(1000));
        _stakedAmount.push(uint256(2000));
        _stakedAmount.push(uint256(3000));

        _stakedWeight.push(uint256(50));
        _stakedWeight.push(uint256(80));
        _stakedWeight.push(uint256(70));

        _lastStakedBlock.push(uint256(4999));
        _lastStakedBlock.push(uint256(4997));
        _lastStakedBlock.push(uint256(4003));

        _lastClaimedBlock.push(uint256(5003));
        _lastClaimedBlock.push(uint256(4999));
        _lastClaimedBlock.push(uint256(5005));
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
        feePoolStaking.migrateUserData(start, end, _user, _stakedAmount, _stakedWeight, _lastStakedBlock, _lastClaimedBlock);
    }

    function test_Revertwhen_MigratePostMigrationCompleted() public whenCallerIsAdmin whenMigrationComplete {
        feePoolStaking.setMigrationComplete();
        vm.expectRevert(bytes("PushFeePoolStaking::isMigrated: Migration Completed"));
        feePoolStaking.migrateUserData(start, end, _user, _stakedAmount, _stakedWeight, _lastStakedBlock, _lastClaimedBlock);
    }

    function test_Revertwhen_UnequalArrayLengthBeforeMigrationCompleted() public whenCallerIsAdmin whenMigrationComplete {
        address[] memory  _testUserLength = new address[](2);
        _testUserLength[0] = address(actor.dan_push_holder);
        _testUserLength[1] = address(actor.tim_push_holder);

        vm.expectRevert(bytes("Invalid Length"));
        feePoolStaking.migrateUserData(start, end, _testUserLength, _stakedAmount, _stakedWeight, _lastStakedBlock, _lastClaimedBlock);
    }

    function testRevertwhen_EndMoreThanLength() public whenCallerIsAdmin whenMigrationNotComplete() {
        vm.expectRevert();
        feePoolStaking.migrateUserData(start, 5, _user, _stakedAmount, _stakedWeight, _lastStakedBlock, _lastClaimedBlock);
    }

    function test_MigrateBeforeMigrationCompleted() public whenCallerIsAdmin whenMigrationNotComplete {
        feePoolStaking.migrateUserData(start, end, _user, _stakedAmount, _stakedWeight, _lastStakedBlock, _lastClaimedBlock);

        // Verifying userData
        for (uint256 i=start; i<end; ++i) {
            address _userAddress = _user[i];
            uint256 expectedUserStakedAmount = _stakedAmount[i];
            uint256 expectedUserStakedWeight = _stakedWeight[i];
            uint256 expectedUserLastStakedBlock = _lastStakedBlock[i];
            uint256 expectedUserLastClaimedBlock = _lastClaimedBlock[i];

            (uint256 actualUserStakedAmount, 
            uint256 actualUserStakedWeight, 
            uint256 actualUserLastStakedBlock,
            uint256 actualUserLastClaimedBlock) = feePoolStaking.userFeesInfo(_userAddress);

            assertEq(expectedUserStakedAmount, actualUserStakedAmount);
            assertEq(expectedUserStakedWeight, actualUserStakedWeight);
            assertEq(expectedUserLastStakedBlock, actualUserLastStakedBlock);
            assertEq(expectedUserLastClaimedBlock, actualUserLastClaimedBlock);   
        }
    }
}
