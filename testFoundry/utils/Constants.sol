// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.11;

abstract contract Constants {
    // General Constant Values of All Contracts
    uint256 internal constant DEC_27_2021 = 1_640_605_391;

    // Specific Constant Values for Staking-Related Contracts
    uint256 public genesisEpoch = 17_821_509;
    uint256 public lastEpochInitialized = 5;
    uint256 public lastTotalStakeEpochInitialized = 0;
    uint256 public totalStakedAmount = 6_654_086 ether;
    uint256 public previouslySetEpochRewards = 60_000 ether;
    uint256 public constant epochDuration = 21 * 7156; // 21 * number of blocks per day(7156) ~ 20 day approx
}
