pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;

/**
 * EPNS Core, is the main protocol that deals with the imperative
 * features and functionalities like Channel Creation, Governance etc.
 **/

// Essential Imports

import "./interfaces/ILendingPool.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IEPNSCommunicator.sol";
import "./interfaces/ILendingPoolAddressesProvider.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "hardhat/console.sol";

contract EPNSCore is Initializable, ReentrancyGuard, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /* ***************
     * DEFINE ENUMS AND CONSTANTS
     *************** */
    // For Message Type
    enum ChannelType {
        ProtocolNonInterest,
        ProtocolPromotion,
        InterestBearingOpen,
        InterestBearingMutual
    }
    enum ChannelAction {
        ChannelRemoved,
        ChannelAdded,
        ChannelUpdated
    }
    enum SubscriberAction {
        SubscriberRemoved,
        SubscriberAdded,
        SubscriberUpdated
    }

    /**
     * @notice Channel Struct that involves imperative details about
     * a specific Channel.
     **/
    struct Channel {
        // Channel Type
        ChannelType channelType;
        uint8 isActivated; // Flag to check if Channel is Activated
        uint8 isBlocked; // Flag to check if Channel is Compltely blocked
        // Channel Pool Contribution
        uint256 poolContribution;
        uint256 memberCount;
        uint256 channelHistoricalZ;
        uint256 channelFairShareCount;
        uint256 channelLastUpdate; // The last update block number, used to calculate fair share
        // To calculate fair share of profit from the pool of channels generating interest
        uint256 channelStartBlock; // Helps in defining when channel started for pool and profit calculation
        uint256 channelUpdateBlock; // Helps in outlining when channel was updated
        uint256 channelWeight; // The individual weight to be applied as per pool contribution
        // TBD -> THE FOLLOWING STRUCT ELEMENTS' SIGNIFICANCE NEEDS TO BE DISCUSSED.
        // These were either used to keep track of Subscribers or used in the subscribe/unsubscribe functions to calculate the FS Ratio

        //mapping(address => bool) memberExists;  // To keep track of subscribers info
        // For iterable mapping
        mapping(address => uint256) members;
        mapping(uint256 => address) mapAddressMember; // This maps to the user
        // To calculate fair share of profit for a subscriber
        // The historical constant that is applied with (wnx0 + wnx1 + .... + wnxZ)
        // Read more in the repo: https://github.com/ethereum-push-notification-system
        mapping(address => uint256) memberLastUpdate;
    }

    /** MAPPINGS **/
    mapping(address => Channel) public channels;
    mapping(uint256 => address) public mapAddressChannels;
    mapping(address => uint256) public usersInterestClaimed;
    mapping(address => uint256) public usersInterestInWallet;

    /** STATE VARIABLES **/
    string public constant name = "EPNS CORE V4";

    uint256 ADJUST_FOR_FLOAT;

    address public epnsCommunicator;
    address public lendingPoolProviderAddress;
    address public daiAddress;
    address public aDaiAddress;
    address public governance;

    uint256 public channelsCount; // Record of total Channels in the protocol
    //  Helper Variables for FSRatio Calculation | GROUPS = CHANNELS
    uint256 public groupNormalizedWeight;
    uint256 public groupHistoricalZ;
    uint256 public groupLastUpdate;
    uint256 public groupFairShareCount;

    address private UNISWAP_V2_ROUTER;
    address private PUSH_TOKEN_ADDRESS;

    // Necessary variables for Defi
    uint256 public poolFunds;
    uint256 public REFERRAL_CODE;
    uint256 DELEGATED_CONTRACT_FEES;
    uint256 ADD_CHANNEL_MIN_POOL_CONTRIBUTION;
    uint256 ADD_CHANNEL_MAX_POOL_CONTRIBUTION;

    /** EVENTS **/
    event DeactivateChannel(address indexed channel);
    event UpdateChannel(address indexed channel, bytes identity);
    event Withdrawal(address indexed to, address token, uint256 amount);
    event InterestClaimed(address indexed user, uint256 indexed amount);
    event AddChannel(
        address indexed channel,
        ChannelType indexed channelType,
        bytes identity
    );

    /* ************** 
    
    => MODIFIERS <=

    ***************/
    modifier onlyGov() {
        require(
            msg.sender == governance,
            "EPNSCore::onlyGov, user is not governance"
        );
        _;
    }

    // THESE 3 USE USER struct, WILL HAVE TO REDEISGN THEM
    // modifier onlyUserWithNoChannel() {
    //     require(!users[msg.sender].channellized, "User already a Channel Owner");
    //     _;
    // }

    // modifier onlyActivatedChannels(address _channel) {
    //     require(users[_channel].channellized && !channels[_channel].deactivated, "Channel deactivated or doesn't exists");
    //     _;
    // }

    // modifier onlyChannelOwner(address _channel) {
    //     require(
    //     ((users[_channel].channellized && msg.sender == _channel) || (msg.sender == governance && _channel == 0x0000000000000000000000000000000000000000)),
    //     "Channel doesn't Exists"
    //     );
    //     _;
    // }

    modifier onlyUserAllowedChannelType(ChannelType _channelType) {
        require(
            (_channelType == ChannelType.InterestBearingOpen ||
                _channelType == ChannelType.InterestBearingMutual),
            "Channel Type Invalid"
        );

        _;
    }

    // modifier onlySubscribed(address _channel, address _subscriber) {
    //     require(channels[_channel].memberExists[_subscriber], "Subscriber doesn't Exists");
    //     _;
    // }

    modifier onlyNonOwnerSubscribed(address _channel, address _subscriber) {
        require(
            _channel != _subscriber &&
                channels[_channel].memberExists[_subscriber],
            "Either Channel Owner or Not Subscribed"
        );
        _;
    }

    modifier onlyNonSubscribed(address _channel, address _subscriber) {
        require(
            !channels[_channel].memberExists[_subscriber],
            "Subscriber already Exists"
        );
        _;
    }

    /* ***************
        INITIALIZER

    *************** */

    function initialize(
        address _governance,
        address _lendingPoolProviderAddress,
        address _daiAddress,
        address _aDaiAddress,
        uint256 _referralCode
    ) public initializer returns (bool success) {
        // setup addresses
        governance = _governance; // multisig/timelock, also controls the proxy
        lendingPoolProviderAddress = _lendingPoolProviderAddress;
        daiAddress = _daiAddress;
        aDaiAddress = _aDaiAddress;
        REFERRAL_CODE = _referralCode;
        UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
        PUSH_TOKEN_ADDRESS = 0xf418588522d5dd018b425E472991E52EBBeEEEEE;

        DELEGATED_CONTRACT_FEES = 1 * 10**17; // 0.1 DAI to perform any delegate call

        ADD_CHANNEL_MIN_POOL_CONTRIBUTION = 50 * 10**18; // 50 DAI or above to create the channel
        ADD_CHANNEL_MAX_POOL_CONTRIBUTION = 250000 * 50 * 10**18; // 250k DAI or below, we don't want channel to make a costly mistake as well

        groupLastUpdate = block.number;
        groupNormalizedWeight = ADJUST_FOR_FLOAT; // Always Starts with 1 * ADJUST FOR FLOAT

        ADJUST_FOR_FLOAT = 10**7;

        // Add EPNS Channels
        // First is for all users
        // Second is all channel alerter, amount deposited for both is 0
        // to save gas, emit both the events out
        // identity = payloadtype + payloadhash

        // EPNS ALL USERS
        emit AddChannel(
            governance,
            ChannelType.ProtocolNonInterest,
            "1+QmSbRT16JVF922yAB26YxWFD6DmGsnSHm8VBrGUQnXTS74"
        );
        _createChannel(governance, ChannelType.ProtocolNonInterest, 0); // should the owner of the contract be the channel? should it be governance in this case?

        // EPNS ALERTER CHANNEL
        emit AddChannel(
            0x0000000000000000000000000000000000000000,
            ChannelType.ProtocolNonInterest,
            "1+QmTCKYL2HRbwD6nGNvFLe4wPvDNuaYGr6RiVeCvWjVpn5s"
        );
        _createChannel(
            0x0000000000000000000000000000000000000000,
            ChannelType.ProtocolNonInterest,
            0
        );

        // Create Channel
        success = true;
    }

    //TBD - Use of onlyOwner and Setter function for communicator?
    function setEpnsCommunicatorAddress(address _commAddress)
        external
        onlyOwner
    {
        epnsCommunicator = _commAddress;
    }

    /* ***********************************
        CHANNEL RELATED FUNCTIONALTIES

    **************************************/

    /**
     * @notice Base Channel Creation Function that allows users to Create Their own Channels and Stores crucial details about the Channel being created
     * @dev    -Initializes the Channel Struct
     *         -Subscribes the Channel's Owner to Imperative EPNS Channels as well as their Own Channels
     *         -Increases Channel Counts and Readjusts the FS of Channels
     * @param _channel         address of the channel being Created
     * @param _channelType     The type of the Channel
     * @param _amonutDeposited The total amount being deposited while Channel Creation
     **/
    function _createChannel(
        address _channel,
        ChannelType _channelType,
        uint256 _amountDeposited
    ) private {
        // Calculate channel weight
        uint256 _channelWeight = _amountDeposited.mul(ADJUST_FOR_FLOAT).div(
            ADD_CHANNEL_MIN_POOL_CONTRIBUTION
        );

        // Next create the channel and mark user as channellized
        channels[_channel].isActivated = 1;

        channels[_channel].poolContribution = _amountDeposited;
        channels[_channel].channelType = _channelType;
        channels[_channel].channelStartBlock = block.number;
        channels[_channel].channelUpdateBlock = block.number;
        channels[_channel].channelWeight = _channelWeight;

        // Add to map of addresses and increment channel count
        mapAddressChannels[channelsCount] = _channel;
        channelsCount = channelsCount.add(1);

        // Readjust fair share if interest bearing
        if (
            _channelType == ChannelType.ProtocolPromotion ||
            _channelType == ChannelType.InterestBearingOpen ||
            _channelType == ChannelType.InterestBearingMutual
        ) {
            (
                groupFairShareCount,
                groupNormalizedWeight,
                groupHistoricalZ,
                groupLastUpdate
            ) = _readjustFairShareOfChannels(
                ChannelAction.ChannelAdded,
                _channelWeight,
                groupFairShareCount,
                groupNormalizedWeight,
                groupHistoricalZ,
                groupLastUpdate
            );
        }

        // Subscribe them to their own channel as well
        if (_channel != governance) {
            IEPNSCommunicator(epnsCommunicator).subscribeViaCore(
                _channel,
                _channel
            );
        }

        // All Channels are subscribed to EPNS Alerter as well, unless it's the EPNS Alerter channel iteself
        if (_channel != 0x0000000000000000000000000000000000000000) {
            IEPNSCommunicator(epnsCommunicator).subscribeViaCore(
                0x0000000000000000000000000000000000000000,
                _channel
            );
            IEPNSCommunicator(epnsCommunicator).subscribeViaCore(
                governance,
                _channel
            );
        }
    }

     /* ************** 
    
    => FAIR SHARE RATIO CALCULATIONS <=

    *************** */
    /// @dev readjust fair share runs on channel addition, removal or update of channel
    function _readjustFairShareOfChannels(
        ChannelAction _action,
        uint256 _channelWeight,
        uint256 _groupFairShareCount,
        uint256 _groupNormalizedWeight,
        uint256 _groupHistoricalZ,
        uint256 _groupLastUpdate
    )
        private
        view
        returns (
            uint256 groupNewCount,
            uint256 groupNewNormalizedWeight,
            uint256 groupNewHistoricalZ,
            uint256 groupNewLastUpdate
        )
    {
        // readjusts the group count and do deconstruction of weight
        uint256 groupModCount = _groupFairShareCount;
        uint256 prevGroupCount = groupModCount;

        uint256 totalWeight;
        uint256 adjustedNormalizedWeight = _groupNormalizedWeight; //_groupNormalizedWeight;

        // Increment or decrement count based on flag
        if (_action == ChannelAction.ChannelAdded) {
            groupModCount = groupModCount.add(1);

            totalWeight = adjustedNormalizedWeight.mul(prevGroupCount);
            totalWeight = totalWeight.add(_channelWeight);
        } else if (_action == ChannelAction.ChannelRemoved) {
            groupModCount = groupModCount.sub(1);

            totalWeight = adjustedNormalizedWeight.mul(prevGroupCount);
            totalWeight = totalWeight.sub(_channelWeight);
        } else if (_action == ChannelAction.ChannelUpdated) {
            totalWeight = adjustedNormalizedWeight.mul(prevGroupCount.sub(1));
            totalWeight = totalWeight.add(_channelWeight);
        } else {
            revert("Invalid Channel Action");
        }

        // now calculate the historical constant
        // z = z + nxw
        // z is the historical constant
        // n is the previous count of group fair share
        // x is the differential between the latest block and the last update block of the group
        // w is the normalized average of the group (ie, groupA weight is 1 and groupB is 2 then w is (1+2)/2 = 1.5)
        uint256 n = groupModCount;
        uint256 x = block.number.sub(_groupLastUpdate);
        uint256 w = totalWeight.div(groupModCount);
        uint256 z = _groupHistoricalZ;

        uint256 nx = n.mul(x);
        uint256 nxw = nx.mul(w);

        // Save Historical Constant and Update Last Change Block
        z = z.add(nxw);

        if (n == 1) {
            // z should start from here as this is first channel
            z = 0;
        }

        // Update return variables
        groupNewCount = groupModCount;
        groupNewNormalizedWeight = w;
        groupNewHistoricalZ = z;
        groupNewLastUpdate = block.number;
    }

    function getChainId() internal pure returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }
}
