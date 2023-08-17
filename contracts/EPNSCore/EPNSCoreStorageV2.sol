pragma solidity >=0.6.0 <0.7.0;

contract EPNSCoreStorageV2 {
    /* *** V2 State variables *** */
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name, uint256 chainId, address verifyingContract)"
        );
    bytes32 public constant CREATE_CHANNEL_TYPEHASH =
        keccak256(
            "CreateChannel(ChannelType channelType, bytes identity, uint256 amount, uint256 channelExpiryTime, uint256 nonce, uint256 expiry)"
        );

    mapping(address => uint256) public nonces;
    mapping(address => uint256) public channelUpdateCounter;
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

    // @notice: Stores all the individual epoch rewards
    mapping(uint256 => uint256) public epochRewards;
    // @notice: Stores User's Fees Details
    mapping(address => UserFessInfo) public userFeesInfo;
    // @notice: Stores the total staked weight at a specific epoch.
    mapping(uint256 => uint256) public epochToTotalStakedWeight;

    /** Handling bridged information **/
    mapping(address => uint256) public celebUserFunds;
}
