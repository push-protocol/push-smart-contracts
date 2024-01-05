pragma solidity ^0.8.20;

/**
 * EPNS Core is the main protocol that deals with the imperative
 * features and functionalities like Channel Creation, pushChannelAdmin etc.
 *
 * This protocol will be specifically deployed on Ethereum Blockchain while the Communicator
 * protocols can be deployed on Multiple Chains.
 * The EPNS Core is more inclined towards the storing and handling the Channel related
 * Functionalties.
 *
 */
import "./PushCoreStorageV1_5.sol";
import "./PushCoreStorageV2.sol";
import "../interfaces/IPUSH.sol";
import "../interfaces/uniswap/IUniswapV2Router.sol";
import {IPushCoreV2} from "../interfaces/IPushCoreV2.sol";
import {IPushCommV2} from "../interfaces/IPushCommV2.sol";
import { Errors } from "../libraries/Errors.sol";
import { CoreTypes } from "../libraries/DataTypes.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract PushCoreV2_Temp is Initializable, PushCoreStorageV1_5, PausableUpgradeable, PushCoreStorageV2, IPushCoreV2 {
    using SafeERC20 for IERC20;

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
    )
        public
        initializer
        returns (bool success)
    {
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

        FEE_AMOUNT = 10 ether; // PUSH Amount that will be charged as Protocol Pool Fees
        MIN_POOL_CONTRIBUTION = 50 ether; // Channel's poolContribution should never go below MIN_POOL_CONTRIBUTION
        ADD_CHANNEL_MIN_FEES = 50 ether; // can never be below MIN_POOL_CONTRIBUTION

        ADJUST_FOR_FLOAT = 10 ** 7;
        groupLastUpdate = block.number;
        groupNormalizedWeight = ADJUST_FOR_FLOAT; // Always Starts with 1 * ADJUST FOR FLOAT

        // Create Channel
        success = true;
    }

    /* ***************

    SETTER & HELPER FUNCTIONS

    *************** */
    function onlyPushChannelAdmin() private view {
        if (msg.sender != pushChannelAdmin) {
            revert Errors.CallerNotAdmin();
        }
    }

    function onlyGovernance() private view {
        if (msg.sender != governance) {
            revert Errors.CallerNotAdmin();
        }
    }

    function onlyActivatedChannels(address _channel) private view {
        if (channels[_channel].channelState != 1) {
            revert Errors.Core_InvalidChannel();
        }
    }

    function onlyChannelOwner(address _channel) private view {
        if (
            (
                (channels[_channel].channelState != 1 || msg.sender != _channel)
                    || (msg.sender != pushChannelAdmin && _channel == address(0x0))
            )
        ) {
            revert Errors.UnauthorizedCaller(msg.sender);
        }
    }

    function addSubGraph(bytes calldata _subGraphData) external {
        onlyActivatedChannels(msg.sender);
        emit AddSubGraph(msg.sender, _subGraphData);
    }

    function setEpnsCommunicatorAddress(address _commAddress) external {
        onlyPushChannelAdmin();
        epnsCommunicator = _commAddress;
    }

    function setGovernanceAddress(address _governanceAddress) external {
        onlyPushChannelAdmin();
        governance = _governanceAddress;
    }

    function setFeeAmount(uint256 _newFees) external {
        onlyGovernance();
        if (_newFees > ADD_CHANNEL_MIN_FEES) {
            revert Errors.InvalidArg_MoreThanExpected(ADD_CHANNEL_MIN_FEES, _newFees);
        }
        FEE_AMOUNT = _newFees;
    }

    function setMinPoolContribution(uint256 _newAmount) external {
        onlyGovernance();
        if (_newAmount <= 0) {
            revert Errors.InvalidArg_LessThanExpected(0, _newAmount);
        }
        MIN_POOL_CONTRIBUTION = _newAmount;
    }

    function pauseContract() external {
        onlyGovernance();
        _pause();
    }

    function unPauseContract() external {
        onlyGovernance();
        _unpause();
    }
    /**
     * @notice Allows to set the Minimum amount threshold for Creating Channels
     *
     * @dev    Minimum required amount can never be below MIN_POOL_CONTRIBUTION
     *
     * @param _newFees new minimum fees required for Channel Creation
     *
     */
    function setMinChannelCreationFees(uint256 _newFees) external {
        onlyGovernance();
        if (_newFees < MIN_POOL_CONTRIBUTION) {
            revert Errors.InvalidArg_LessThanExpected(MIN_POOL_CONTRIBUTION, _newFees);
        }
        ADD_CHANNEL_MIN_FEES = _newFees;
    }

    function transferPushChannelAdminControl(address _newAdmin) external {
        onlyPushChannelAdmin();
        if (_newAdmin == address(0) || _newAdmin == pushChannelAdmin) {
            revert Errors.InvalidArgument_WrongAddress(_newAdmin);
        }
        pushChannelAdmin = _newAdmin;
    }

    /* ***********************************

        CHANNEL RELATED FUNCTIONALTIES

    **************************************/
    /**
     * @notice Allows Channel Owner to update their Channel's Details like Description, Name, Logo, etc by passing in a
     * new identity bytes hash
     *
     * @dev  Only accessible when contract is NOT Paused
     *       Only accessible when Caller is the Channel Owner itself
     *       If Channel Owner is updating the Channel Meta for the first time:
     *       Required Fees => 50 PUSH tokens
     *
     *       If Channel Owner is updating the Channel Meta for the N time:
     *       Required Fees => (50 * N) PUSH Tokens
     *
     *       Total fees goes to PROTOCOL_POOL_FEES
     *       Updates the channelUpdateCounter
     *       Updates the channelUpdateBlock
     *       Records the Block Number of the Block at which the Channel is being updated
     *       Emits an event with the new identity for the respective Channel Address
     *
     * @param _channel     address of the Channel
     * @param _newIdentity bytes Value for the New Identity of the Channel
     * @param _amount amount of PUSH Token required for updating channel details.
     *
     */
    function updateChannelMeta(address _channel, bytes calldata _newIdentity, uint256 _amount) external whenNotPaused {
        onlyChannelOwner(_channel);
        uint256 updateCounter = channelUpdateCounter[_channel] + 1;
        uint256 requiredFees = ADD_CHANNEL_MIN_FEES * updateCounter;

        if (_amount < requiredFees) {
            revert Errors.InvalidArg_LessThanExpected(requiredFees, _amount);
        }

        PROTOCOL_POOL_FEES = PROTOCOL_POOL_FEES + _amount;
        channelUpdateCounter[_channel] = updateCounter;
        channels[_channel].channelUpdateBlock = block.number;

        IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(_channel, address(this), _amount);
        emit UpdateChannel(_channel, _newIdentity, _amount);
    }

    /**
     * @notice An external function that allows users to Create their Own Channels by depositing a valid amount of PUSH
     * @dev    Only allows users to Create One Channel for a specific address.
     *         Only allows a Valid Channel Type to be assigned for the Channel Being created.
     *         Validates and Transfers the amount of PUSH  from the Channel Creator to the EPNS Core Contract
     *
     * @param  _channelType the type of the Channel Being created
     * @param  _identity the bytes value of the identity of the Channel
     * @param  _amount Amount of PUSH  to be deposited before Creating the Channel
     * @param  _channelExpiryTime the expiry time for time bound channels
     *
     */
    function createChannelWithPUSH(
        CoreTypes.ChannelType _channelType,
        bytes calldata _identity,
        uint256 _amount,
        uint256 _channelExpiryTime
    )
        external
        whenNotPaused
    {
        if (_amount < ADD_CHANNEL_MIN_FEES) {
            revert Errors.InvalidArg_LessThanExpected(ADD_CHANNEL_MIN_FEES, _amount);
        }
        if (channels[msg.sender].channelState != 0) {
            revert Errors.Core_InvalidChannel();
        }
        if (
            _channelType != CoreTypes.ChannelType.InterestBearingOpen && _channelType != CoreTypes.ChannelType.InterestBearingMutual
                && _channelType != CoreTypes.ChannelType.TimeBound && _channelType != CoreTypes.ChannelType.TokenGaited
        ) {
            revert Errors.Core_InvalidChannelType();
        }

        emit AddChannel(msg.sender, _channelType, _identity);

        IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(msg.sender, address(this), _amount);
        _createChannel(msg.sender, _channelType, _amount, _channelExpiryTime);
    }

    /**
     * @notice Base Channel Creation Function that allows users to Create Their own Channels and Stores crucial details
     * about the Channel being created
     * @dev    -Initializes the Channel Struct
     *         -Subscribes the Channel's Owner to Imperative EPNS Channels as well as their Own Channels
     *         - Updates the CHANNEL_POOL_FUNDS and PROTOCOL_POOL_FEES in the contract.
     *
     * @param _channel         address of the channel being Created
     * @param _channelType     The type of the Channel
     * @param _amountDeposited The total amount being deposited while Channel Creation
     * @param _channelExpiryTime the expiry time for time bound channels
     *
     */
    function _createChannel(
        address _channel,
        CoreTypes.ChannelType _channelType,
        uint256 _amountDeposited,
        uint256 _channelExpiryTime
    )
        private
    {
        uint256 poolFeeAmount = FEE_AMOUNT;
        uint256 poolFundAmount = _amountDeposited - poolFeeAmount;
        //store funds in pool_funds & pool_fees
        CHANNEL_POOL_FUNDS = CHANNEL_POOL_FUNDS + poolFundAmount;
        PROTOCOL_POOL_FEES = PROTOCOL_POOL_FEES + poolFeeAmount;

        // Calculate channel weight
        uint256 _channelWeight = (poolFundAmount * ADJUST_FOR_FLOAT) / MIN_POOL_CONTRIBUTION;
        // Next create the channel and mark user as channellized
        channels[_channel].channelState = 1;
        channels[_channel].poolContribution = poolFundAmount;
        channels[_channel].channelType = _channelType;
        channels[_channel].channelStartBlock = block.number;
        channels[_channel].channelUpdateBlock = block.number;
        channels[_channel].channelWeight = _channelWeight;
        // Add to map of addresses and increment channel count
        uint256 _channelsCount = channelsCount;
        channelsCount = _channelsCount + 1;

        if (_channelType == CoreTypes.ChannelType.TimeBound) {
            if (_channelExpiryTime <= block.timestamp) {
                revert Errors.Core_InvalidExpiryTime();
            }
            channels[_channel].expiryTime = _channelExpiryTime;
        }

        // Subscribe them to their own channel as well
        address _epnsCommunicator = epnsCommunicator;
        if (_channel != pushChannelAdmin) {
            IPushCommV2(_epnsCommunicator).subscribeViaCore(_channel, _channel);
        }

        // All Channels are subscribed to EPNS Alerter as well, unless it's the EPNS Alerter channel iteself
        if (_channel != address(0x0)) {
            IPushCommV2(_epnsCommunicator).subscribeViaCore(address(0x0), _channel);
            IPushCommV2(_epnsCommunicator).subscribeViaCore(_channel, pushChannelAdmin);
        }
    }

    /**
     * @notice Function that allows Channel Owners to Destroy their Time-Bound Channels
     * @dev    - Can only be called the owner of the Channel or by the EPNS Governance/Admin.
     *         - EPNS Governance/Admin can only destory a channel after 14 Days of its expriation timestamp.
     *         - Can only be called if the Channel is of type - TimeBound
     *         - Can only be called after the Channel Expiry time is up.
     *         - If Channel Owner destroys the channel after expiration, he/she recieves back refundable amount &
     * CHANNEL_POOL_FUNDS decreases.
     *         - If Channel is destroyed by EPNS Governance/Admin, No refunds for channel owner. Refundable Push tokens
     * are added to PROTOCOL_POOL_FEES.
     *         - Deletes the Channel completely
     *         - It transfers back refundable tokenAmount back to the USER.
     *
     */

    function destroyTimeBoundChannel(address _channelAddress) external whenNotPaused {
        onlyActivatedChannels(_channelAddress);
        CoreTypes.Channel memory channelData = channels[_channelAddress];

        if (channelData.channelType != CoreTypes.ChannelType.TimeBound) {
            revert Errors.Core_InvalidChannelType();
        }
        if (
            (msg.sender != _channelAddress || channelData.expiryTime >= block.timestamp)
                && (msg.sender != pushChannelAdmin || channelData.expiryTime + 14 days >= block.timestamp)
        ) {
            revert Errors.UnauthorizedCaller(msg.sender);
        }
        uint256 totalRefundableAmount = channelData.poolContribution;

        if (msg.sender != pushChannelAdmin) {
            CHANNEL_POOL_FUNDS = CHANNEL_POOL_FUNDS - totalRefundableAmount;
            IERC20(PUSH_TOKEN_ADDRESS).safeTransfer(msg.sender, totalRefundableAmount);
        } else {
            CHANNEL_POOL_FUNDS = CHANNEL_POOL_FUNDS - totalRefundableAmount;
            PROTOCOL_POOL_FEES = PROTOCOL_POOL_FEES + totalRefundableAmount;
        }
        // Unsubscribing from imperative Channels
        address _epnsCommunicator = epnsCommunicator;
        IPushCommV2(_epnsCommunicator).unSubscribeViaCore(address(0x0), _channelAddress);
        IPushCommV2(_epnsCommunicator).unSubscribeViaCore(_channelAddress, _channelAddress);
        IPushCommV2(_epnsCommunicator).unSubscribeViaCore(_channelAddress, pushChannelAdmin);
        // Decrement Channel Count and Delete Channel Completely
        channelsCount = channelsCount - 1;
        delete channels[_channelAddress];

        emit TimeBoundChannelDestroyed(msg.sender, totalRefundableAmount);
    }

    /**
     * @notice - Deliminated Notification Settings string contains -> Total Notif Options + Notification Settings
     * For instance: 5+1-0+2-50-20-100+1-1+2-78-10-150
     *  5 -> Total Notification Options provided by a Channel owner
     *
     *  For Boolean Type Notif Options
     *  1-0 -> 1 stands for BOOLEAN type - 0 stands for Default Boolean Type for that Notifcation(set by Channel Owner),
     * In this case FALSE.
     *  1-1 stands for BOOLEAN type - 1 stands for Default Boolean Type for that Notifcation(set by Channel Owner), In
     * this case TRUE.
     *
     *  For SLIDER TYPE Notif Options
     *   2-50-20-100 -> 2 stands for SLIDER TYPE - 50 stands for Default Value for that Option - 20 is the Start Range
     * of that SLIDER - 100 is the END Range of that SLIDER Option
     *  2-78-10-150 -> 2 stands for SLIDER TYPE - 78 stands for Default Value for that Option - 10 is the Start Range of
     * that SLIDER - 150 is the END Range of that SLIDER Option
     *
     *  @param _notifOptions - Total Notification options provided by the Channel Owner
     *  @param _notifSettings- Deliminated String of Notification Settings
     *  @param _notifDescription - Description of each Notification that depicts the Purpose of that Notification
     *  @param _amountDeposited - Fees required for setting up channel notification settings
     *
     */
    function createChannelSettings(
        uint256 _notifOptions,
        string calldata _notifSettings,
        string calldata _notifDescription,
        uint256 _amountDeposited
    )
        external
    {
        onlyActivatedChannels(msg.sender);
        if (_amountDeposited < ADD_CHANNEL_MIN_FEES) {
            revert Errors.InvalidArg_LessThanExpected(ADD_CHANNEL_MIN_FEES, _amountDeposited);
        }
        string memory notifSetting = string(abi.encodePacked(Strings.toString(_notifOptions), "+", _notifSettings));
        channelNotifSettings[msg.sender] = notifSetting;

        PROTOCOL_POOL_FEES = PROTOCOL_POOL_FEES + _amountDeposited;
        IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(msg.sender, address(this), _amountDeposited);
        emit ChannelNotifcationSettingsAdded(msg.sender, _notifOptions, notifSetting, _notifDescription);
    }

    /**
     * @notice Allows Channel Owner to Deactivate his/her Channel for any period of Time. Channels Deactivated can be
     * Activated again.
     * @dev    - Function can only be Called by Already Activated Channels
     *         - Calculates the totalRefundableAmount for the Channel Owner.
     *         - The function deducts MIN_POOL_CONTRIBUTION from refundAble amount to ensure that channel's weight &
     * poolContribution never becomes ZERO.
     *         - Updates the State of the Channel(channelState) and the New Channel Weight in the Channel's Struct
     *         - In case, the Channel Owner wishes to reactivate his/her channel, they need to Deposit at least the
     * Minimum required PUSH  while reactivating.
     *
     */

    function deactivateChannel() external whenNotPaused {
        onlyActivatedChannels(msg.sender);
        CoreTypes.Channel storage channelData = channels[msg.sender];

        uint256 minPoolContribution = MIN_POOL_CONTRIBUTION;
        uint256 totalRefundableAmount = channelData.poolContribution - minPoolContribution;

        uint256 _newChannelWeight = (minPoolContribution * ADJUST_FOR_FLOAT) / minPoolContribution;

        channelData.channelState = 2;
        CHANNEL_POOL_FUNDS = CHANNEL_POOL_FUNDS - totalRefundableAmount;
        channelData.channelWeight = _newChannelWeight;
        channelData.poolContribution = minPoolContribution;

        IERC20(PUSH_TOKEN_ADDRESS).safeTransfer(msg.sender, totalRefundableAmount);

        emit DeactivateChannel(msg.sender, totalRefundableAmount);
    }

    /**
     * @notice Allows Channel Owner to Reactivate his/her Channel again.
     * @dev    - Function can only be called by previously Deactivated Channels
     *         - Channel Owner must Depost at least minimum amount of PUSH  to reactivate his/her channel.
     *         - Deposited PUSH amount is distributed between CHANNEL_POOL_FUNDS and PROTOCOL_POOL_FEES
     *         - Calculation of the new Channel Weight and poolContribution is performed and stored
     *         - Updates the State of the Channel(channelState) in the Channel's Struct.
     * @param _amount Amount of PUSH to be deposited
     *
     */

    function reactivateChannel(uint256 _amount) external whenNotPaused {
        if (_amount < ADD_CHANNEL_MIN_FEES) {
            revert Errors.InvalidArg_LessThanExpected(ADD_CHANNEL_MIN_FEES, _amount);
        }

        if (channels[msg.sender].channelState != 2) {
            revert Errors.Core_InvalidChannel();
        }

        IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(msg.sender, address(this), _amount);
        uint256 poolFeeAmount = FEE_AMOUNT;
        uint256 poolFundAmount = _amount - poolFeeAmount;
        //store funds in pool_funds & pool_fees
        CHANNEL_POOL_FUNDS = CHANNEL_POOL_FUNDS + poolFundAmount;
        PROTOCOL_POOL_FEES = PROTOCOL_POOL_FEES + poolFeeAmount;

        CoreTypes.Channel storage channelData = channels[msg.sender];

        uint256 _newPoolContribution = channelData.poolContribution + poolFundAmount;
        uint256 _newChannelWeight = (_newPoolContribution * ADJUST_FOR_FLOAT) / MIN_POOL_CONTRIBUTION;

        channelData.channelState = 1;
        channelData.poolContribution = _newPoolContribution;
        channelData.channelWeight = _newChannelWeight;

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
     *         - Decreases the Channel Count
     *         - Since there is no refund, the channel's poolContribution is added to PROTOCOL_POOL_FEES and Removed
     * from CHANNEL_POOL_FUNDS
     *         - Emit 'ChannelBlocked' Event
     * @param _channelAddress Address of the Channel to be blocked
     *
     */

    function blockChannel(address _channelAddress) external whenNotPaused {
        onlyPushChannelAdmin();
        if (((channels[_channelAddress].channelState == 3) || (channels[_channelAddress].channelState == 0))) {
            revert Errors.Core_InvalidChannel();
        }
        uint256 minPoolContribution = MIN_POOL_CONTRIBUTION;
        CoreTypes.Channel storage channelData = channels[_channelAddress];
        // add channel's currentPoolContribution to PoolFees - (no refunds if Channel is blocked)
        // Decrease CHANNEL_POOL_FUNDS by currentPoolContribution
        uint256 currentPoolContribution = channelData.poolContribution - minPoolContribution;
        CHANNEL_POOL_FUNDS = CHANNEL_POOL_FUNDS - currentPoolContribution;
        PROTOCOL_POOL_FEES = PROTOCOL_POOL_FEES + currentPoolContribution;

        uint256 _newChannelWeight = (minPoolContribution * ADJUST_FOR_FLOAT) / minPoolContribution;

        channelsCount = channelsCount - 1;
        channelData.channelState = 3;
        channelData.channelWeight = _newChannelWeight;
        channelData.channelUpdateBlock = block.number;
        channelData.poolContribution = minPoolContribution;

        emit ChannelBlocked(_channelAddress);
    }

    /* **************
    => CHANNEL VERIFICATION FUNCTIONALTIES <=
    *************** */

    /**
     * @notice    Function is designed to tell if a channel is verified or not
     * @dev       Get if channel is verified or not
     * @param    _channel Address of the channel to be Verified
     * @return   verificationStatus  Returns 0 for not verified, 1 for primary verification, 2 for secondary
     * verification
     *
     */
    function getChannelVerfication(address _channel) public view returns (uint8 verificationStatus) {
        address verifiedBy = channels[_channel].verifiedBy;
        bool logicComplete = false;

        // Check if it's primary verification
        if (verifiedBy == pushChannelAdmin || _channel == address(0x0) || _channel == pushChannelAdmin) {
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
    )
        external
        returns (bool)
    {
        onlyPushChannelAdmin();
        for (uint256 i = _startIndex; i < _endIndex; i++) {
            verifyChannel(_channelList[i]);
        }
        return true;
    }

    /**
     * @notice    Function is designed to verify a channel
     * @dev       Channel will be verified by primary or secondary verification, will fail or upgrade if already
     * verified
     * @param    _channel Address of the channel to be Verified
     *
     */
    function verifyChannel(address _channel) public {
        onlyActivatedChannels(_channel);
        // Check if caller is verified first
        uint8 callerVerified = getChannelVerfication(msg.sender);
        if (callerVerified <= 0) {
            revert Errors.UnauthorizedCaller(msg.sender);
        }

        // Check if channel is verified
        uint8 channelVerified = getChannelVerfication(_channel);
        if (channelVerified != 0 || msg.sender != pushChannelAdmin) {
            revert Errors.Core_InvalidChannel();
        }

        // Verify channel
        channels[_channel].verifiedBy = msg.sender;

        // Emit event
        emit ChannelVerified(_channel, msg.sender);
    }

    /**
     * @notice    Function is designed to unverify a channel
     * @dev       Channel who verified this channel or Push Channel Admin can only revoke
     * @param    _channel Address of the channel to be unverified
     *
     */
    function unverifyChannel(address _channel) public {
        if (channels[_channel].verifiedBy != msg.sender || msg.sender != pushChannelAdmin) {
            revert Errors.CallerNotAdmin();
        }

        // Unverify channel
        channels[_channel].verifiedBy = address(0x0);

        // Emit Event
        emit ChannelVerificationRevoked(_channel, msg.sender);
    }

    /**
     * Core-V2: Stake and Claim Functions **
     */
    /**
     * Allows caller to add pool_fees at any given epoch
     *
     */
    function addPoolFees(uint256 _rewardAmount) external {
        IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(msg.sender, address(this), _rewardAmount);
        PROTOCOL_POOL_FEES = PROTOCOL_POOL_FEES + _rewardAmount;
    }

    /**
     * @notice Function to return User's Push Holder weight based on amount being staked & current block number
     *
     */
    function _returnPushTokenWeight(
        address _account,
        uint256 _amount,
        uint256 _atBlock
    )
        internal
        view
        returns (uint256)
    {
        return _amount * (_atBlock - IPUSH(PUSH_TOKEN_ADDRESS).holderWeight(_account));
    }

    /**
     * @notice Returns the epoch ID based on the start and end block numbers passed as input
     *
     */
    function lastEpochRelative(uint256 _from, uint256 _to) public view returns (uint256) {
        if (_to < _from) {
            revert Errors.InvalidArg_LessThanExpected(_from, _to);
        }

        return uint256((_to - _from) / epochDuration + 1);
    }

    /**
     * @notice Calculates and returns the claimable reward amount for a user at a given EPOCH ID.
     * @dev    Formulae for reward calculation:
     *         rewards = ( userStakedWeight at Epoch(n) * avalailable rewards at EPOCH(n) ) / totalStakedWeight at
     * EPOCH(n)
     *
     */
    function calculateEpochRewards(address _user, uint256 _epochId) public view returns (uint256 rewards) {
        rewards = (userFeesInfo[_user].epochToUserStakedWeight[_epochId] * epochRewards[_epochId])
            / epochToTotalStakedWeight[_epochId];
    }

    /**
     * @notice Function to initialize the staking procedure in Core contract
     * @dev    Requires caller to deposit/stake 1 PUSH token to ensure staking pool is never zero.
     *
     */
    function initializeStake() external {
        if (genesisEpoch != 0) {
            revert("Already Initialized");
        }

        genesisEpoch = block.number;
        lastEpochInitialized = genesisEpoch;

        _stake(address(this), 1e18);
    }

    /**
     * @notice Function to allow users to stake in the protocol
     * @dev    Records total Amount staked so far by a particular user
     *         Triggers weight adjustents functions
     * @param  _amount represents amount of tokens to be staked
     *
     */
    function stake(uint256 _amount) external whenNotPaused {
        _stake(msg.sender, _amount);
        emit Staked(msg.sender, _amount);
    }

    function _stake(address _staker, uint256 _amount) private {
        uint256 currentEpoch = lastEpochRelative(genesisEpoch, block.number);
        uint256 blockNumberToConsider = genesisEpoch + (epochDuration * currentEpoch);
        uint256 userWeight = _returnPushTokenWeight(_staker, _amount, blockNumberToConsider);

        IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(msg.sender, address(this), _amount);

        userFeesInfo[_staker].stakedAmount = userFeesInfo[_staker].stakedAmount + _amount;
        userFeesInfo[_staker].lastClaimedBlock =
            userFeesInfo[_staker].lastClaimedBlock == 0 ? genesisEpoch : userFeesInfo[_staker].lastClaimedBlock;
        totalStakedAmount += _amount;
        // Adjust user and total rewards, piggyback method
        _adjustUserAndTotalStake(_staker, userWeight, false);
    }

    /**
     * @notice Function to allow users to Unstake from the protocol
     * @dev    Allows stakers to claim rewards before unstaking their tokens
     *         Triggers weight adjustents functions
     *         Allows users to unstake all amount at once
     *
     */
    function unstake() external whenNotPaused {
        if (block.number <= userFeesInfo[msg.sender].lastStakedBlock + epochDuration) {
            revert Errors.PushStaking_InvalidEpoch_LessThanExpected();
        }
        if (userFeesInfo[msg.sender].stakedAmount <= 0) {
            revert Errors.UnauthorizedCaller(msg.sender);
        }

        harvestAll();
        uint256 stakedAmount = userFeesInfo[msg.sender].stakedAmount;
        IERC20(PUSH_TOKEN_ADDRESS).safeTransfer(msg.sender, stakedAmount);

        // Adjust user and total rewards, piggyback method
        _adjustUserAndTotalStake(msg.sender, userFeesInfo[msg.sender].stakedWeight, true);

        userFeesInfo[msg.sender].stakedAmount = 0;
        userFeesInfo[msg.sender].stakedWeight = 0;
        totalStakedAmount -= stakedAmount;

        emit Unstaked(msg.sender, stakedAmount);
    }

    /**
     * @notice Allows users to harvest/claim their earned rewards from the protocol
     * @dev    Computes nextFromEpoch and currentEpoch and uses them as startEPoch and endEpoch respectively.
     *         Rewards are claculated from start epoch till endEpoch(currentEpoch - 1).
     *         Once calculated, user's total claimed rewards and nextFromEpoch details is updated.
     *
     */
    function harvestAll() public whenNotPaused {
        uint256 currentEpoch = lastEpochRelative(genesisEpoch, block.number);

        uint256 rewards = harvest(msg.sender, currentEpoch - 1);
        IERC20(PUSH_TOKEN_ADDRESS).safeTransfer(msg.sender, rewards);
    }

    /**
     * @notice Allows paginated harvests for users between a particular number of epochs.
     * @param  _tillEpoch   - the end epoch number till which rewards shall be counted.
     * @dev    _tillEpoch should never be equal to currentEpoch.
     *         Transfers rewards to caller and updates user's details.
     *
     */
    function harvestPaginated(uint256 _tillEpoch) external whenNotPaused {
        uint256 rewards = harvest(msg.sender, _tillEpoch);
        IERC20(PUSH_TOKEN_ADDRESS).safeTransfer(msg.sender, rewards);
    }

    /**
     * @notice Allows Push Governance to harvest/claim the earned rewards for its stake in the protocol
     * @param  _tillEpoch   - the end epoch number till which rewards shall be counted.
     * @dev    only accessible by Push Admin
     *         Unlike other harvest functions, this is designed to transfer rewards to Push Governance.
     *
     */
    function daoHarvestPaginated(uint256 _tillEpoch) external whenNotPaused {
        onlyGovernance();
        uint256 rewards = harvest(address(this), _tillEpoch);
        IERC20(PUSH_TOKEN_ADDRESS).safeTransfer(governance, rewards);
    }

    /**
     * @notice Internal harvest function that is called for all types of harvest procedure.
     * @param  _user       - The user address for which the rewards will be calculated.
     * @param  _tillEpoch   - the end epoch number till which rewards shall be counted.
     * @dev    _tillEpoch should never be equal to currentEpoch.
     *         Transfers rewards to caller and updates user's details.
     *
     */
    function harvest(address _user, uint256 _tillEpoch) internal returns (uint256 rewards) {
        IPUSH(PUSH_TOKEN_ADDRESS).resetHolderWeight(_user);
        _adjustUserAndTotalStake(_user, 0, false);

        uint256 currentEpoch = lastEpochRelative(genesisEpoch, block.number);
        uint256 nextFromEpoch = lastEpochRelative(genesisEpoch, userFeesInfo[_user].lastClaimedBlock);

        if (currentEpoch <= _tillEpoch) {
            revert Errors.PushStaking_InvalidEpoch_LessThanExpected();
        }
        if (_tillEpoch < nextFromEpoch) {
            revert Errors.InvalidArg_LessThanExpected(nextFromEpoch, _tillEpoch);
        }
        for (uint256 i = nextFromEpoch; i <= _tillEpoch; i++) {
            uint256 claimableReward = calculateEpochRewards(_user, i);
            rewards = rewards + claimableReward;
        }

        usersRewardsClaimed[_user] = usersRewardsClaimed[_user] + rewards;
        // set the lastClaimedBlock to blocknumer at the end of `_tillEpoch`
        uint256 _epoch_to_block_number = genesisEpoch + _tillEpoch * epochDuration;
        userFeesInfo[_user].lastClaimedBlock = _epoch_to_block_number;

        emit RewardsHarvested(_user, rewards, nextFromEpoch, _tillEpoch);
    }

    /**
     * @notice  This functions helps in adjustment of user's as well as totalWeigts, both of which are imperative for
     * reward calculation at a particular epoch.
     * @dev     Enables adjustments of user's stakedWeight, totalStakedWeight, epochToTotalStakedWeight as well as
     * epochToTotalStakedWeight.
     *          triggers _setupEpochsReward() to adjust rewards for every epoch till the current epoch
     *
     *          Includes 2 main cases of weight adjustments
     *          1st Case: User stakes for the very first time:
     *              - Simply update userFeesInfo, totalStakedWeight and epochToTotalStakedWeight of currentEpoch
     *
     *          2nd Case: User is NOT staking for first time - 2 Subcases
     *              2.1 Case: User stakes again but in Same Epoch
     *                  - Increase user's stake and totalStakedWeight
     *                  - Record the epochToUserStakedWeight for that epoch
     *                  - Record the epochToTotalStakedWeight of that epoch
     *
     *              2.2 Case: - User stakes again but in different Epoch
     *                  - Update the epochs between lastStakedEpoch & (currentEpoch - 1) with the old staked weight
     * amounts
     *                  - While updating epochs between lastStaked & current Epochs, if any epoch has zero value for
     * totalStakedWeight, update it with current totalStakedWeight value of the protocol
     *                  - For currentEpoch, initialize the epoch id with updated weight values for
     * epochToUserStakedWeight & epochToTotalStakedWeight
     */
    function _adjustUserAndTotalStake(address _user, uint256 _userWeight, bool isUnstake) internal {
        uint256 currentEpoch = lastEpochRelative(genesisEpoch, block.number);
        _setupEpochsRewardAndWeights(_userWeight, currentEpoch, isUnstake);
        uint256 userStakedWeight = userFeesInfo[_user].stakedWeight;

        // Initiating 1st Case: User stakes for first time
        if (userStakedWeight == 0) {
            userFeesInfo[_user].stakedWeight = _userWeight;
        } else {
            // Initiating 2.1 Case: User stakes again but in Same Epoch
            uint256 lastStakedEpoch = lastEpochRelative(genesisEpoch, userFeesInfo[_user].lastStakedBlock);
            if (currentEpoch == lastStakedEpoch) {
                userFeesInfo[_user].stakedWeight =
                    isUnstake ? userStakedWeight - _userWeight : userStakedWeight + _userWeight;
            } else {
                // Initiating 2.2 Case: User stakes again but in Different Epoch
                for (uint256 i = lastStakedEpoch; i <= currentEpoch; i++) {
                    if (i != currentEpoch) {
                        userFeesInfo[_user].epochToUserStakedWeight[i] = userStakedWeight;
                    } else {
                        userFeesInfo[_user].stakedWeight =
                            isUnstake ? userStakedWeight - _userWeight : userStakedWeight + _userWeight;
                        userFeesInfo[_user].epochToUserStakedWeight[i] = userFeesInfo[_user].stakedWeight;
                    }
                }
            }
        }

        if (_userWeight != 0) {
            userFeesInfo[_user].lastStakedBlock = block.number;
        }
    }

    /**
     * @notice Internal function that allows setting up the rewards for specific EPOCH IDs
     * @dev    Initializes (sets reward) for every epoch ID that falls between the lastEpochInitialized and currentEpoch
     *         Reward amount for specific EPOCH Ids depends on newly available Protocol_Pool_Fees.
     *             - If no new fees was accumulated, rewards for particular epoch ids can be zero
     *             - Records the Pool_Fees value used as rewards.
     *             - Records the last epoch id whose rewards were set.
     */
    function _setupEpochsRewardAndWeights(uint256 _userWeight, uint256 _currentEpoch, bool isUnstake) private {
        uint256 _lastEpochInitiliazed = lastEpochRelative(genesisEpoch, lastEpochInitialized);

        // Setting up Epoch Based Rewards
        if (_currentEpoch > _lastEpochInitiliazed || _currentEpoch == 1) {
            uint256 availableRewardsPerEpoch = (PROTOCOL_POOL_FEES - previouslySetEpochRewards);
            uint256 _epochGap = _currentEpoch - _lastEpochInitiliazed;

            if (_epochGap > 1) {
                epochRewards[_currentEpoch - 1] += availableRewardsPerEpoch;
            } else {
                epochRewards[_currentEpoch] += availableRewardsPerEpoch;
            }

            lastEpochInitialized = block.number;
            previouslySetEpochRewards = PROTOCOL_POOL_FEES;
        }
        // Setting up Epoch Based TotalWeight
        if (lastTotalStakeEpochInitialized == 0 || lastTotalStakeEpochInitialized == _currentEpoch) {
            epochToTotalStakedWeight[_currentEpoch] = isUnstake
                ? epochToTotalStakedWeight[_currentEpoch] - _userWeight
                : epochToTotalStakedWeight[_currentEpoch] + _userWeight;
        } else {
            for (uint256 i = lastTotalStakeEpochInitialized + 1; i <= _currentEpoch - 1; i++) {
                if (epochToTotalStakedWeight[i] == 0) {
                    epochToTotalStakedWeight[i] = epochToTotalStakedWeight[lastTotalStakeEpochInitialized];
                }
            }

            epochToTotalStakedWeight[_currentEpoch] = isUnstake
                ? epochToTotalStakedWeight[lastTotalStakeEpochInitialized] - _userWeight
                : epochToTotalStakedWeight[lastTotalStakeEpochInitialized] + _userWeight;
        }
        lastTotalStakeEpochInitialized = _currentEpoch;
    }

    /**
     * @notice Designed to handle the incoming Incentivized Chat Request Data and PUSH tokens.
     * @dev    This function currently handles the PUSH tokens that enters the contract due to any
     *         activation of incentivizied chat request from Communicator contract.
     *          - Can only be called by Communicator contract
     *          - Records and keeps track of Pool Funds and Pool Fees
     *          - Stores the PUSH tokens for the Celeb User, which can be claimed later only by that specific user.
     * @param  requestSender    Address that initiates the incentivized chat request
     * @param  requestReceiver  Address of the target user for whom the request is activated.
     * @param  amount           Amount of PUSH tokens deposited for activating the chat request
     */
    function handleChatRequestData(address requestSender, address requestReceiver, uint256 amount) external {
        if (msg.sender != epnsCommunicator) {
            revert Errors.UnauthorizedCaller(msg.sender);
        }
        uint256 poolFeeAmount = FEE_AMOUNT;
        uint256 requestReceiverAmount = amount - poolFeeAmount;

        celebUserFunds[requestReceiver] += requestReceiverAmount;
        PROTOCOL_POOL_FEES = PROTOCOL_POOL_FEES + poolFeeAmount;

        emit IncentivizeChatReqReceived(
            requestSender, requestReceiver, requestReceiverAmount, poolFeeAmount, block.timestamp
        );
    }

    /**
     * @notice Allows the Celeb User(for whom chat requests were triggered) to claim their PUSH token earings.
     * @dev    Only accessible if a particular user has a non-zero PUSH token earnings in contract.
     * @param  _amount Amount of PUSH tokens to be claimed
     */
    function claimChatIncentives(uint256 _amount) external {
        if (celebUserFunds[msg.sender] < _amount) {
            revert Errors.InvalidArg_MoreThanExpected(celebUserFunds[msg.sender], _amount);
        }

        celebUserFunds[msg.sender] -= _amount;
        IERC20(PUSH_TOKEN_ADDRESS).safeTransfer(msg.sender, _amount);

        emit ChatIncentiveClaimed(msg.sender, _amount);
    }

    function sendFunds(address _user, uint256 _amount) external {
        if (msg.sender != feePoolStakingContract) {
            revert Errors.UnauthorizedCaller(msg.sender);
        }
        IERC20(PUSH_TOKEN_ADDRESS).transfer(_user, _amount);
    }
}
