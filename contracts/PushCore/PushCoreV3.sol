pragma solidity ^0.8.20;

/**
 * @title  PushCore V3
 * @author Push Protocol
 * @notice Push Core is the main protocol that deals with the imperative
 *         features and functionalities like Channel Creation, pushChannelAdmin etc.
 *
 * @dev This protocol will be specifically deployed on Ethereum Blockchain while the Communicator
 *      protocols can be deployed on Multiple Chains.
 *      The Push Core is more inclined towards the storing and handling the Channel related functionalties.
 *
 */
import { PushCoreStorageV1_5 } from "./PushCoreStorageV1_5.sol";
import { PushCoreStorageV2 } from "./PushCoreStorageV2.sol";
import "../interfaces/IPUSH.sol";
import { IPushCoreV3 } from "../interfaces/IPushCoreV3.sol";
import { Errors } from "../libraries/Errors.sol";
import { CoreTypes } from "../libraries/DataTypes.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { PausableUpgradeable, Initializable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract PushCoreV3 is Initializable, PushCoreStorageV1_5, PausableUpgradeable, PushCoreStorageV2, IPushCoreV3 {
    using SafeERC20 for IERC20;

    /* ***************
        INITIALIZER
    *************** */
    /**
     * @notice Initializer has been removed to save contract space.
     * However, for readability, initialized values have been mentioned below:
     *   FEE_AMOUNT            = 10 ether;
     *   MIN_POOL_CONTRIBUTION = 1 ether;
     *   ADD_CHANNEL_MIN_FEES  = 50 ether;
     *   ADJUST_FOR_FLOAT      = 10 ** 7;
     * --------------------------------------------------------------------------
     */

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
            revert Errors.CallerNotGovernance();
        }
    }

    function onlyActivatedChannels(address _channel) private view {
        if (channels[_channel].channelState != 1) {
            revert Errors.Core_InvalidChannel();
        }
    }

    function addSubGraph(bytes calldata _subGraphData) external {
        onlyActivatedChannels(msg.sender);
        emit AddSubGraph(msg.sender, _subGraphData);
    }

    function setPushCommunicatorAddress(address _commAddress) external {
        onlyPushChannelAdmin();
        pushCommunicator = _commAddress;
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
        if (_newFees == 0) {
            revert Errors.InvalidArg_LessThanExpected(1, _newFees);
        }
        if (_newFees >= ADD_CHANNEL_MIN_FEES) {
            revert Errors.InvalidArg_MoreThanExpected(ADD_CHANNEL_MIN_FEES, _newFees);
        }
        FEE_AMOUNT = _newFees;
    }

    function setMinPoolContribution(uint256 _newAmount) external {
        onlyGovernance();
        if (_newAmount == 0) {
            revert Errors.InvalidArg_LessThanExpected(1, _newAmount);
        }
        MIN_POOL_CONTRIBUTION = _newAmount;
    }

    function pauseContract() external {
        onlyPushChannelAdmin();
        _pause();
    }

    function unPauseContract() external {
        onlyPushChannelAdmin();
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
    ///@inheritdoc IPushCoreV3
    function updateChannelMeta(address _channel, bytes calldata _newIdentity, uint256 _amount) external whenNotPaused {
        onlyActivatedChannels(_channel);

        if (msg.sender != _channel) {
            revert Errors.UnauthorizedCaller(msg.sender);
        }

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

    /// @inheritdoc IPushCoreV3
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
            !(
                _channelType == CoreTypes.ChannelType.InterestBearingOpen
                    || _channelType == CoreTypes.ChannelType.InterestBearingMutual
                    || _channelType == CoreTypes.ChannelType.TimeBound || _channelType == CoreTypes.ChannelType.TokenGated
            )
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
     *         -Subscribes the Channel's Owner to Imperative Push Channels as well as their Own Channels
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
    }

    /// @inheritdoc IPushCoreV3
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

    /// @inheritdoc IPushCoreV3
    function updateChannelState(uint256 _amount) external whenNotPaused {
        // Check channel's current state
        CoreTypes.Channel storage channelData = channels[msg.sender];
        uint8 channelCurrentState = channelData.channelState;
        // Prevent INACTIVE or BLOCKED Channels
        if (channelCurrentState != 1 && channelCurrentState != 2) {
            revert Errors.Core_InvalidChannel();
        }

        uint256 minPoolContribution = MIN_POOL_CONTRIBUTION;
        // If Active State , Enter the Time-Bound Deletion/Deactivate Channel Phase
        if (channelCurrentState == 1) {
            uint256 totalRefundableAmount;
            bool isTimeBound = channelData.channelType == CoreTypes.ChannelType.TimeBound;
            if (!isTimeBound) {
                // DEACTIVATION PHASE
                totalRefundableAmount = channelData.poolContribution - minPoolContribution;

                uint256 _newChannelWeight = (minPoolContribution * ADJUST_FOR_FLOAT) / minPoolContribution;
                channelData.channelState = 2;
                channelData.channelWeight = _newChannelWeight;
                channelData.poolContribution = minPoolContribution;
                emit ChannelStateUpdate(msg.sender, totalRefundableAmount, 0);
            } else {
                // TIME-BOUND CHANNEL DELETION PHASE
                if (channelData.expiryTime >= block.timestamp) {
                    revert Errors.Core_InvalidChannel();
                }
                totalRefundableAmount = channelData.poolContribution;
                channelsCount = channelsCount - 1;
                delete channels[msg.sender];
                emit ChannelStateUpdate(msg.sender, totalRefundableAmount, 0);
            }
            CHANNEL_POOL_FUNDS = CHANNEL_POOL_FUNDS - totalRefundableAmount;
            IERC20(PUSH_TOKEN_ADDRESS).safeTransfer(msg.sender, totalRefundableAmount);
        } // RE-ACTIVATION PHASE
        else {
            if (_amount < ADD_CHANNEL_MIN_FEES) {
                revert Errors.InvalidArg_LessThanExpected(ADD_CHANNEL_MIN_FEES, _amount);
            }

            IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(msg.sender, address(this), _amount);
            uint256 poolFeeAmount = FEE_AMOUNT;
            uint256 poolFundAmount = _amount - poolFeeAmount;
            //store funds in pool_funds & pool_fees
            CHANNEL_POOL_FUNDS = CHANNEL_POOL_FUNDS + poolFundAmount;
            PROTOCOL_POOL_FEES = PROTOCOL_POOL_FEES + poolFeeAmount;

            uint256 _newPoolContribution = channelData.poolContribution + poolFundAmount;
            uint256 _newChannelWeight = (_newPoolContribution * ADJUST_FOR_FLOAT) / minPoolContribution;

            channelData.channelState = 1;
            channelData.poolContribution = _newPoolContribution;
            channelData.channelWeight = _newChannelWeight;
            emit ChannelStateUpdate(msg.sender, 0, _amount);
        }
    }

    /// @inheritdoc IPushCoreV3
    function blockChannel(address _channelAddress) external whenNotPaused {
        onlyGovernance();
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

    /// @inheritdoc IPushCoreV3
    function getChannelVerfication(address _channel) public view returns (uint8 verificationStatus) {
        address verifiedBy = channels[_channel].verifiedBy;
        bool logicComplete = false;

        // Check if it's primary verification
        if (verifiedBy == pushChannelAdmin || _channel == pushChannelAdmin) {
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
        for (uint256 i = _startIndex; i < _endIndex;) {
            verifyChannel(_channelList[i]);

            unchecked {
                i++;
            }
        }
        return true;
    }

    /// @inheritdoc IPushCoreV3
    function verifyChannel(address _channel) public {
        onlyActivatedChannels(_channel);
        // Check if caller is verified first
        uint8 callerVerified = getChannelVerfication(msg.sender);
        if (callerVerified == 0) {
            revert Errors.UnauthorizedCaller(msg.sender);
        }

        // Check if channel is verified
        uint8 channelVerified = getChannelVerfication(_channel);
        if (!(channelVerified == 0 || msg.sender == pushChannelAdmin)) {
            revert Errors.Core_InvalidChannel();
        }

        // Verify channel
        channels[_channel].verifiedBy = msg.sender;

        // Emit event
        emit ChannelVerified(_channel, msg.sender);
    }

    /// @inheritdoc IPushCoreV3
    function unverifyChannel(address _channel) public {
        if (!(channels[_channel].verifiedBy == msg.sender || msg.sender == pushChannelAdmin)) {
            revert Errors.CallerNotAdmin();
        }

        // Unverify channel
        channels[_channel].verifiedBy = address(0x0);

        // Emit Event
        emit ChannelVerificationRevoked(_channel, msg.sender);
    }

    /**
     * Core-V3: Stake and Claim Functions
     */

    /// @notice Allows caller to add pool_fees at any given epoch
    function addPoolFees(uint256 _rewardAmount) external {
        IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(msg.sender, address(this), _rewardAmount);
        PROTOCOL_POOL_FEES = PROTOCOL_POOL_FEES + _rewardAmount;
    }

    /**
     * @notice Function to return User's Push Holder weight based on amount being staked & current block number
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
    function stake(uint256 _amount) external {
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
    function unstake() external {
        if (block.number <= userFeesInfo[msg.sender].lastStakedBlock + epochDuration) {
            revert Errors.PushStaking_InvalidEpoch_LessThanExpected();
        }
        if (userFeesInfo[msg.sender].stakedAmount == 0) {
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
    function harvestAll() public {
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
    function harvestPaginated(uint256 _tillEpoch) external {
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
    function daoHarvestPaginated(uint256 _tillEpoch) external {
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

    /// @inheritdoc IPushCoreV3
    function handleChatRequestData(address requestSender, address requestReceiver, uint256 amount) external {
        if (msg.sender != pushCommunicator) {
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

    /// @inheritdoc IPushCoreV3
    function claimChatIncentives(uint256 _amount) external {
        if (celebUserFunds[msg.sender] < _amount) {
            revert Errors.InvalidArg_MoreThanExpected(celebUserFunds[msg.sender], _amount);
        }

        celebUserFunds[msg.sender] -= _amount;
        IERC20(PUSH_TOKEN_ADDRESS).safeTransfer(msg.sender, _amount);

        emit ChatIncentiveClaimed(msg.sender, _amount);
    }
}
