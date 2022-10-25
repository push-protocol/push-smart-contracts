pragma solidity >=0.6.0 <0.7.0;

contract EPNSCoreStorageV2 {
    /* *** V2 State variables *** */
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name, uint256 chainId, address verifyingContract)"
        );
    bytes32 public constant CREATE_CHANNEL_TYPEHASH =
        keccak256("CreateChannel(ChannelType channelType, bytes identity, uint256 amount, uint256 channelExpiryTime, uint256 nonce, uint256 expiry)");

    mapping(address => uint256) public nonces;
    mapping(address => uint256) public channelUpdateCounter;

     /* ***************
    
        EXPERIMENTAL ZONE - Stake and Claim Function -> V3
    
    *************** */

    uint256 public stakeEpochEnd = 0; // periodFinish
    uint256 public rewardRate = 0;
    uint256 public stakeEpochDuration = 7 days; //rewardsDuration
    uint256 public lastUpdateTime;
    uint256 public totalStakedAmount; // totalSupply
    uint256 public rewardPerTokenStored;

    // Mappings 
    mapping(address => uint) public rewards;
    mapping(address => uint256) public userStakedAmount;
    mapping(address => uint) public userRewardPerTokenPaid;
    mapping(address => uint256) public usersRewardsClaimed;   
}
