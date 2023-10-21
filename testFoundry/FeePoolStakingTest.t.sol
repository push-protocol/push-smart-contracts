// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "../contracts/token/EPNS.sol";
import "../contracts/PushStaking/PushFeePoolStaking.sol";

contract FeePoolStakingTest is Test {
    EPNS public pushToken;
    PushFeePoolStaking public feePoolStaking;

    uint256 genesis;
    uint256 epochDuration;
    // Addresses and Set-Ups
    address public admin = address(1);
    address public alice = makeAddr("alice");
    address public charlie = makeAddr("charlie");
    address public tony = makeAddr("tony");
    address public bob = makeAddr("bob");

    function setUp() external {
        pushToken = new EPNS(admin);
        feePoolStaking = new PushFeePoolStaking();

        feePoolStaking.initialize(
            admin,
            address(1), //address(coreAddress)
            address(2), // Should be PUSH Token Address
            0, //_genesisEpoch
            0, //_lastEpochInitialized
            0, //_lastTotalStakeEpochInitialized
            0, //_totalStakedAmount
            0  // _previouslySetEpochRewards
        );
    }

    function testVerifyAdmin() external {
        address owner = feePoolStaking.pushChannelAdmin();
        assertEq(owner, admin);
    }

}