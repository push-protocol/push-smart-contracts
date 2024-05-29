pragma solidity ^0.8.20;

import { StakingTypes } from "../libraries/DataTypes.sol";

contract PushCoreStorageV2 {
    /* *** V2 State variables *** */
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name, uint256 chainId, address verifyingContract)");
    bytes32 public constant CREATE_CHANNEL_TYPEHASH = keccak256(
        "CreateChannel(ChannelType channelType, bytes identity, uint256 amount, uint256 channelExpiryTime, uint256 nonce, uint256 expiry)"
    );

    mapping(address => uint256) public nonces;
    mapping(address => uint256) public channelUpdateCounter;
    /**
     * Staking V2 state variables *
     */
    mapping(address => uint256) public usersRewardsClaimed;

    uint256 public genesisEpoch; // Block number at which Stakig starts
    uint256 lastEpochInitialized; // The last EPOCH ID initialized with the respective epoch rewards
    uint256 lastTotalStakeEpochInitialized; // The last EPOCH ID initialized with the respective total staked weight
    uint256 public totalStakedAmount; // Total token weight staked in Protocol at any given time
    uint256 public previouslySetEpochRewards; // Amount of rewards set in last initialized epoch
    uint256 public constant epochDuration = 21 * 7156; // 21 * number of blocks per day(7156) ~ 20 day approx

    /// @notice Stores all the individual epoch rewards
    mapping(uint256 => uint256) public epochRewards;
    /// @notice Stores User's Fees Details
    mapping(address => StakingTypes.UserFessInfo) public userFeesInfo;
    /// @notice Stores the total staked weight at a specific epoch.
    mapping(uint256 => uint256) public epochToTotalStakedWeight;

    /**
     * Handling bridged information *
     */
    mapping(address => uint256) public celebUserFunds;

    /* *** v3 State variables *** */
    mapping(address wallet => uint256 sharesAmount) public WalletToShares ;
    mapping(address wallet => uint256 sharesAmount) public WalletToRewards ;
}
