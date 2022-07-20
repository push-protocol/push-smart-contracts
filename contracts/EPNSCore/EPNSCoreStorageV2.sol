pragma solidity >=0.6.0 <0.7.0;

contract EPNSCoreStorageV2 {
    /* *** V2 State variables *** */
    uint256 public totalRewardsClaimed;
    mapping(address => uint256) public channelUpdateCounter;
    mapping(address => uint256) public usersRewardsClaimed;
}
