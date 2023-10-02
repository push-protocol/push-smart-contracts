pragma solidity >=0.6.0 <0.7.0;

contract PushFeePoolStorage {

    /** Staking V2 state variables **/
    mapping(address => uint256) public usersRewardsClaimed;

    //@notice: Stores all user's staking details
    struct UserFessInfo {
        uint256 stakedAmount;
        uint256 stakedWeight;
        uint256 lastStakedBlock;
        uint256 lastClaimedBlock;
        mapping(uint256 => uint256) epochToUserStakedWeight;
    }

    uint256 public genesisEpoch; // Block number at which Stakig starts
    uint256 lastEpochInitialized; // The last EPOCH ID initialized with the respective epoch rewards
    uint256 lastTotalStakeEpochInitialized; // The last EPOCH ID initialized with the respective total staked weight
    uint256 public totalStakedAmount; // Total token weight staked in Protocol at any given time
    uint256 public previouslySetEpochRewards; // Amount of rewards set in last initialized epoch
    uint256 public constant epochDuration = 21 * 7156; // 21 * number of blocks per day(7156) ~ 20 day approx

    address public pushChannelAdmin;
    address public PUSH_TOKEN_ADDRESS;
    address public governance;
    address public core;

    // @notice: Stores all the individual epoch rewards
    mapping(uint256 => uint256) public epochRewards;
    // @notice: Stores User's Fees Details
    mapping(address => UserFessInfo) public userFeesInfo;
    // @notice: Stores the total staked weight at a specific epoch.
    mapping(uint256 => uint256) public epochToTotalStakedWeight;
    bool migrated;
}
