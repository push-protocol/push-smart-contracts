pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;

/**
 * EPNS Core is the main protocol that deals with the imperative
 * features and functionalities like Channel Creation, admin etc.
 *
 * This protocol will be specifically deployed on Ethereum Blockchain while the Communicator
 * protocols can be deployed on Multiple Chains.
 * The EPNS Core is more inclined towards the storing and handling the Channel related
 * Functionalties.
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

    /**
     * @notice Channel Struct that involves imperative details about
     * a specific Channel.
     **/
    struct Channel {
        // Channel Type
        ChannelType channelType;
        uint8 channelState; // Channel State Details: 0 -> INACTIVE, 1 -> ACTIVATED, 2 -> DeActivated By Channel Owner, 3 -> BLOCKED by ADMIN/Governance
        uint8 isChannelVerified; // Channel Verification Status: 0 -> UnVerified Channels, 1 -> Verified by Admin, 2 -> Verified by Channel Owners
        uint256 poolContribution;
        uint256 channelHistoricalZ;
        uint256 channelFairShareCount;
        uint256 channelLastUpdate; // The last update block number, used to calculate fair share
        // To calculate fair share of profit from the pool of channels generating interest
        uint256 channelStartBlock; // Helps in defining when channel started for pool and profit calculation
        uint256 channelUpdateBlock; // Helps in outlining when channel was updated
        uint256 channelWeight; // The individual weight to be applied as per pool contribution
        // TBD -> THE FOLLOWING STRUCT ELEMENTS' SIGNIFICANCE NEEDS TO BE DISCUSSED.
        // TBD -> memberExists has been removed
        // These were either used to keep track of Subscribers or used in the subscribe/unsubscribe functions to calculate the FS Ratio

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
    mapping(address => string) public channelNotifSettings;
    mapping(address => uint256) public usersInterestClaimed;
    /** CHANNEL VERIFICATION MAPPINGS **/
    mapping(address => address) public channelVerifiedBy; // Keeps track of Channel Being Verified => The VERIFIER CHANNEL
    mapping(address => uint256) public verifiedChannelCount; // Keeps track of Verifier Channel Address => Total Number of Channels it Verified
    mapping(address => address[]) public verifiedViaAdminRecords; // Array of All Channels verified by ADMIN
    mapping(address => address[]) public verifiedViaChannelRecords; // Array of All Channels verified by CHANNEL OWNERS

    /** STATE VARIABLES **/
    string public constant name = "EPNS CORE V4";

    uint256 ADJUST_FOR_FLOAT;

    address public epnsCommunicator;
    address public lendingPoolProviderAddress;
    address public daiAddress;
    address public aDaiAddress;
    address public admin;

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
    uint256 CHANNEL_DEACTIVATION_FEES;
    uint256 ADD_CHANNEL_MIN_POOL_CONTRIBUTION;
    uint256 ADD_CHANNEL_MAX_POOL_CONTRIBUTION;

    /** EVENTS **/
    event UpdateChannel(address indexed channel, bytes identity);
    event Withdrawal(address indexed to, address token, uint256 amount);
    event InterestClaimed(address indexed user, uint256 indexed amount);
    event ChannelVerified(
        address indexed verifiedChannel,
        address indexed verifier
    );
    event ChannelVerificationRevoked(
        address indexed trargetChannel,
        address indexed verificationRevoker
    );
    event DeactivateChannel(
        address indexed channel,
        uint256 indexed amountRefunded
    );
    event ReactivateChannel(
        address indexed channel,
        uint256 indexed amountDeposited
    );
    event AddChannel(
        address indexed channel,
        ChannelType indexed channelType,
        bytes identity
    );
    event ChannelNotifcationSettingsAdded(
        address _channel,
        uint256 totalNotifOptions,
        string _notifSettings,
        string _notifDescription
    );

    /* ************** 
    
    => MODIFIERS <=

    ***************/
    modifier onlyAdmin() {
        require(msg.sender == admin, "EPNSCore::onlyAdmin, user is not admin");
        _;
    }
    // INFO -> onlyActivatedChannels redesigned
    modifier onlyActivatedChannels(address _channel) {
        require(
            channels[_channel].channelState == 1,
            "Channel Deactivated, Blocked or Doesn't Exist"
        );
        _;
    }
    // INFO -> onlyUserWithNoChannel became onlyInactiveChannels
    modifier onlyInactiveChannels(address _channel) {
        require(
            channels[_channel].channelState == 0,
            "Channel is already activated "
        );
        _;
    }

    modifier onlyDeactivatedChannels(address _channel) {
        require(
            channels[_channel].channelState == 2,
            "Channel is already activated "
        );
        _;
    }

    modifier onlyUnblockedChannels(address _channel) {
        require(
            channels[_channel].channelState != 3,
            "Channel is Completely BLOCKED"
        );
        _;
    }

    // INFO -> onlyChannelOwner redesigned
    modifier onlyChannelOwner(address _channel) {
        require(
            ((channels[_channel].channelState == 1 && msg.sender == _channel) ||
                (msg.sender == admin &&
                    _channel == 0x0000000000000000000000000000000000000000)),
            "Channel doesn't Exists or Invalid Channel Owner"
        );
        _;
    }

    modifier onlyUserAllowedChannelType(ChannelType _channelType) {
        require(
            (_channelType == ChannelType.InterestBearingOpen ||
                _channelType == ChannelType.InterestBearingMutual),
            "Channel Type Invalid"
        );

        _;
    }

    modifier onlyUnverifiedChannels(address _channel) {
        require(
            channels[_channel].isChannelVerified == 0,
            "Channel is Already Verified"
        );
        _;
    }

    modifier onlyAdminVerifiedChannels(address _channel) {
        require(
            channels[_channel].isChannelVerified == 1,
            "Channel is Verified By ADMIN"
        );
        _;
    }

    modifier onlyChannelVerifiedChannels(address _channel) {
        require(
            channels[_channel].isChannelVerified == 2,
            "Channel is Verified By Other Channel"
        );
        _;
    }

    modifier onlyVerifiedChannels(address _channel) {
        require(
            channels[_channel].isChannelVerified == 1 ||
                channels[_channel].isChannelVerified == 2,
            "Channel is Not Verified Yet"
        );
        _;
    }

    /* ***************
        INITIALIZER

    *************** */

    function initialize(
        address _admin,
        address _lendingPoolProviderAddress,
        address _daiAddress,
        address _aDaiAddress,
        uint256 _referralCode
    ) public initializer returns (bool success) {
        // setup addresses
        admin = _admin; // multisig/timelock, also controls the proxy
        lendingPoolProviderAddress = _lendingPoolProviderAddress;
        daiAddress = _daiAddress;
        aDaiAddress = _aDaiAddress;
        REFERRAL_CODE = _referralCode;
        UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
        PUSH_TOKEN_ADDRESS = 0xf418588522d5dd018b425E472991E52EBBeEEEEE;

        DELEGATED_CONTRACT_FEES = 1 * 10**17; // 0.1 DAI to perform any delegate call

        CHANNEL_DEACTIVATION_FEES = 10 ether; // 10 DAI out of total deposited DAIs is charged for Deactivating a Channel
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION = 50 ether; // 50 DAI or above to create the channel
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
            admin,
            ChannelType.ProtocolNonInterest,
            "1+QmSbRT16JVF922yAB26YxWFD6DmGsnSHm8VBrGUQnXTS74"
        );
        _createChannel(admin, ChannelType.ProtocolNonInterest, 0); // should the owner of the contract be the channel? should it be admin in this case?

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

    /* ***************
        SETTER FUNCTIONS

    *************** */

    //TBD - Use of onlyADMIN vs onlyGov in Setter functions below:

    function setEpnsCommunicatorAddress(address _commAddress)
        external
        onlyAdmin
    {
        epnsCommunicator = _commAddress;
    }

    function setChannelDeactivationFees(uint256 _newFees) external onlyAdmin {
        require(
            _newFees > 0,
            "Channel Deactivation Fees must be greater than ZERO"
        );
        CHANNEL_DEACTIVATION_FEES = _newFees;
    }

    function setMinChannelCreationFees(uint256 _newFees) external onlyAdmin {
        require(
            _newFees > 0,
            "Channel MIN Creation Fees must be greater than ZERO"
        );
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION = _newFees;
    }

    function setMaxChannelCreationFees(uint256 _newFees) external onlyAdmin {
        require(
            _newFees > 0,
            "Channel MAX Creation Fees must be greater than ZERO"
        );
        ADD_CHANNEL_MAX_POOL_CONTRIBUTION = _newFees;
    }

    function transferAdminControl(address _newAdmin) public onlyAdmin {
        require(_newAdmin != address(0), "Invalid Address");
        require(_newAdmin != admin, "New admin can't be current admin");
        admin = _newAdmin;
    }

    /* ***********************************
        Channel HELPER Functions

    **************************************/
    function getChannelState(address _channel) public returns (uint256 state) {
        state = channels[_channel].channelState;
    }

    /* ***********************************
        CHANNEL RELATED FUNCTIONALTIES

    **************************************/

    /**
     * @notice Allows Channel Owner to update their Channel Description/Detail
     *
     * @dev    Emits an event with the new identity for the respective Channel Address
     *         Records the Block Number of the Block at which the Channel is being updated with a New Identity
     *
     * @param _channel     address of the Channel
     * @param _newIdentity bytes Value for the New Identity of the Channel
     **/
    function updateChannelMeta(address _channel, bytes calldata _newIdentity)
        external
        onlyChannelOwner(_channel)
    {
        emit UpdateChannel(_channel, _newIdentity);

        _updateChannelMeta(_channel);
    }

    function _updateChannelMeta(address _channel) internal {
        channels[msg.sender].channelUpdateBlock = block.number;
    }

    /**
     * @notice Allows the Creation of a EPNS Promoter Channel
     *
     * @dev    Can only be called once for the Core Contract Address.
     *         Follows the usual procedure for Channel Creation
     **/
    /// @dev One time, Create Promoter Channel
    function createPromoterChannel()
        external
        onlyInactiveChannels(address(this))
    {
        // EPNS PROMOTER CHANNEL
        // Check the allowance and transfer funds
        IERC20(daiAddress).transferFrom(
            msg.sender,
            address(this),
            ADD_CHANNEL_MIN_POOL_CONTRIBUTION
        );

        // Then Add Promoter Channel
        emit AddChannel(
            address(this),
            ChannelType.ProtocolPromotion,
            "1+QmRcewnNpdt2DWYuud3LxHTwox2RqQ8uyZWDJ6eY6iHkfn"
        );

        // Call create channel after fees transfer
        _createChannelAfterTransferOfFees(
            address(this),
            ChannelType.ProtocolPromotion,
            ADD_CHANNEL_MIN_POOL_CONTRIBUTION
        );
    }

    /**
     * @notice An external function that allows users to Create their Own Channels by depositing a valid amount of DAI.
     * @dev    Only allows users to Create One Channel for a specific address.
     *         Only allows a Valid Channel Type to be assigned for the Channel Being created.
     *         Validates and Transfers the amount of DAI from the Channel Creator to this Contract Address
     *         Deposits the Funds the Lending Pool and creates the Channel for the msg.sender.
     * @param  _channelType the type of the Channel Being created
     * @param  _identity the bytes value of the identity of the Channel
     * @param  _amount Amount of DAI to be deposited before Creating the Channel
     **/
    function createChannelWithFees(
        ChannelType _channelType,
        bytes calldata _identity,
        uint256 _amount
    )
        external
        onlyInactiveChannels(msg.sender)
        onlyUserAllowedChannelType(_channelType)
    {
        // Save gas, Emit the event out
        emit AddChannel(msg.sender, _channelType, _identity);

        // Bubble down to create channel
        _createChannelWithFees(msg.sender, _channelType, _amount);
    }

    function _createChannelWithFees(
        address _channel,
        ChannelType _channelType,
        uint256 _amount
    ) private {
        // Check if it's equal or above Channel Pool Contribution
        require(
            _amount >= ADD_CHANNEL_MIN_POOL_CONTRIBUTION,
            "Insufficient Funds or max ceiling reached"
        );
        IERC20(daiAddress).safeTransferFrom(_channel, address(this), _amount);
        _createChannelAfterTransferOfFees(_channel, _channelType, _amount);
    }

    function _createChannelAfterTransferOfFees(
        address _channel,
        ChannelType _channelType,
        uint256 _amount
    ) private {
        // Deposit funds to pool
        _depositFundsToPool(_amount);

        // Call Create Channel
        _createChannel(_channel, _channelType, _amount);
    }

    /**
     * @notice Base Channel Creation Function that allows users to Create Their own Channels and Stores crucial details about the Channel being created
     * @dev    -Initializes the Channel Struct
     *         -Subscribes the Channel's Owner to Imperative EPNS Channels as well as their Own Channels
     *         -Increases Channel Counts and Readjusts the FS of Channels
     * @param _channel         address of the channel being Created
     * @param _channelType     The type of the Channel
     * @param _amountDeposited The total amount being deposited while Channel Creation
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
        channels[_channel].channelState = 1;

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
        if (_channel != admin) {
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
                admin,
                _channel
            );
        }
    }

    /** @notice - Deliminated Notification Settings string contains -> Total Notif Options + Notification Settings
     * For instance: 5+1-0+2-50-20-100+1-1+2-78-10-150
     *  5 -> Total Notification Options provided by a Channel owner
     *
     *  For Boolean Type Notif Options
     *  1-0 -> 1 stands for BOOLEAN type - 0 stands for Default Boolean Type for that Notifcation(set by Channel Owner), In this case FALSE.
     *  1-1 stands for BOOLEAN type - 1 stands for Default Boolean Type for that Notifcation(set by Channel Owner), In this case TRUE.
     *  
     *  For SLIDER TYPE Notif Options
     *   2-50-20-100 -> 2 stands for SLIDER TYPE - 50 stands for Default Value for that Option - 20 is the Start Range of that SLIDER - 100 is the END Range of that SLIDER Option
     *  2-78-10-150 -> 2 stands for SLIDER TYPE - 78 stands for Default Value for that Option - 10 is the Start Range of that SLIDER - 150 is the END Range of that SLIDER Option

     *  @param _notifOptions - Total Notification options provided by the Channel Owner
    // @param _notifSettings- Deliminated String of Notification Settings
    // @param _notifDescription - Description of each Notification that depicts the Purpose of that Notification
**/
    function createChannelNotificationSettings(
        uint256 _notifOptions,
        string calldata _notifSettings,
        string calldata _notifDescription
    ) external onlyActivatedChannels(msg.sender) {
        string memory notifSetting = string(
            abi.encodePacked(
                Strings.toString(_notifOptions),
                "+",
                _notifSettings
            )
        );
        channelNotifSettings[msg.sender] = notifSetting;
        emit ChannelNotifcationSettingsAdded(
            msg.sender,
            _notifOptions,
            notifSetting,
            _notifDescription
        );
    }

    /**
     * @notice Allows Channel Owner to Deactivate his/her Channel for any period of Time. Channels Deactivated can be Activated again.
     * @dev    - Function can only be Called by Already Activated Channels
     *         - Calculates the Total DAI Deposited by Channel Owner while Channel Creation.
     *         - Deducts CHANNEL_DEACTIVATION_FEES from the total Deposited DAI and Transfers back the remaining amount of DAI in the form of PUSH tokens.
     *         - Calculates the New Channel Weight and Readjusts the FS Ratio accordingly.
     *         - Updates the State of the Channel(channelState) and the New Channel Weight in the Channel's Struct
     *         - In case, the Channel Owner wishes to reactivate his/her channel, they need to Deposit at least the Minimum required DAI while reactivating.
     **/

    // TBD -> YET TO BE COMPLETED, DISCUSS THE FS PART and Channel Weight Updation Part
    function deactivateChannel() external onlyActivatedChannels(msg.sender) {
        Channel memory channelData = channels[msg.sender];

        uint256 totalAmountDeposited = channelData
            .channelWeight
            .mul(ADD_CHANNEL_MIN_POOL_CONTRIBUTION)
            .div(ADJUST_FOR_FLOAT);
        uint256 totalRefundableAmount = totalAmountDeposited.sub(
            CHANNEL_DEACTIVATION_FEES
        );

        uint256 _newChannelWeight = CHANNEL_DEACTIVATION_FEES
            .mul(ADJUST_FOR_FLOAT)
            .div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

        (
            groupFairShareCount,
            groupNormalizedWeight,
            groupHistoricalZ,
            groupLastUpdate
        ) = _readjustFairShareOfChannels(
            ChannelAction.ChannelUpdated,
            _newChannelWeight,
            groupFairShareCount,
            groupNormalizedWeight,
            groupHistoricalZ,
            groupLastUpdate
        );

        channels[msg.sender].channelWeight = _newChannelWeight;
        channels[msg.sender].channelState = 2;

        swapAndTransferaDaiToPUSH(msg.sender, totalRefundableAmount);
        emit DeactivateChannel(msg.sender, totalRefundableAmount);
    }

    /**
     * @notice Allows Channel Owner to Reactivate his/her Channel again.
     * @dev    - Function can only be called by previously Deactivated Channels
     *         - Channel Owner must Depost at least minimum amount of DAI to reactivate his/her channel.
     *         - Deposited Dai goes thorugh similar procedure and is deposited to AAVE .
     *         - Calculation of the new Channel Weight is performed and the FairShare is Readjusted once again with relevant details
     *         - Updates the State of the Channel(channelState) in the Channel's Struct.
     * @param _amount Amount of Dai to be deposited
     **/

    function reActivateChannel(uint256 _amount)
        external
        onlyDeactivatedChannels(msg.sender)
    {
        require(
            _amount >= ADD_CHANNEL_MIN_POOL_CONTRIBUTION,
            "Insufficient Funds or max ceiling reached"
        );
        IERC20(daiAddress).safeTransferFrom(msg.sender, address(this), _amount);
        _depositFundsToPool(_amount);

        uint256 _channelWeight = _amount.mul(ADJUST_FOR_FLOAT).div(
            ADD_CHANNEL_MIN_POOL_CONTRIBUTION
        );

        (
            groupFairShareCount,
            groupNormalizedWeight,
            groupHistoricalZ,
            groupLastUpdate
        ) = _readjustFairShareOfChannels(
            ChannelAction.ChannelUpdated,
            _channelWeight,
            groupFairShareCount,
            groupNormalizedWeight,
            groupHistoricalZ,
            groupLastUpdate
        );

        channels[msg.sender].channelWeight = _channelWeight;
        channels[msg.sender].channelState = 1;
        emit ReactivateChannel(msg.sender, _amount);
    }

    /* ************** 
    
    => CHANNEL VERIFICATION FUNCTIONALTIES <=

    *************** */

    /**
     * PLAN FOR CHANNEL VERIFICATION FEATURES
     *
     * 1. Update Channel Struct with a isChannelVerified uint8 value
     * 2. isChannelVerified => 0 when not verified, 1 when verified by Admin, 2 when verified by Other ChannelOwner
     * 3. Create 2 Mappings:
     *                         1. mapping(address => address[]) public verifiedViaChannelRecord;
     *                         2. mapping(address => address[]) public verifiedViaAdminRecord;
     *                         3. mapping(address => address) public verifiedBy;
     *
     * 4. Create Relevant Modifiers:
     *                         1. onlyNonVerifiedChannels
     *                         2. onlyVerifiedChannels;
     *                         3. onlyAdminVerifiedChannels;
     *                         4. onlyChannelVerifiedChannels;
     *
     * 5. Create Imperative Functions:
     *                         1. verifyChannelViaAdmin()
     *                         2. verifyChannelViaChannelOwners()
     *                         3. getAllVerifiedChannelsViaChannelOwners()
     *                         4. getChannelVerificationStatus()
     *                         5. revokeChannelVerification();
     *
     * 6. ANY ADDITIONAL FEATURE ???
     **/

    function getTotalVerifiedChannels(address _verifier)
        public
        view
        returns (uint256 totalVerifiedChannels)
    {
        totalVerifiedChannels = verifiedChannelCount[_verifier];
    }

    function getChannelVerificationStatus(address _channel)
        public
        view
        returns (uint8 _verificationStatus)
    {
        _verificationStatus = channels[_channel].isChannelVerified;
    }

    function getAllVerifiedChannel(address _verifier)
        public
        view
        returns (address[] memory)
    {
        uint256 totalVerified = getTotalVerifiedChannels(_verifier);
        address[] memory result = new address[](totalVerified);

        if (_verifier == admin) {
            for (uint256 i; i < totalVerified; i++) {
                result[i] = verifiedViaAdminRecords[_verifier][i];
            }
        } else {
            for (uint256 i; i < totalVerified; i++) {
                result[i] = verifiedViaChannelRecords[_verifier][i];
            }
        }

        return result;
    }

    /**
     * @notice    Function is designed specifically for the Admin to verify any particular Channel
     * @dev       Can only be Called by the Admin
     *            Calls the base function, i.e., verifyChannel() to execute the Main Verification Procedure
     * @param    _channel  Address of the channel to be Verified
     **/

    function verifyChannelViaAdmin(address _channel)
        external
        onlyAdmin
        returns (bool)
    {
        _verifyChannel(_channel, admin, 1);
        return true;
    }

    /**
     * @notice    Function is designed specifically for the Verified CHANNEL Owners to verify any particular Channel
     * @dev       Can only be Called by the Channel Owners who themselves have been verified by the ADMIN first
     *            Calls the base function, i.e., verifyChannel() to execute the Main Verification Procedure
     *
     * @param    _channel  Address of the channel to be Verified
     **/

    function verifyChannelViaChannelOwners(address _channel)
        external
        onlyAdminVerifiedChannels(msg.sender)
        returns (bool)
    {
        _verifyChannel(_channel, msg.sender, 2);
        return true;
    }

    /**
     * @notice    Base function that allows Admin or Channel Owners to Verify other Channels
     *
     * @dev       Can only be Called for UnVerified Channels
     *            Checks if the Caller of this function is an ADMIN or other Verified Channel Owners and Proceeds Accordingly
     *            If Caller is Admin:
     *                                a. Marks Channel Verification Status as '1'.
     *                                b. Updates the verifiedViaAdminRecords Mapping
     *                                c. Emits Relevant Events
     *            If Caller is Verified Channel Owners:
     *                                a. Marks Channel Verification Status as '2'.
     *                                b. Updates the verifiedViaChannelRecords Mapping
     *                                c. Updates the channelToChannelVerificationRecords mapping
     *                                d. Emits Relevant Events
     *
     * @param     _channel        Address of the channel to be Verified
     * @param     _verifier       Address of the Caller who is verifiying the Channel
     * @param     _verifierFlag   uint Value to indicate the Caller of this Base Verification function
     **/
    function _verifyChannel(
        address _channel,
        address _verifier,
        uint8 _verifierFlag
    ) private onlyActivatedChannels(_channel) onlyUnverifiedChannels(_channel) {
        Channel memory channelDetails = channels[_channel];

        if (_verifierFlag == 1) {
            channelDetails.isChannelVerified = 1;
            verifiedViaAdminRecords[_verifier].push(_channel);
        } else {
            channelDetails.isChannelVerified = 2;
            verifiedViaChannelRecords[_verifier].push(_channel);
        }

        channelVerifiedBy[_channel] = _verifier;
        verifiedChannelCount[_verifier] += 1;
        channels[_channel] = channelDetails;
        emit ChannelVerified(_channel, _verifier);
    }

      /**
     * @notice    The revokeVerificationViaAdmin allows the ADMIN of the Contract to Revoke any Specific Channel's Verified Tag
     *            Can be called for any Target Channel that has been verified either by Admin or other Channels
     *
     * @dev       Can only be Called for Verified Channels
     *            Can only be Called by the ADMIN of the contract
     *            Involves 2 Main CASES: 
                                         a. Either the Target Channel is CHILD Verified Channel (Channel that is NOT verified by ADMIN directly) or,
     *                                   b. The Target Channel is a PARENT VERIFIED Channel (Channel that is verified by ADMIN)
     *            If Target Channel CHILD:
     *                                   -> Checks for its Parent Channel.
     *                                   -> Update the verifiedViaChannelRecords mapping for Parent's Channel
     *                                   -> Update the channelVerifiedBy mapping for Target Channel.
     *                                   -> Revoke Verification of Target Channel                
     *            If Target Channel PARENT:
     *                                   -> Checks total number of Channels verified by Parent Channel
     *                                   -> Removes Verification for all Channels that were verified by the Target Parent Channel
     *                                   -> Update the channelVerifiedBy mapping for every Target Channel Target Channel.
     *                                   -> Deletes the verifiedViaChannelRecords for Parent's Channel
     *                                   -> Revoke Verification and Update channelVerifiedBy mapping for of the Parent Target Channel itself.
     *                               
     * @param     _targetChannel  Address of the channel whose Verification is to be Revoked
     **/

    function revokeVerificationViaAdmin(address _targetChannel)
        external
        onlyVerifiedChannels(_targetChannel)
        onlyAdmin()
        returns (bool)
    {
        Channel memory channelDetails = channels[_targetChannel];

        if (channelDetails.isChannelVerified == 1) {
            uint256 _totalVerifiedByAdmin = getTotalVerifiedChannels(admin);
            updateVerifiedChannelRecords(admin, _targetChannel, _totalVerifiedByAdmin, 1);

            uint256 _totalChannelsVerified = getTotalVerifiedChannels(_targetChannel);
            for (uint256 i; i < _totalChannelsVerified; i++) {

                address childChannel = verifiedViaChannelRecords[_targetChannel][i];
                channels[childChannel].isChannelVerified = 0;
                delete channelVerifiedBy[childChannel];
            }

            delete verifiedViaChannelRecords[_targetChannel];
            delete verifiedChannelCount[_targetChannel];
            channels[_targetChannel].isChannelVerified = 0;

        } else {
            address verifierChannel = channelVerifiedBy[_targetChannel];
            uint256 _totalVerifiedByVerifierChannel = getTotalVerifiedChannels(verifierChannel);
            updateVerifiedChannelRecords(verifierChannel, _targetChannel, _totalVerifiedByVerifierChannel, 2);
            delete channelVerifiedBy[_targetChannel];
            channels[_targetChannel].isChannelVerified = 0;

        }

        emit ChannelVerificationRevoked(_targetChannel, msg.sender);
    }

   /**
     * @notice    The revokeVerificationViaChannelOwners allows the CHANNEL OWNERS to Revoke the Verification of Child Channels that they themselves Verified
     *            Can only be called for those Target Child Channel whose Verification was provided for the Caller of the Function
     *
     * @dev       Can only be called by Channels who were Verified directly by the ADMIN
     *            The _targetChannel must be have been verified by the Channel calling this function.
     *            Delets the Record of _targetChannel from the verifiedViaChannelRecords mapping
     *            Marks _targetChannel as Unverified and Updates the channelVerifiedBy & verifiedChannelCount mapping for the Caller of the function 
     *                                        
     * @param     _targetChannel  Address of the channel whose Verification is to be Revoked
     **/
    function revokeVerificationViaChannelOwners(address _targetChannel)
        external
        onlyChannelVerifiedChannels(_targetChannel)
        onlyAdminVerifiedChannels(msg.sender)
        returns (bool)
    {
        address verifierChannel = channelVerifiedBy[_targetChannel];
        require (verifierChannel == msg.sender, "Caller is not the Verifier of the Target Channel");
        
        uint256 _totalVerifiedByVerifierChannel = getTotalVerifiedChannels(verifierChannel);

        updateVerifiedChannelRecords(verifierChannel, _targetChannel, _totalVerifiedByVerifierChannel, 2);
        delete channelVerifiedBy[_targetChannel];
        channels[_targetChannel].isChannelVerified = 0;
        
        emit ChannelVerificationRevoked(_targetChannel, msg.sender);
    }

   /**
     * @notice   Private Helper function that updates the Verified Channel Records in the  verifiedViaAdminRecords & verifiedViaChannelRecords Mapping
     *           Only Called when a Channel's Verification is Revoked 
     *  
     * @dev      Performs a SWAP and DELETION of the Target Channel from CHANNEL's and ADMIN's record(Array) of Verified Chanenl
     *           Also updates the verifiedChannelCount mapping => The Count of Total verified channels by the Caller of the Function 
     *                             
     * @param    _verifierChannel      Address of the channel who verified the Channel initially (And is now Revoking its Verification)
     * @param     _targetChannel         Address of the channel whose Verification is to be Revoked
     * @param     _totalVerifiedChannel  Total Number of Channels verified by the Verifier(Caller) of the Functions
     * @param     _verifierFlag          A uint value(Flag) to represent if the Caller is ADMIN or a Channel
     **/

    function updateVerifiedChannelRecords(address _verifierChannel, address _targetChannel, uint256 _totalVerifiedChannel, uint8 _verifierFlag) private{
        if(_verifierFlag == 1){

            for(uint256 i; i < _totalVerifiedChannel; i++){
                if(verifiedViaAdminRecords[_verifierChannel][i] != _targetChannel){
                    continue;
                }else{
                    address target = verifiedViaAdminRecords[_verifierChannel][i];
                    verifiedViaAdminRecords[_verifierChannel][i] = verifiedViaAdminRecords[_verifierChannel][_totalVerifiedChannel - 1];
                    verifiedViaAdminRecords[_verifierChannel][_totalVerifiedChannel - 1] = target;
                    delete verifiedViaAdminRecords[_verifierChannel][_totalVerifiedChannel - 1];
                    verifiedChannelCount[_verifierChannel] = verifiedChannelCount[_verifierChannel].sub(1);
                }
            }
        }else{

             for (uint256 i; i < _totalVerifiedChannel; i++) {
                if ( verifiedViaChannelRecords[_verifierChannel][i] != _targetChannel) {
                    continue;

                } else {

                    address target = verifiedViaChannelRecords[_verifierChannel][i];
                    verifiedViaChannelRecords[_verifierChannel][i] = verifiedViaChannelRecords[_verifierChannel][_totalVerifiedChannel - 1];
                    verifiedViaChannelRecords[_verifierChannel][_totalVerifiedChannel - 1] = target;
                    delete verifiedViaChannelRecords[_verifierChannel][_totalVerifiedChannel - 1];
                    verifiedChannelCount[_verifierChannel] = verifiedChannelCount[_verifierChannel].sub(1);
                }
            }
        }
    }

    /* ************** 
    
    => DEPOSIT & WITHDRAWAL of FUNDS<=

    *************** */

    function updateUniswapV2Address(address _newAddress) external onlyAdmin {
        UNISWAP_V2_ROUTER = _newAddress;
    }

    /**
     * @notice  Function is used for Handling the entire procedure of Depositing the Funds
     *
     * @dev     Updates the Relevant state variable during Deposit of DAI
     *          Lends the DAI to AAVE protocol.
     *
     * @param   amount - Amount that is to be deposited
     **/
    function _depositFundsToPool(uint256 amount) private {
        // Got the funds, add it to the channels dai pool
        poolFunds = poolFunds.add(amount);

        // Next swap it via AAVE for aDAI
        // mainnet address, for other addresses: https://docs.aave.com/developers/developing-on-aave/deployed-contract-instances
        ILendingPoolAddressesProvider provider = ILendingPoolAddressesProvider(
            lendingPoolProviderAddress
        );
        ILendingPool lendingPool = ILendingPool(provider.getLendingPool());
        IERC20(daiAddress).approve(provider.getLendingPoolCore(), amount);

        // Deposit to AAVE
        lendingPool.deposit(daiAddress, amount, uint16(REFERRAL_CODE)); // set to 0 in constructor presently
    }

    /**
     * @notice  Withdraw function that allows Users to withdraw their funds from the protocol
     *
     * @dev     Privarte function that is called for Withdrawal of funds for a particular user
     *          Calculates the total Claimable amount and Updates the Relevant State variables
     *          Swaps the aDai to Push and transfers the PUSH Tokens back to the User
     *
     * @param   ratio -ratio of the Total Amount to be transferred to the Caller
     **/
    function _withdrawFundsFromPool(uint256 ratio) private nonReentrant {
        uint256 totalBalanceWithProfit = IERC20(aDaiAddress).balanceOf(
            address(this)
        );

        uint256 totalProfit = totalBalanceWithProfit.sub(poolFunds);
        uint256 userAmount = totalProfit.mul(ratio);

        // adjust poolFunds first
        uint256 userAmountAdjusted = userAmount.div(ADJUST_FOR_FLOAT);
        poolFunds = poolFunds.sub(userAmountAdjusted);

        // Add to interest claimed
        usersInterestClaimed[msg.sender] = usersInterestClaimed[msg.sender].add(
            userAmountAdjusted
        );

        // Finally SWAP aDAI to PUSH, and TRANSFER TO USER
        swapAndTransferaDaiToPUSH(msg.sender, userAmountAdjusted);
        // Emit Event
        emit InterestClaimed(msg.sender, userAmountAdjusted);
    }

    // TBD - Significance of this function is not very clear
    function withdrawEthFunds() external onlyAdmin {
        uint256 bal = address(this).balance;

        payable(admin).transfer(bal);

        emit Withdrawal(msg.sender, daiAddress, bal);
    }

    /**
     * @notice Swaps aDai to PUSH Tokens and Transfers to the USER Address
     *
     * @param _user address of the user that will recieve the PUSH Tokens
     * @param _userAmount the amount of aDai to be swapped and transferred
     **/
    function swapAndTransferaDaiToPUSH(address _user, uint256 _userAmount)
        internal
        returns (bool)
    {
        IERC20(aDaiAddress).approve(UNISWAP_V2_ROUTER, _userAmount);

        address[] memory path;
        path[0] = aDaiAddress;
        path[1] = PUSH_TOKEN_ADDRESS;

        IUniswapV2Router(UNISWAP_V2_ROUTER).swapExactTokensForTokens(
            _userAmount,
            1,
            path,
            _user,
            block.timestamp
        );
        return true;
    }

    /* ************** 
    
    => FAIR SHARE RATIO CALCULATIONS <=

    *************** */

    /*
     * @notice  Helps keeping trakc of the FAIR Share Details whenever a specific Channel Action occur
     * @dev     Updates some of the imperative Fair Share Data based whenever a paricular channel action is performed.
     *          Takes into consideration 3 major Channel Actions, i.e., Channel Creation, Channel Removal or Channel Deactivation/Reactivation.
     *
     * @param _action                 The type of Channel action for which the Fair Share is being adjusted
     * @param _channelWeight          Weight of the channel on which the Action is being performed.
     * @param _groupFairShareCount    Fair share count
     * @param _groupNormalizedWeight  Normalized weight value
     * @param _groupHistoricalZ       The Historical Constant - Z
     * @param _groupLastUpdate        Holds the block number of the last update.
     */
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
