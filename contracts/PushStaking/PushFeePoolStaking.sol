// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./PushFeePoolStorage.sol";
import "../interfaces/IPUSH.sol";
import "../interfaces/IPushCore.sol";
import "../libraries/Errors.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract PushFeePoolStaking is Initializable, PushFeePoolStorage {
    using SafeERC20 for IERC20;

    event Staked(address indexed user, uint256 indexed amountStaked);
    event Unstaked(address indexed user, uint256 indexed amountUnstaked);
    event RewardsHarvested(address indexed user, uint256 indexed rewardAmount, uint256 fromEpoch, uint256 tillEpoch);

    function initialize(
        address _pushChannelAdmin,
        address _core,
        address _pushToken,
        uint256 _genesisEpoch,
        uint256 _lastEpochInitialized,
        uint256 _lastTotalStakeEpochInitialized,
        uint256 _totalStakedAmount,
        uint256 _previouslySetEpochRewards
    )
        public
        initializer
    {
        pushChannelAdmin = _pushChannelAdmin;
        governance = _pushChannelAdmin;
        core = _core;
        PUSH_TOKEN_ADDRESS = _pushToken;
        genesisEpoch = _genesisEpoch;
        lastEpochInitialized = _lastEpochInitialized;
        lastTotalStakeEpochInitialized = _lastTotalStakeEpochInitialized;
        totalStakedAmount = _totalStakedAmount;
        previouslySetEpochRewards = _previouslySetEpochRewards;
    }

    modifier onlyPushChannelAdmin() {
        if (msg.sender != pushChannelAdmin) {
            revert InvalidCaller();
        }        _;
    }

    modifier isMigrated() {
        if(migrated){
            revert InvalidLogic("Migration Completed");
        }
        _;
    }

    function setGovernanceAddress(address _governanceAddress) external onlyPushChannelAdmin {
        governance = _governanceAddress;
    }

    // *************** MIGRATION FUNCTIONS BEGINS ********************* //
    function migrateEpochDetails(
        uint256 _currentEpoch,
        uint256[] memory _epochRewards,
        uint256[] memory _epochToTotalStakedWeight
    )
        public
        onlyPushChannelAdmin
        isMigrated
    {
        if (
            _currentEpoch != _epochRewards.length ||
            _currentEpoch != _epochToTotalStakedWeight.length
        ) {
            revert InvalidArgument("Invalid Length");
        }

        for (uint256 i; i < _currentEpoch; ++i) {
            epochRewards[i + 1] = _epochRewards[i];
            epochToTotalStakedWeight[i + 1] = _epochToTotalStakedWeight[i];
        }
    }

    function migrateUserData(
        uint256 start,
        uint256 end,
        address[] calldata _user,
        uint256[] calldata _stakedAmount,
        uint256[] calldata _stakedWeight,
        uint256[] calldata _lastStakedBlock,
        uint256[] calldata _lastClaimedBlock
    )
        external
        onlyPushChannelAdmin
        isMigrated
    {
        if (
            _user.length != _stakedAmount.length ||
            _user.length != _stakedWeight.length ||
            _user.length != _lastStakedBlock.length ||
            _user.length != _lastClaimedBlock.length
        ) {
            revert InvalidArgument("Invalid Length");
        }
        for (uint256 i = start; i < end; ++i) {
            userFeesInfo[_user[i]].stakedAmount = _stakedAmount[i];
            userFeesInfo[_user[i]].stakedWeight = _stakedWeight[i];
            userFeesInfo[_user[i]].lastStakedBlock = _lastStakedBlock[i];
            userFeesInfo[_user[i]].lastClaimedBlock = _lastClaimedBlock[i];
        }
    }

    function migrateUserMappings(
        uint256 _epoch,
        uint256 startIndex,
        uint256 endIndex,
        address[] calldata _user,
        uint256[] calldata _epochToUserStakedWeight,
        uint256[] calldata _userRewardsClaimed
    )
        external
        onlyPushChannelAdmin
        isMigrated
    {
        if (
            _user.length != _epochToUserStakedWeight.length ||
            _user.length != _userRewardsClaimed.length
        ) {
            revert InvalidArgument("Invalid Length");
        }

        for (uint256 i = startIndex; i < endIndex; ++i) {
            userFeesInfo[_user[i]].epochToUserStakedWeight[_epoch] = _epochToUserStakedWeight[i];
            if (_userRewardsClaimed.length > 0) {
                usersRewardsClaimed[_user[i]] = _userRewardsClaimed[i];
            }
        }
    }

    function setMigrationComplete() external onlyPushChannelAdmin {
        migrated = true;
    }

    // *************** MIGRATION FUNCTIONS BEGINS ********************* //

    /**
     * @notice Function to return User's Staked Weight for any given EPOCH ID
     *
     */
    function getEpochToUserStakedWeight(address _user, uint256 _epoch) external view returns (uint256) {
        return userFeesInfo[_user].epochToUserStakedWeight[_epoch];
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
    function lastEpochRelative(uint256 _from, uint256 _to) public pure returns (uint256) {
        if (_to < _from) {
            revert InvalidArgument("To < from");
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

        IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(msg.sender, core, _amount);

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
        if (
            block.number <=
            userFeesInfo[msg.sender].lastStakedBlock + epochDuration
        ) {
            revert InvalidEpoch("incomplete epoch");
        }
        if (userFeesInfo[msg.sender].stakedAmount <= 0) {
            revert InvalidCallerParam("not a staker");
        }
        harvestAll();
        uint256 stakedAmount = userFeesInfo[msg.sender].stakedAmount;
        IPushCore(core).sendFunds(msg.sender, stakedAmount);

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
        IPushCore(core).sendFunds(msg.sender, rewards);
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
        IPushCore(core).sendFunds(msg.sender, rewards);
    }

    /**
     * @notice Allows Push Governance to harvest/claim the earned rewards for its stake in the protocol
     * @param  _tillEpoch   - the end epoch number till which rewards shall be counted.
     * @dev    only accessible by Push Admin
     *         Unlike other harvest functions, this is designed to transfer rewards to Push Governance.
     *
     */
    function daoHarvestPaginated(uint256 _tillEpoch) external {
        if (msg.sender != governance) {
            revert InvalidCaller();
        }
        uint256 rewards = harvest(core, _tillEpoch);
        IPushCore(core).sendFunds(msg.sender, rewards);
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
            revert InvalidEpoch("currentEpoch <= _tillEpoch");
        }
        if (_tillEpoch < nextFromEpoch) {
            revert InvalidEpoch("_tillEpoch < nextFromEpoch");
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
            uint256 PROTOCOL_POOL_FEES = IPushCore(core).PROTOCOL_POOL_FEES();
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
}
