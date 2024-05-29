pragma solidity ^0.8.20;

import { CoreTypes } from "../libraries/DataTypes.sol";

contract PushCoreStorageV1_5 {
    /* **************
    MAPPINGS
    *************** */

    mapping(address => CoreTypes.Channel) public channels;
    mapping(uint256 => address) public channelById; // NOT IN USE
    mapping(address => string) public channelNotifSettings;

    /* ***************
    STATE VARIABLES
    *************** */
    string public constant name = "EPNS_CORE_V2";
    bool oneTimeCheck;
    bool public isMigrationComplete;

    address public pushChannelAdmin;
    address public governance;
    address public FOUNDATION;// RE-USE STORAGE
    address public aDaiAddress;
    address public WETH_ADDRESS;
    address public epnsCommunicator;
    address public UNISWAP_V2_ROUTER;
    address public PUSH_TOKEN_ADDRESS;
    address public lendingPoolProviderAddress;

    uint256 public REFERRAL_CODE;
    uint256 ADJUST_FOR_FLOAT;
    uint256 public channelsCount;

    ///  @notice Helper Variables for FSRatio Calculation | GROUPS = CHANNELS -> NOT IN USE
    uint256 public HOLDER_FEE_POOL;// RE-USE STORAGE
    uint256 public WALLET_FEE_POOL;// RE-USE STORAGE
    uint256 public WALLET_TOTAL_SHARES;// RE-USE STORAGE
    uint256 public groupFairShareCount;

    /// @notice Necessary variables for Keeping track of Funds and Fees
    uint256 public CHANNEL_POOL_FUNDS;
    uint256 public PROTOCOL_POOL_FEES;
    uint256 public ADD_CHANNEL_MIN_FEES;
    uint256 public FEE_AMOUNT;
    uint256 public MIN_POOL_CONTRIBUTION;
}
