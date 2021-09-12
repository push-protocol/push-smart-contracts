pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;

/**
 * EPNS Core is the main protocol that deals with the imperative
 * features and functionalities like Channel Creation, pushChannelAdmin etc.
 *
 * This protocol will be specifically deployed on Ethereum Blockchain while the Communicator
 * protocols can be deployed on Multiple Chains.
 * The EPNS Core is more inclined towards the storing and handling the Channel related
 * Functionalties.
 **/

import "./interfaces/IPUSH.sol";
import "./interfaces/IADai.sol";
import "./interfaces/ILendingPool.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IEPNSCommV1.sol";
import "./interfaces/ILendingPoolAddressesProvider.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// import "hardhat/console.sol";

contract EPNSCoreV1 is Initializable, ReentrancyGuard, Ownable {
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
        // @notice Denotes the Channel Type
        ChannelType channelType;

        /** @notice Symbolizes Channel's State:
         * 0 -> INACTIVE,
         * 1 -> ACTIVATED
         * 2 -> DeActivated By Channel Owner,
         * 3 -> BLOCKED by pushChannelAdmin/Governance
        **/
        uint8 channelState;

        /** @notice Symbolizes Channel's Verification Status:
         * 0 -> UnVerified Channels,
         * 1 -> Verified by pushChannelAdmin,
         * 2 -> Verified by other Channel Owners
        **/
        uint8 isChannelVerified;

        //@ notice Total Amount of Dai deposited during Channel Creation
        uint256 poolContribution;

        // @notice Represents the Historical Constant
        uint256 channelHistoricalZ;

        // @notice Represents the FS Count
        uint256 channelFairShareCount;

        // @notice The last update block number, used to calculate fair share
        uint256 channelLastUpdate;

        // @notice Helps in defining when channel started for pool and profit calculation
        uint256 channelStartBlock;

        // @notice Helps in outlining when channel was updated
        uint256 channelUpdateBlock;

        // @notice The individual weight to be applied as per pool contribution
        uint256 channelWeight;
    }

    /** MAPPINGS **/
    mapping(address => Channel) public channels;
    mapping(uint256 => address) public mapAddressChannels;
    mapping(address => string) public channelNotifSettings;
    mapping(address => uint256) public usersInterestClaimed;

    /** CHANNEL VERIFICATION MAPPINGS **/
    // @notice Keeps track of Channel Being Verified => The VERIFIER CHANNEL
    mapping(address => address) public channelVerifiedBy;

    // @notice Keeps track of Verifier Channel Address => Total Number of Channels it Verified
    mapping(address => uint256) public verifiedChannelCount;

    // @notice Array of All Channels verified by pushChannelAdmin
    mapping(address => address[]) public verifiedViaAdminRecords;

    // @notice Array of All Channels verified by CHANNEL OWNERS
    mapping(address => address[]) public verifiedViaChannelRecords;

    /** STATE VARIABLES **/
    string public constant name = "EPNS CORE V1";
    bool oneTimeCheck;
    bool public isMigrationComplete;

    address public pushChannelAdmin;
    address public governance;
    address public daiAddress;
    address public aDaiAddress;
    address public WETH_ADDRESS;
    address public epnsCommunicator;
    address public UNISWAP_V2_ROUTER;
    address public PUSH_TOKEN_ADDRESS;
    address public lendingPoolProviderAddress;

    uint256 public REFERRAL_CODE;
    uint256 ADJUST_FOR_FLOAT;
    uint256 public channelsCount;

    //  @notice Helper Variables for FSRatio Calculation | GROUPS = CHANNELS
    uint256 public groupNormalizedWeight;
    uint256 public groupHistoricalZ;
    uint256 public groupLastUpdate;
    uint256 public groupFairShareCount;

    // @notice Necessary variables for Keeping track of Funds and Fees
    uint256 public poolFunds;
    uint256 public protocolFeePool;
    uint256 public CHANNEL_DEACTIVATION_FEES;
    uint256 public ADD_CHANNEL_MIN_POOL_CONTRIBUTION;

    /** EVENTS **/
    event UpdateChannel(address indexed channel, bytes identity);
    event Withdrawal(address indexed to, address token, uint256 amount);
    event InterestClaimed(address indexed user, uint256 indexed interestAmount);
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
    event ChannelBlocked(
        address indexed channel
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
    modifier onlyPushChannelAdmin() {
        require(msg.sender == pushChannelAdmin, "EPNSCoreV1::onlyPushChannelAdmin: Caller not pushChannelAdmin");
        _;
    }

    modifier onlyGovernance() {
        require(msg.sender == pushChannelAdmin, "EPNSCoreV1::onlyGovernance: Caller not Governance");
        _;
    }

    modifier onlyInactiveChannels(address _channel) {
        require(
            channels[_channel].channelState == 0,
            "EPNSCoreV1::onlyInactiveChannels: Channel already Activated"
        );
        _;
    }
    modifier onlyActivatedChannels(address _channel) {
        require(
            channels[_channel].channelState == 1,
            "EPNSCoreV1::onlyActivatedChannels: Channel Deactivated, Blocked or Not Exist"
        );
        _;
    }

    modifier onlyDeactivatedChannels(address _channel) {
        require(
            channels[_channel].channelState == 2,
            "EPNSCoreV1::onlyDeactivatedChannels: Channel is not Deactivated Yet"
        );
        _;
    }

    modifier onlyUnblockedChannels(address _channel) {
        require(
            ((channels[_channel].channelState != 3) &&
              (channels[_channel].channelState != 0)),
            "EPNSCoreV1::onlyUnblockedChannels: Channel is BLOCKED Already or Not Activated Yet"
        );
        _;
    }

    modifier onlyChannelOwner(address _channel) {
        require(
            ((channels[_channel].channelState == 1 && msg.sender == _channel) ||
                (msg.sender == pushChannelAdmin &&
                    _channel == 0x0000000000000000000000000000000000000000)),
            "EPNSCoreV1::onlyChannelOwner: Channel not Exists or Invalid Channel Owner"
        );
        _;
    }

    modifier onlyUserAllowedChannelType(ChannelType _channelType) {
        require(
            (_channelType == ChannelType.InterestBearingOpen ||
                _channelType == ChannelType.InterestBearingMutual),
            "EPNSCoreV1::onlyUserAllowedChannelType: Channel Type Invalid"
        );

        _;
    }

    modifier onlyUnverifiedChannels(address _channel) {
        require(
            channels[_channel].isChannelVerified == 0,
            "EPNSCoreV1::onlyUnverifiedChannels: Channel Already Verified"
        );
        _;
    }

    modifier onlyAdminVerifiedChannels(address _channel) {
        require(
            channels[_channel].isChannelVerified == 1,
            "EPNSCoreV1::onlyAdminVerifiedChannels: Caller NOT Verified By pushChannelAdmin or pushChannelAdmin Itself"
        );
        _;
    }

    modifier onlyChannelVerifiedChannels(address _channel) {
        require(
            channels[_channel].isChannelVerified == 2,
            "EPNSCoreV1::onlyChannelVerifiedChannels: Channel is Either Verified By pushChannelAdmin or UNVERIFIED YET"
        );
        _;
    }

    modifier onlyVerifiedChannels(address _channel) {
        require(
            channels[_channel].isChannelVerified == 1 ||
                channels[_channel].isChannelVerified == 2,
            "EPNSCoreV1::onlyVerifiedChannels: Channel is Not Verified Yet"
        );
        _;
    }

    /* ***************
        INITIALIZER

    *************** */

    function initialize(
        address _pushChannelAdmin,
        address _pushTokenAddress,
        address _wethAddress,
        address _uniswapRouterAddress,
        address _lendingPoolProviderAddress,
        address _daiAddress,
        address _aDaiAddress,
        uint256 _referralCode
    ) public initializer returns (bool success) {
        // setup addresses
        pushChannelAdmin = _pushChannelAdmin; // multisig/timelock, also controls the proxy
        governance = pushChannelAdmin;
        daiAddress = _daiAddress;
        aDaiAddress = _aDaiAddress;
        WETH_ADDRESS = _wethAddress;
        REFERRAL_CODE = _referralCode;
        PUSH_TOKEN_ADDRESS = _pushTokenAddress;
        UNISWAP_V2_ROUTER = _uniswapRouterAddress;
        lendingPoolProviderAddress = _lendingPoolProviderAddress;

        CHANNEL_DEACTIVATION_FEES = 10 ether; // 10 DAI out of total deposited DAIs is charged for Deactivating a Channel
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION = 50 ether; // 50 DAI or above to create the channel

        ADJUST_FOR_FLOAT = 10**7;
        groupLastUpdate = block.number;
        groupNormalizedWeight = ADJUST_FOR_FLOAT; // Always Starts with 1 * ADJUST FOR FLOAT

        // Create Channel
        success = true;
    }

    /* ***************
        SETTER FUNCTIONS

    *************** */
    function updateWETHAddress(address _newAddress) external onlyPushChannelAdmin {
        WETH_ADDRESS = _newAddress;
    }

    function updateUniswapRouterAddress(address _newAddress) external onlyPushChannelAdmin {
        UNISWAP_V2_ROUTER = _newAddress;
    }

    function setEpnsCommunicatorAddress(address _commAddress)
        external
        onlyPushChannelAdmin
    {
        epnsCommunicator = _commAddress;
    }

    function setGovernanceAddress(address _governanceAddress) external onlyPushChannelAdmin{
      governance = _governanceAddress;
    }

    function setMigrationComplete() external onlyPushChannelAdmin{
        isMigrationComplete = true;
    }

    function setChannelDeactivationFees(uint256 _newFees) external onlyGovernance {
        require(
            _newFees > 0,
            "EPNSCoreV1::setChannelDeactivationFees: Channel Deactivation Fees must be greater than ZERO"
        );
        CHANNEL_DEACTIVATION_FEES = _newFees;
    }

// TO BE DISCUSSED
    // function setMinChannelCreationFees(uint256 _newFees) external onlyPushChannelAdmin {
    //     require(
    //         _newFees > 0,
    //         "Channel MIN Creation Fees must be greater than ZERO"
    //     );
    //     ADD_CHANNEL_MIN_POOL_CONTRIBUTION = _newFees;
    // }


    function transferPushChannelAdminControl(address _newAdmin) public onlyPushChannelAdmin {
        require(_newAdmin != address(0), "EPNSCoreV1::transferPushChannelAdminControl: Invalid Address");
        require(_newAdmin != pushChannelAdmin, "EPNSCoreV1::transferPushChannelAdminControl: Admin address is same");
        pushChannelAdmin = _newAdmin;
    }

    /* ***********************************
        CHANNEL RELATED FUNCTIONALTIES

    **************************************/
    function getChannelState(address _channel) external view returns(uint256 state) {
        state = channels[_channel].channelState;
    }
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
        channels[_channel].channelUpdateBlock = block.number;
    }

    function createChannelForPushChannelAdmin() external onlyPushChannelAdmin() {
        require (!oneTimeCheck, "EPNSCoreV1::migrateChannelData: Unequal Arrays passed as Argument Function can only be called Once");

        // Add EPNS Channels
        // First is for all users
        // Second is all channel alerter, amount deposited for both is 0
        // to save gas, emit both the events out
        // identity = payloadtype + payloadhash

        // EPNS ALL USERS

        _createChannel(pushChannelAdmin, ChannelType.ProtocolNonInterest, 0); // should the owner of the contract be the channel? should it be pushChannelAdmin in this case?
         emit AddChannel(
            pushChannelAdmin,
            ChannelType.ProtocolNonInterest,
            "1+QmSbRT16JVF922yAB26YxWFD6DmGsnSHm8VBrGUQnXTS74"
        );

        // EPNS ALERTER CHANNEL
        _createChannel(
            0x0000000000000000000000000000000000000000,
            ChannelType.ProtocolNonInterest,
            0
        );
        emit AddChannel(
        0x0000000000000000000000000000000000000000,
        ChannelType.ProtocolNonInterest,
        "1+QmTCKYL2HRbwD6nGNvFLe4wPvDNuaYGr6RiVeCvWjVpn5s"
        );

        oneTimeCheck = true;
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
            "EPNSCoreV1::_createChannelWithFees: Insufficient Funds"
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
     * @notice Migration function that allows pushChannelAdmin to migrate the previous Channel Data to this protocol
     *
     * @dev   can only be Called by the pushChannelAdmin
     *        DAI required for Channel Creation will be PAID by pushChannelAdmin
     *
     * @param _startIndex       starting Index for the LOOP
     * @param _endIndex         Last Index for the LOOP
     * @param _channelAddresses array of address of the Channel
     * @param _channelTypeLst   array of type of the Channel being created
     * @param _amountList       array of amount of DAI to be depositeds
    **/
    function migrateChannelData(
        uint256 _startIndex,
        uint256 _endIndex,
        address[] calldata _channelAddresses,
        ChannelType[] calldata _channelTypeLst,
        bytes[] calldata _identityList,
        uint256[] calldata _amountList
    ) external onlyPushChannelAdmin returns (bool) {
        require(
            !isMigrationComplete,
            "EPNSCoreV1::migrateChannelData: Migration is already done"
        );

        require(
            (_channelAddresses.length == _channelTypeLst.length) &&
            (_channelAddresses.length == _channelAddresses.length),
            "EPNSCoreV1::migrateChannelData: Unequal Arrays passed as Argument"
        );

        for (uint256 i = _startIndex; i < _endIndex; i++) {
                if(channels[_channelAddresses[i]].channelState != 0){
                    continue;
            }else{
                IERC20(daiAddress).safeTransferFrom(pushChannelAdmin, address(this), _amountList[i]);
                _depositFundsToPool(_amountList[i]);
                emit AddChannel(_channelAddresses[i], _channelTypeLst[i], _identityList[i]);
                _createChannel(_channelAddresses[i], _channelTypeLst[i], _amountList[i]);
            }
        }
        return true;
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
        if (_channel != pushChannelAdmin) {
            IEPNSCommV1(epnsCommunicator).subscribeViaCore(
                _channel,
                _channel
            );
        }

        // All Channels are subscribed to EPNS Alerter as well, unless it's the EPNS Alerter channel iteself
        if (_channel != 0x0000000000000000000000000000000000000000) {
            IEPNSCommV1(epnsCommunicator).subscribeViaCore(
                0x0000000000000000000000000000000000000000,
                _channel
            );
            IEPNSCommV1(epnsCommunicator).subscribeViaCore(
                _channel,
                pushChannelAdmin
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
     *
     *  @param _notifOptions - Total Notification options provided by the Channel Owner
     *  @param _notifSettings- Deliminated String of Notification Settings
     *  @param _notifDescription - Description of each Notification that depicts the Purpose of that Notification
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

    function deactivateChannel() external onlyActivatedChannels(msg.sender) {
        Channel memory channelData = channels[msg.sender];

        uint256 totalAmountDeposited = channelData.poolContribution;
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

        channelData.channelState = 2;
        poolFunds = poolFunds.sub(totalRefundableAmount);
        channelData.channelWeight = _newChannelWeight;

        channels[msg.sender] = channelData;
        swapAndTransferPUSH(msg.sender, totalRefundableAmount);
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

    function reactivateChannel(uint256 _amount)
        external
        onlyDeactivatedChannels(msg.sender)
    {
        require(
            _amount >= ADD_CHANNEL_MIN_POOL_CONTRIBUTION,
            "EPNSCoreV1::reactivateChannel: Insufficient Funds Passed for Channel Reactivation"
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

        channels[msg.sender].channelState = 1;
        channels[msg.sender].channelWeight = _channelWeight;

        emit ReactivateChannel(msg.sender, _amount);
    }

    /**
     * @notice ALlows the pushChannelAdmin to Block any particular channel Completely.
     *
     * @dev    - Can only be called by pushChannelAdmin
     *         - Can only be Called for Activated Channels
     *         - Can only Be Called for NON-BLOCKED Channels
     *
     *         - Updates channel's state to BLOCKED ('3')
     *         - Updates Channel's Pool Contribution to ZERO
     *         - Updates Channel's Weight to ZERO
     *         - Increases the Protocol Fee Pool
     *         - Decreases the Channel Count
     *         - Readjusts the FS Ratio
     *         - Emit 'ChannelBlocked' Event
     * @param _channelAddress Address of the Channel to be blocked
     **/

     function blockChannel(address _channelAddress)
     external
     onlyPushChannelAdmin()
     onlyUnblockedChannels(_channelAddress){
       Channel memory channelData = channels[_channelAddress];

       uint256 totalAmountDeposited = channelData.poolContribution;
       uint256 totalRefundableAmount = totalAmountDeposited.sub(
           CHANNEL_DEACTIVATION_FEES
       );

       uint256 _newChannelWeight = CHANNEL_DEACTIVATION_FEES
           .mul(ADJUST_FOR_FLOAT)
           .div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

       channelsCount = channelsCount.sub(1);

       channelData.channelState = 3;
       channelData.channelWeight = _newChannelWeight;
       channelData.channelUpdateBlock = block.number;
       channelData.poolContribution = CHANNEL_DEACTIVATION_FEES;
       protocolFeePool = protocolFeePool.add(totalRefundableAmount);
       (
           groupFairShareCount,
           groupNormalizedWeight,
           groupHistoricalZ,
           groupLastUpdate
       ) = _readjustFairShareOfChannels(
           ChannelAction.ChannelRemoved,
           _newChannelWeight,
           groupFairShareCount,
           groupNormalizedWeight,
           groupHistoricalZ,
           groupLastUpdate
       );

       channels[_channelAddress] = channelData;
       emit ChannelBlocked(_channelAddress);
     }

    /* **************

    => CHANNEL VERIFICATION FUNCTIONALTIES <=

    *************** */

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

        if (_verifier == pushChannelAdmin) {
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
     * @notice    Function is designed specifically for the pushChannelAdmin to verify any particular Channel
     * @dev       Can only be Called by the pushChannelAdmin
     *            Calls the base function, i.e., verifyChannel() to execute the Main Verification Procedure
     * @param    _channel  Address of the channel to be Verified
     **/

    function verifyChannelViapushChannelAdmin(address _channel)
        external
        onlyPushChannelAdmin
        returns (bool)
    {
        _verifyChannel(_channel, pushChannelAdmin, 1);
        return true;
    }

    /**
     * @notice    Function is designed specifically for the Verified CHANNEL Owners to verify any particular Channel
     * @dev       Can only be Called by the Channel Owners who themselves have been verified by the pushChannelAdmin first
     *            Calls the base function, i.e., verifyChannel() to execute the Main Verification Procedure
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
     * @notice    Base function that allows pushChannelAdmin or Channel Owners to Verify other Channels
     *
     * @dev       Can only be Called for UnVerified Channels
     *            Checks if the Caller of this function is an pushChannelAdmin or other Verified Channel Owners and Proceeds Accordingly
     *            If Caller is pushChannelAdmin:
     *                                a. Marks Channel Verification Status as '1'.
     *                                b. Updates the verifiedViaAdminRecords Mapping
     *                                c. Emits Relevant Events
     *            If Caller is Verified Channel Owners:
     *                                a. Marks Channel Verification Status as '2'.
     *                                b. Updates the verifiedViaChannelRecords Mapping
     *                                c. Updates the channelToChannelVerificationRecords mapping
     *                                d. Emits Relevant Events
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
     * @notice    The revokeVerificationViaAdmin allows the pushChannelAdmin of the Contract to Revoke any Specific Channel's Verified Tag
     *            Can be called for any Target Channel that has been verified either by pushChannelAdmin or other Channels
     *
     * @dev       Can only be Called for Verified Channels
     *            Can only be Called by the pushChannelAdmin of the contract
     *            Involves 2 Main CASES:
     *                                   a. Either the Target Channel is CHILD Verified Channel (Channel that is NOT verified by pushChannelAdmin directly) or,
     *                                   b. The Target Channel is a PARENT VERIFIED Channel (Channel that is verified by pushChannelAdmin)
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
     * @param     _targetChannel  Address of the channel whose Verification is to be Revoked
     **/

    function revokeVerificationViaAdmin(address _targetChannel)
        external
        onlyPushChannelAdmin()
        onlyVerifiedChannels(_targetChannel)
        returns (bool)
    {
        Channel memory channelDetails = channels[_targetChannel];

        if (channelDetails.isChannelVerified == 1) {
            uint256 _totalVerifiedBypushChannelAdmin = getTotalVerifiedChannels(pushChannelAdmin);
            updateVerifiedChannelRecords(pushChannelAdmin, _targetChannel, _totalVerifiedBypushChannelAdmin, 1);

            uint256 _totalChannelsVerified = getTotalVerifiedChannels(_targetChannel);
            if(_totalChannelsVerified > 0){
                for (uint256 i; i < _totalChannelsVerified; i++) {

                address childChannel = verifiedViaChannelRecords[_targetChannel][i];
                channels[childChannel].isChannelVerified = 0;
                delete channelVerifiedBy[childChannel];
                }
                delete verifiedViaChannelRecords[_targetChannel];
                delete verifiedChannelCount[_targetChannel];
            }
            delete channelVerifiedBy[_targetChannel];
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
     * @dev       Can only be called by Channels who were Verified directly by the pushChannelAdmin
     *            The _targetChannel must be have been verified by the Channel calling this function.
     *            Delets the Record of _targetChannel from the verifiedViaChannelRecords mapping
     *            Marks _targetChannel as Unverified and Updates the channelVerifiedBy & verifiedChannelCount mapping for the Caller of the function
     * @param     _targetChannel  Address of the channel whose Verification is to be Revoked
     **/
    function revokeVerificationViaChannelOwners(address _targetChannel)
        external
        onlyAdminVerifiedChannels(msg.sender)
        onlyChannelVerifiedChannels(_targetChannel)
        returns (bool)
    {
        address verifierChannel = channelVerifiedBy[_targetChannel];
        require (verifierChannel == msg.sender, "EPNSCoreV1::revokeVerificationViaChannelOwners: Caller not Verifier of the Channel");

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
     * @dev      Performs a SWAP and DELETION of the Target Channel from CHANNEL's and pushChannelAdmin's record(Array) of Verified Chanenl
     *           Also updates the verifiedChannelCount mapping => The Count of Total verified channels by the Caller of the Function
     *
     * @param    _verifierChannel      Address of the channel who verified the Channel initially (And is now Revoking its Verification)
     * @param     _targetChannel         Address of the channel whose Verification is to be Revoked
     * @param     _totalVerifiedChannel  Total Number of Channels verified by the Verifier(Caller) of the Functions
     * @param     _verifierFlag          A uint value(Flag) to represent if the Caller is pushChannelAdmin or a Channel
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
    /**
     * @notice  Function is used for Handling the entire procedure of Depositing the Funds
     *
     * @dev     Updates the Relevant state variable during Deposit of DAI
     *          Lends the DAI to AAVE protocol.
     * @param   amount - Amount that is to be deposited
     **/
    function _depositFundsToPool(uint256 amount) private {
        // Got the funds, add it to the channels dai pool
        poolFunds = poolFunds.add(amount);

        ILendingPoolAddressesProvider provider = ILendingPoolAddressesProvider(
            lendingPoolProviderAddress
        );
        ILendingPool lendingPool = ILendingPool(provider.getLendingPool());
        IERC20(daiAddress).approve(provider.getLendingPoolCore(), amount);

        // Deposit to AAVE
        lendingPool.deposit(daiAddress, amount, uint16(REFERRAL_CODE)); // set to 0 in constructor presently
    }

    /**
     * @notice Swaps aDai to PUSH Tokens and Transfers to the USER Address
     *
     * @param _user address of the user that will recieve the PUSH Tokens
     * @param _userAmount the amount of aDai to be swapped and transferred
     **/
    function swapAndTransferPUSH(address _user, uint256 _userAmount)
        internal
        returns (bool)
    {
        swapADaiForDai(_userAmount);
        IERC20(daiAddress).approve(UNISWAP_V2_ROUTER, _userAmount);

        address[] memory path = new address[](3);
        path[0] = daiAddress;
        path[1] = WETH_ADDRESS;
        path[2] = PUSH_TOKEN_ADDRESS;

        IUniswapV2Router(UNISWAP_V2_ROUTER).swapExactTokensForTokens(
            _userAmount,
            1,
            path,
            _user,
            block.timestamp
        );
        return true;
    }

    function swapADaiForDai(uint256 _amount) private{
      ILendingPoolAddressesProvider provider = ILendingPoolAddressesProvider(
        lendingPoolProviderAddress
      );
      ILendingPool lendingPool = ILendingPool(provider.getLendingPool());
      IERC20(aDaiAddress).approve(provider.getLendingPoolCore(), _amount);

      IADai(aDaiAddress).redeem(_amount);
    }

    /**
     * @notice Function to claim Rewards generated for indivudual users
     * NOTE   The EPNSCore Protocol must be approved as a Delegtate for Resetting the HOLDER's WEIGHT on PUSH Token Contract.
     *
     * @dev - Gets the User's Holder weight from the PUSH token contract
     *      - Gets the totalSupply and Start Block of PUSH Token
     *      - Calculates the totalHolder weight w.r.t to the current block number
     *      - Gets the ratio of token holder by dividing individual User's weight tp totalWeight (also adjusts for the FLOAT)
     *      - Gets the Total ADAI Interest accumulated for the protocol
     *      - Calculates the amount the User should recieve considering the user's ratio calculated before
     *      - The claim function resets the Holder's Weight on the PUSH Contract by setting it to the current block.number
     *      - The Claimable ADAI Amount amount is SWapped for PUSH Tokens.
     *      - The PUSH token is then transferred to the USER as the interest.
    **/
    function claimInterest() external returns(bool success){
      address _user = msg.sender;
      // Reading necessary PUSH details
      uint pushStartBlock = IPUSH(PUSH_TOKEN_ADDRESS).born();
      uint pushTotalSupply = IPUSH(PUSH_TOKEN_ADDRESS).totalSupply();
      uint256 userHolderWeight = IPUSH(PUSH_TOKEN_ADDRESS).returnHolderUnits(_user, block.number);
      // Calculating total holder weight at the current Block Number
      uint blockGap = block.number.sub(pushStartBlock);
      uint totalHolderWeight = pushTotalSupply.mul(blockGap);
      //Calculating individual User's Ratio
      uint userRatio = userHolderWeight.mul(ADJUST_FOR_FLOAT).div(totalHolderWeight);
      // Calculating aDai Interest Generated and CLaimable Amount
      uint256 aDaiBalanceWithInterest = IADai(aDaiAddress).balanceOf(address(this));
      uint256 totalADAIInterest = aDaiBalanceWithInterest.sub(poolFunds);
      uint256 totalClaimableRewards = totalADAIInterest.mul(userRatio).div(ADJUST_FOR_FLOAT).div(100);
      require(totalClaimableRewards > 0, "EPNSCoreV1::claimInterest: No Claimable Rewards at the Moment");
      // Reset the User's Weight and Transfer the Tokens
      IPUSH(PUSH_TOKEN_ADDRESS).resetHolderWeight(_user);
      usersInterestClaimed[_user] = usersInterestClaimed[_user].add(totalClaimableRewards);
      swapAndTransferPUSH(_user, totalClaimableRewards);

      emit InterestClaimed(msg.sender, totalClaimableRewards);
      success = true;
    }

    /* **************

    => FAIR SHARE RATIO CALCULATIONS <=

    *************** */
    /**
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
     **/
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
            revert("EPNSCoreV1::_readjustFairShareOfChannels: Invalid Channel Action");
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
