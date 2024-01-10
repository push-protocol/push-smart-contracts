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
import { IPushCoreV2 } from "../interfaces/IPushCoreV2.sol";
import { IPushCommV2 } from "../interfaces/IPushCommV2.sol";
import { Errors } from "../libraries/Errors.sol";
import { CoreTypes } from "../libraries/DataTypes.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { PausableUpgradeable, Initializable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract PushCoreV2_5 is Initializable, PushCoreStorageV1_5, PausableUpgradeable, PushCoreStorageV2, IPushCoreV2 {
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
            !(
                (channels[_channel].channelState == 1 && msg.sender == _channel)
                    || (msg.sender == pushChannelAdmin && _channel == address(0x0))
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
    /**
     * @notice Allows admin to set the Fee Amount of core contract
     *
     * @dev    _newFees must not be more than (or equal to) the ADD_CHANNEL_MIN_FEES
     *
     * @param _newFees new minimum fees required for FEE_AMOUNT 
     */
    function setFeeAmount(uint256 _newFees) external {
        onlyGovernance();
        if (_newFees >= ADD_CHANNEL_MIN_FEES) {
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
     * @dev    Minimum required amount can never be below the sum of MIN_POOL_CONTRIBUTION and FEE_AMOUNT 
     *
     * @param _newFees new minimum fees required for Channel Creation
     *
     */
    function setMinChannelCreationFees(uint256 _newFees) external {
        onlyGovernance();
        uint256 minFeeRequired = MIN_POOL_CONTRIBUTION + FEE_AMOUNT;
        if (_newFees < minFeeRequired) {
            revert Errors.InvalidArg_LessThanExpected(minFeeRequired, _newFees);
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

    /// @inheritdoc IPushCoreV2
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

        IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(msg.sender, address(this), _amount);
        emit UpdateChannel(_channel, _newIdentity, _amount);
    }

    /// @inheritdoc IPushCoreV2
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
            _channelType != CoreTypes.ChannelType.InterestBearingOpen
                && _channelType != CoreTypes.ChannelType.InterestBearingMutual
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
        channelsCount = channelsCount + 1;

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

    /// @inheritdoc IPushCoreV2
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
        // Update POOL_FUNDS & PROTOCOL_POOL_FEES
        CHANNEL_POOL_FUNDS = CHANNEL_POOL_FUNDS - totalRefundableAmount;
        
        if (msg.sender != pushChannelAdmin) {
            IERC20(PUSH_TOKEN_ADDRESS).safeTransfer(msg.sender, totalRefundableAmount);
        } else {
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

    /// @inheritdoc IPushCoreV2
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

    /// @inheritdoc IPushCoreV2
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

    /// @inheritdoc IPushCoreV2
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

    /// @inheritdoc IPushCoreV2
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

    /// @inheritdoc IPushCoreV2
    function verifyChannel(address _channel) public {
        onlyActivatedChannels(_channel);
        // Check if caller is verified first
        uint8 callerVerified = getChannelVerfication(msg.sender);
        if (callerVerified == 0) {
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

    /// @inheritdoc IPushCoreV2
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
    function updateStakingAddress(address _stakingAddress) external {
        onlyPushChannelAdmin();
        feePoolStakingContract = _stakingAddress;
    }

    function sendFunds(address _user, uint256 _amount) external {
        if (msg.sender != feePoolStakingContract) {
            revert Errors.UnauthorizedCaller(msg.sender);
        }
        IERC20(PUSH_TOKEN_ADDRESS).transfer(_user, _amount);
    }

    /**
     * Allows caller to add pool_fees at any given epoch
     *
     */
    function addPoolFees(uint256 _rewardAmount) external {
        IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(msg.sender, address(this), _rewardAmount);
        PROTOCOL_POOL_FEES = PROTOCOL_POOL_FEES + _rewardAmount;
    }

    /// @inheritdoc IPushCoreV2
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

    /// @inheritdoc IPushCoreV2
    function claimChatIncentives(uint256 _amount) external {
        if (celebUserFunds[msg.sender] < _amount) {
            revert Errors.InvalidArg_MoreThanExpected(celebUserFunds[msg.sender], _amount);
        }

        celebUserFunds[msg.sender] -= _amount;
        IERC20(PUSH_TOKEN_ADDRESS).safeTransfer(msg.sender, _amount);

        emit ChatIncentiveClaimed(msg.sender, _amount);
    }
}
