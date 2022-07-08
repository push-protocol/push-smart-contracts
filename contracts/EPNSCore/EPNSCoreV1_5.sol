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

import "./EPNSCoreStorageV1_5.sol";
import "./EPNSCoreStorageV2.sol";
import "../interfaces/IPUSH.sol";
import "../interfaces/IADai.sol";
import "../interfaces/ILendingPool.sol";
import "../interfaces/IUniswapV2Router.sol";
import "../interfaces/IEPNSCommV1.sol";
import "../interfaces/ILendingPoolAddressesProvider.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract EPNSCoreV1_5 is Initializable, EPNSCoreStorageV1_5, Pausable, EPNSCoreStorageV2{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /* ***************
        EVENTS
     *************** */
    event UpdateChannel(address indexed channel, bytes identity);
    event RewardsClaimed(address indexed user, uint256 rewardAmount);
    event ChannelVerified(address indexed channel, address indexed verifier);
    event ChannelVerificationRevoked(
        address indexed channel,
        address indexed revoker
    );

    event DeactivateChannel(
        address indexed channel,
        uint256 indexed amountRefunded
    );
    event ReactivateChannel(
        address indexed channel,
        uint256 indexed amountDeposited
    );
    event ChannelBlocked(address indexed channel);
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
    event AddSubGraph(address indexed channel, bytes _subGraphData);
    event TimeBoundChannelDestroyed(
        address indexed channel,
        uint256 indexed amountRefunded
    );

    /* **************
        MODIFIERS
    ***************/
    modifier onlyPushChannelAdmin() {
        require(
            msg.sender == pushChannelAdmin,
            "EPNSCoreV1::onlyPushChannelAdmin: Caller not pushChannelAdmin"
        );
        _;
    }

    modifier onlyGovernance() {
        require(
            msg.sender == governance,
            "EPNSCoreV1::onlyGovernance: Caller not Governance"
        );
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
            "EPNSCoreV1::onlyActivatedChannels: Channel Deactivated, Blocked or Does Not Exist"
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
                (msg.sender == pushChannelAdmin && _channel == address(0x0))),
            "EPNSCoreV1::onlyChannelOwner: Channel not Exists or Invalid Channel Owner"
        );
        _;
    }

    modifier onlyUserAllowedChannelType(ChannelType _channelType) {
        require(
            (_channelType == ChannelType.InterestBearingOpen ||
                _channelType == ChannelType.InterestBearingMutual ||
                _channelType == ChannelType.TimeBound ||
                _channelType == ChannelType.TokenGaited),
            "EPNSCoreV1::onlyUserAllowedChannelType: Channel Type Invalid"
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
        pushChannelAdmin = _pushChannelAdmin;
        governance = _pushChannelAdmin; // Will be changed on-Chain governance Address later
        daiAddress = _daiAddress;
        aDaiAddress = _aDaiAddress;
        WETH_ADDRESS = _wethAddress;
        REFERRAL_CODE = _referralCode;
        PUSH_TOKEN_ADDRESS = _pushTokenAddress;
        UNISWAP_V2_ROUTER = _uniswapRouterAddress;
        lendingPoolProviderAddress = _lendingPoolProviderAddress;

        CHANNEL_DEACTIVATION_FEES = 10 ether; // 10 PUSH  out of total deposited PUSH s is charged for Deactivating a Channel
        ADD_CHANNEL_MIN_POOL_CONTRIBUTION = 50 ether; // 50 PUSH  or above to create the channel
        ADD_CHANNEL_MIN_FEES = 50 ether; // can never be below ADD_CHANNEL_MIN_POOL_CONTRIBUTION

        ADJUST_FOR_FLOAT = 10**7;
        groupLastUpdate = block.number;
        groupNormalizedWeight = ADJUST_FOR_FLOAT; // Always Starts with 1 * ADJUST FOR FLOAT

        // Create Channel
        success = true;
    }

    /* ***************

    SETTER FUNCTIONS

    *************** */
    function addSubGraph(bytes calldata _subGraphData)
        external
        onlyActivatedChannels(msg.sender)
    {
        emit AddSubGraph(msg.sender, _subGraphData);
    }

    function updateWETHAddress(address _newAddress)
        external
        onlyPushChannelAdmin
    {
        WETH_ADDRESS = _newAddress;
    }

    function updateUniswapRouterAddress(address _newAddress)
        external
        onlyPushChannelAdmin
    {
        UNISWAP_V2_ROUTER = _newAddress;
    }

    function setEpnsCommunicatorAddress(address _commAddress)
        external
        onlyPushChannelAdmin
    {
        epnsCommunicator = _commAddress;
    }

    function setGovernanceAddress(address _governanceAddress)
        external
        onlyPushChannelAdmin
    {
        governance = _governanceAddress;
    }

    function setMigrationComplete() external onlyPushChannelAdmin {
        isMigrationComplete = true;
    }

    function setChannelDeactivationFees(uint256 _newFees)
        external
        onlyGovernance
    {
        require(
            _newFees > 0,
            "EPNSCoreV1::setChannelDeactivationFees: Channel Deactivation Fees must be greater than ZERO"
        );
        CHANNEL_DEACTIVATION_FEES = _newFees;
    }

    function pauseContract() external onlyGovernance {
        _pause();
    }

    function unPauseContract() external onlyGovernance {
        _unpause();
    }

    function getTotalHolderShare() public view returns (uint256) {
        return POOL_FUNDS;
    }

    /**
     * @notice Allows to set the Minimum amount threshold for Creating Channels
     *
     * @dev    Minimum required amount can never be below ADD_CHANNEL_MIN_POOL_CONTRIBUTION
     *
     * @param _newFees new minimum fees required for Channel Creation
     **/
    function setMinChannelCreationFees(uint256 _newFees)
        external
        onlyGovernance
    {
        require(
            _newFees >= ADD_CHANNEL_MIN_POOL_CONTRIBUTION,
            "EPNSCoreV1::setMinChannelCreationFees: Fees should be greater than ADD_CHANNEL_MIN_POOL_CONTRIBUTION"
        );
        ADD_CHANNEL_MIN_FEES = _newFees;
    }

    function transferPushChannelAdminControl(address _newAdmin)
        public
        onlyPushChannelAdmin
    {
        require(
            _newAdmin != address(0),
            "EPNSCoreV1::transferPushChannelAdminControl: Invalid Address"
        );
        require(
            _newAdmin != pushChannelAdmin,
            "EPNSCoreV1::transferPushChannelAdminControl: Admin address is same"
        );
        pushChannelAdmin = _newAdmin;
    }

    /* ***********************************

        CHANNEL RELATED FUNCTIONALTIES

    **************************************/
    function getChannelState(address _channel)
        external
        view
        returns (uint256 state)
    {
        state = channels[_channel].channelState;
    }

    /**
     * @notice Allows Channel Owner to update their Channel's Details like Description, Name, Logo, etc by passing in a new identity bytes hash
     *
     * @dev  Only accessible when contract is NOT Paused
     *       Only accessible when Caller is the Channel Owner itself
     *       If Channel Owner is updating the Channel Meta for the first time:
     *       Required Fees => 50 PUSH tokens
     *
     *       If Channel Owner is updating the Channel Meta for the N time:
     *       Required Fees => (50 * N) PUSH Tokens
     *
     *       Updates the channelUpdateCounter
     *       Updates the channelUpdateBlock
     *       Records the Block Number of the Block at which the Channel is being updated
     *       Emits an event with the new identity for the respective Channel Address
     *
     * @param _channel     address of the Channel
     * @param _newIdentity bytes Value for the New Identity of the Channel
     * @param _amount amount of PUSH Token required for updating channel details.
     **/
    function updateChannelMeta(
        address _channel,
        bytes calldata _newIdentity,
        uint256 _amount
    ) external whenNotPaused onlyChannelOwner(_channel) {
        uint256 updateCounter = channelUpdateCounter[_channel].add(1);
        uint256 requiredFees = ADD_CHANNEL_MIN_FEES.mul(updateCounter);

        require(
            _amount >= requiredFees,
            "EPNSCoreV2::updateChannelMeta: Insufficient Deposit Amount"
        );

        POOL_FUNDS += _amount;
        channelUpdateCounter[_channel] += 1;
        channels[_channel].channelUpdateBlock = block.number;

        IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(
            _channel,
            address(this),
            _amount
        );
        emit UpdateChannel(_channel, _newIdentity);
    }

    /**
     * @notice An external function that allows users to Create their Own Channels by depositing a valid amount of PUSH
     * @dev    Only allows users to Create One Channel for a specific address.
     *         Only allows a Valid Channel Type to be assigned for the Channel Being created.
     *         Validates and Transfers the amount of PUSH  from the Channel Creator to the EPNS Core Contract
     *         Updates the POOL_FUNDS state and Creates a Channel for the caller
     *
     * @param  _channelType the type of the Channel Being created
     * @param  _identity the bytes value of the identity of the Channel
     * @param  _amount Amount of PUSH  to be deposited before Creating the Channel
     * @param  _channelExpiryTime the expiry time for time bound channels
     **/
    function createChannelWithPUSH(
        ChannelType _channelType,
        bytes calldata _identity,
        uint256 _amount,
        uint256 _channelExpiryTime
    )
        external
        whenNotPaused
        onlyInactiveChannels(msg.sender)
        onlyUserAllowedChannelType(_channelType)
    {
        require(
            _amount >= ADD_CHANNEL_MIN_FEES,
            "EPNSCoreV1::_createChannelWithPUSH: Insufficient Deposit Amount"
        );
        emit AddChannel(msg.sender, _channelType, _identity);

        POOL_FUNDS = POOL_FUNDS.add(_amount);
        IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );
        _createChannel(msg.sender, _channelType, _amount, _channelExpiryTime);
    }

    /**
     * @notice Migration function that allows pushChannelAdmin to migrate the previous Channel Data to this protocol
     *
     * @dev   can only be Called by the pushChannelAdmin
     *        Channel's identity is simply emitted out
     *        Channel's on-Chain details are stored by calling the "_crateChannel" function
     *        PUSH  required for Channel Creation will be PAID by pushChannelAdmin
     *
     * @param _startIndex       starting Index for the LOOP
     * @param _endIndex         Last Index for the LOOP
     * @param _channelAddresses array of address of the Channel
     * @param _channelTypeList   array of type of the Channel being created
     * @param _identityList     array of list of identity Bytes
     * @param _amountList       array of amount of PUSH  to be depositeds
     * @param  _channelExpiryTime the expiry time for time bound channels
     **/
    function migrateChannelData(
        uint256 _startIndex,
        uint256 _endIndex,
        address[] calldata _channelAddresses,
        ChannelType[] calldata _channelTypeList,
        bytes[] calldata _identityList,
        uint256[] calldata _amountList,
        uint256[] calldata _channelExpiryTime
    ) external onlyPushChannelAdmin returns (bool) {
        require(
            !isMigrationComplete,
            "EPNSCoreV1::migrateChannelData: Migration is already done"
        );

        require(
            (_channelAddresses.length == _channelTypeList.length) &&
                (_channelAddresses.length == _identityList.length) &&
                (_channelAddresses.length == _amountList.length) &&
                (_channelAddresses.length == _channelExpiryTime.length),
            "EPNSCoreV1::migrateChannelData: Unequal Arrays passed as Argument"
        );

        for (uint256 i = _startIndex; i < _endIndex; i++) {
            if (channels[_channelAddresses[i]].channelState != 0) {
                continue;
            } else {
                IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(
                    msg.sender,
                    address(this),
                    _amountList[i]
                );
                emit AddChannel(
                    _channelAddresses[i],
                    _channelTypeList[i],
                    _identityList[i]
                );
                _createChannel(
                    _channelAddresses[i],
                    _channelTypeList[i],
                    _amountList[i],
                    _channelExpiryTime[i]
                );
            }
        }
        return true;
    }

    /**
     * @notice Base Channel Creation Function that allows users to Create Their own Channels and Stores crucial details about the Channel being created
     * @dev    -Initializes the Channel Struct
     *         -Subscribes the Channel's Owner to Imperative EPNS Channels as well as their Own Channels
     * @param _channel         address of the channel being Created
     * @param _channelType     The type of the Channel
     * @param _amountDeposited The total amount being deposited while Channel Creation
     * @param _channelExpiryTime the expiry time for time bound channels
     **/
    function _createChannel(
        address _channel,
        ChannelType _channelType,
        uint256 _amountDeposited,
        uint256 _channelExpiryTime
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
        channelById[channelsCount] = _channel;
        channelsCount = channelsCount.add(1);

        if (_channelType == ChannelType.TimeBound) {
            require(
                _channelExpiryTime > block.timestamp,
                "EPNSCoreV1::createChannel: Invalid channelExpiryTime"
            );
            channels[_channel].expiryTime = _channelExpiryTime;
        }

        // Subscribe them to their own channel as well
        address _epnsCommunicator = epnsCommunicator;
        if (_channel != pushChannelAdmin) {
            IEPNSCommV1(_epnsCommunicator).subscribeViaCore(_channel, _channel);
        }

        // All Channels are subscribed to EPNS Alerter as well, unless it's the EPNS Alerter channel iteself
        if (_channel != address(0x0)) {
            IEPNSCommV1(_epnsCommunicator).subscribeViaCore(
                address(0x0),
                _channel
            );
            IEPNSCommV1(_epnsCommunicator).subscribeViaCore(
                _channel,
                pushChannelAdmin
            );
        }
    }

    /**
     * @notice Function that allows Channel Owners to Destroy their Time-Bound Channels
     * @dev    - Can only be called the owner of the Channel or by the EPNS Governance/Admin.
     *         - EPNS Governance/Admin can only destory a channel after 14 Days of its expriation timestamp.
     *         - Can only be called if the Channel is of type - TimeBound
     *         - Can only be called after the Channel Expiry time is up.
     *         - If Channel Owner destroys the channel after expiration, he/she recieves back 40 PUSH Token back.
     *         - If Channel is destroyed by EPNS Governance/Admin, push tokens remain within  the contract. No refunds for channel owner.
     *         - Deletes the Channel completely
     *         - It transfers back 40 PUSH Tokens back to the USER.
     **/

    function destroyTimeBoundChannel(address _channelAddress)
        external
        whenNotPaused
        onlyActivatedChannels(_channelAddress)
    {
        Channel storage channelData = channels[_channelAddress];

        require(
            channelData.channelType == ChannelType.TimeBound,
            "EPNSCoreV1::destroyTimeBoundChannel: Channel is not TIME BOUND"
        );
        require(
            (msg.sender == _channelAddress &&
                channelData.expiryTime < block.timestamp) ||
                (msg.sender == pushChannelAdmin &&
                    channelData.expiryTime.add(14 days) < block.timestamp),
            "EPNSCoreV1::destroyTimeBoundChannel: Invalid Caller or Channel has not Expired Yet"
        );
        uint256 totalRefundableAmount;
        if (msg.sender != pushChannelAdmin) {
            totalRefundableAmount = channelData.poolContribution.sub(
                CHANNEL_DEACTIVATION_FEES
            );
            POOL_FUNDS = POOL_FUNDS.sub(totalRefundableAmount);
            IERC20(PUSH_TOKEN_ADDRESS).safeTransfer(
                msg.sender,
                totalRefundableAmount
            );
        }
        // Unsubscribing from imperative Channels
        address _epnsCommunicator = epnsCommunicator;
        IEPNSCommV1(_epnsCommunicator).unSubscribeViaCore(
            address(0x0),
            _channelAddress
        );
        IEPNSCommV1(_epnsCommunicator).unSubscribeViaCore(
            _channelAddress,
            _channelAddress
        );
        IEPNSCommV1(_epnsCommunicator).unSubscribeViaCore(
            _channelAddress,
            pushChannelAdmin
        );
        // Decrement Channel Count and Delete Channel Completely
        channelsCount = channelsCount.sub(1);
        delete channels[msg.sender];

        emit TimeBoundChannelDestroyed(msg.sender, totalRefundableAmount);
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
    function createChannelSettings(
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
     *         - Calculates the Total PUSH  Deposited by Channel Owner while Channel Creation.
     *         - Deducts CHANNEL_DEACTIVATION_FEES from the total Deposited PUSH  and Transfers back the remaining amount of PUSH  in the form of PUSH tokens.
     *         - Updates the State of the Channel(channelState) and the New Channel Weight in the Channel's Struct
     *         - In case, the Channel Owner wishes to reactivate his/her channel, they need to Deposit at least the Minimum required PUSH  while reactivating.
     **/

    function deactivateChannel()
        external
        whenNotPaused
        onlyActivatedChannels(msg.sender)
    {
        Channel storage channelData = channels[msg.sender];

        uint256 totalAmountDeposited = channelData.poolContribution;

        uint256 totalRefundableAmount = totalAmountDeposited.sub(
            CHANNEL_DEACTIVATION_FEES
        );

        uint256 _newChannelWeight = CHANNEL_DEACTIVATION_FEES
            .mul(ADJUST_FOR_FLOAT)
            .div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

        channelData.channelState = 2;
        POOL_FUNDS = POOL_FUNDS.sub(totalRefundableAmount);
        channelData.channelWeight = _newChannelWeight;
        channelData.poolContribution = CHANNEL_DEACTIVATION_FEES;

        IERC20(PUSH_TOKEN_ADDRESS).safeTransfer(
            msg.sender,
            totalRefundableAmount
        );

        emit DeactivateChannel(msg.sender, totalRefundableAmount);
    }

    /**
     * @notice Allows Channel Owner to Reactivate his/her Channel again.
     * @dev    - Function can only be called by previously Deactivated Channels
     *         - Channel Owner must Depost at least minimum amount of PUSH  to reactivate his/her channel.
     *         - Calculation of the new Channel Weight is performed and the FairShare is Readjusted once again with relevant details
     *         - Updates the State of the Channel(channelState) in the Channel's Struct.
     * @param _amount Amount of Dai to be deposited
     **/

    function reactivateChannel(uint256 _amount)
        external
        whenNotPaused
        onlyDeactivatedChannels(msg.sender)
    {
        uint _add_channel_min_pool_contribution = ADD_CHANNEL_MIN_POOL_CONTRIBUTION;
        require(
            _amount >= _add_channel_min_pool_contribution,
            "EPNSCoreV1::reactivateChannel: Insufficient Funds Passed for Channel Reactivation"
        );

        IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        uint256 newChannelPoolContribution = _amount.add(
            CHANNEL_DEACTIVATION_FEES
        );
        uint256 _channelWeight = newChannelPoolContribution
            .mul(ADJUST_FOR_FLOAT)
            .div(_add_channel_min_pool_contribution);

        POOL_FUNDS = POOL_FUNDS.add(_amount);
        channels[msg.sender].channelState = 1;
        channels[msg.sender].poolContribution += _amount;
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
     *         - Emit 'ChannelBlocked' Event
     * @param _channelAddress Address of the Channel to be blocked
     **/

    function blockChannel(address _channelAddress)
        external
        whenNotPaused
        onlyPushChannelAdmin
        onlyUnblockedChannels(_channelAddress)
    {
        Channel storage channelData = channels[_channelAddress];
        uint _channel_deactivation_fees = CHANNEL_DEACTIVATION_FEES;

        uint256 _newChannelWeight = _channel_deactivation_fees
            .mul(ADJUST_FOR_FLOAT)
            .div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

        channelsCount = channelsCount.sub(1);

        channelData.channelState = 3;
        channelData.channelWeight = _newChannelWeight;
        channelData.channelUpdateBlock = block.number;
        channelData.poolContribution = _channel_deactivation_fees;

        emit ChannelBlocked(_channelAddress);
    }

    /* **************
    => CHANNEL VERIFICATION FUNCTIONALTIES <=
    *************** */

    /**
     * @notice    Function is designed to tell if a channel is verified or not
     * @dev       Get if channel is verified or not
     * @param    _channel Address of the channel to be Verified
     * @return   verificationStatus  Returns 0 for not verified, 1 for primary verification, 2 for secondary verification
     **/
    function getChannelVerfication(address _channel)
        public
        view
        returns (uint8 verificationStatus)
    {
        address verifiedBy = channels[_channel].verifiedBy;
        bool logicComplete = false;

        // Check if it's primary verification
        if (
            verifiedBy == pushChannelAdmin ||
            _channel == address(0x0) ||
            _channel == pushChannelAdmin
        ) {
            // primary verification, mark and exit
            verificationStatus = 1;
        } else {
            // can be secondary verification or not verified, dig deeper
            while (!logicComplete) {
                if (verifiedBy == address(0x0)) {
                    verificationStatus = 0;
                    logicComplete = true;
                } else if (verifiedBy == pushChannelAdmin) {
                    verificationStatus = 2;
                    logicComplete = true;
                } else {
                    // Upper drill exists, go up
                    verifiedBy = channels[verifiedBy].verifiedBy;
                }
            }
        }
    }

    function batchVerification(
        uint256 _startIndex,
        uint256 _endIndex,
        address[] calldata _channelList
    ) external onlyPushChannelAdmin returns (bool) {
        for (uint256 i = _startIndex; i < _endIndex; i++) {
            verifyChannel(_channelList[i]);
        }
        return true;
    }

    function batchRevokeVerification(
        uint256 _startIndex,
        uint256 _endIndex,
        address[] calldata _channelList
    ) external onlyPushChannelAdmin returns (bool) {
        for (uint256 i = _startIndex; i < _endIndex; i++) {
            unverifyChannel(_channelList[i]);
        }
        return true;
    }

    /**
     * @notice    Function is designed to verify a channel
     * @dev       Channel will be verified by primary or secondary verification, will fail or upgrade if already verified
     * @param    _channel Address of the channel to be Verified
     **/
    function verifyChannel(address _channel)
        public
        onlyActivatedChannels(_channel)
    {
        // Check if caller is verified first
        uint8 callerVerified = getChannelVerfication(msg.sender);
        require(
            callerVerified > 0,
            "EPNSCoreV1::verifyChannel: Caller is not verified"
        );

        // Check if channel is verified
        uint8 channelVerified = getChannelVerfication(_channel);
        require(
            channelVerified == 0  || msg.sender == pushChannelAdmin,
            "EPNSCoreV1::verifyChannel: Channel already verified"
        );

        // Verify channel
        channels[_channel].verifiedBy = msg.sender;

        // Emit event
        emit ChannelVerified(_channel, msg.sender);
    }

    /**
     * @notice    Function is designed to unverify a channel
     * @dev       Channel who verified this channel or Push Channel Admin can only revoke
     * @param    _channel Address of the channel to be unverified
     **/
    function unverifyChannel(address _channel) public {
        require(
            channels[_channel].verifiedBy == msg.sender ||
                msg.sender == pushChannelAdmin,
            "EPNSCoreV1::unverifyChannel: Only channel who verified this or Push Channel Admin can revoke"
        );

        // Unverify channel
        channels[_channel].verifiedBy = address(0x0);

        // Emit Event
        emit ChannelVerificationRevoked(_channel, msg.sender);
    }

    /* **************

    => CLAIM REWARDS & FAIR SHARE RATIO CALCULATIONS <=

    *************** */
    /**
     * @notice  Allows the user to claim their rewards in Push Tokens
     * @dev     Gets the User's Holder weight, totalSupply & start Block from the PUSH token contract
     *          Calculates the totalHolder weight w.r.t to the current block number
     *          Gets the ratio of token holder -> ( Individual User's weight / totalWeight)
     *          Resets the Holder's Weight on the PUSH Contract by setting it to the current block.number
     *          The PUSH token is then transferred to the USER as the interest.
     *
     * @return  success Returns true if rewards are claimed successfully.
     **/
    function claimRewards() external returns (bool success) {
        address _user = msg.sender;
        address _push_token_address = PUSH_TOKEN_ADDRESS;
        uint256 totalClaimableRewards = getRewardValue(_user);

        require(
            totalClaimableRewards > 0,
            "EPNSCoreV2::claimRewards: No Claimable Rewards at the Moment"
        );

        // Reset the User's Weight and Transfer the Tokens
        POOL_FUNDS = POOL_FUNDS.sub(totalClaimableRewards);
        IPUSH(_push_token_address).resetHolderWeight(_user);
        usersRewardsClaimed[_user] = usersRewardsClaimed[_user].add(
            totalClaimableRewards
        );

        // Transfer PUSH to the user
        IERC20(_push_token_address).safeTransfer(_user, totalClaimableRewards);

        emit RewardsClaimed(msg.sender, totalClaimableRewards);
        success = true;
    }

    function getRewardValue(address _user)
        public
        view
        returns (uint256 rewardValue)
    {
        // Reading necessary PUSH details
        address _push_token_address = PUSH_TOKEN_ADDRESS;
        uint _adjust_for_float = ADJUST_FOR_FLOAT;

        uint256 pushStartBlock = IPUSH(_push_token_address).born();
        uint256 pushTotalSupply = IPUSH(_push_token_address).totalSupply();
        uint256 userHolderWeight = IPUSH(_push_token_address).returnHolderUnits(
            _user,
            block.number
        );

        // Calculating total holder weight at the current Block Number
        uint256 blockGap = block.number.sub(pushStartBlock);
        uint256 totalHolderWeight = pushTotalSupply.mul(blockGap);

        //Calculating individual User's Ratio
        uint256 userRatio = userHolderWeight.mul(_adjust_for_float).div(
            totalHolderWeight
        );

        //Calculating Claimable rewards for individual user(msg.sender)
        uint256 totalShare = getTotalHolderShare();
        rewardValue = totalShare.mul(userRatio).div(_adjust_for_float);
    }

    function getChainId() internal pure returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }
}
