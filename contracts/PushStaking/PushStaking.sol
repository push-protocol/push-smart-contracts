// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./PushStakingStorage.sol";
import "../interfaces/IPUSH.sol";
import { IPushCoreStaking } from "../interfaces/IPushCoreStaking.sol";
import { Errors } from "../libraries/Errors.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract PushFeePoolStaking is Initializable, PushStakingStorage {
    using SafeERC20 for IERC20;

    event Staked(address indexed user, uint256 indexed amountStaked);
    event Unstaked(address indexed user, uint256 indexed amountUnstaked);
    event RewardsHarvested(address indexed user, uint256 indexed rewardAmount, uint256 fromEpoch, uint256 tillEpoch);

    function initialize(
        address _pushChannelAdmin,
        address _core,
        address _pushToken
    )
        public
        initializer
    {
        pushChannelAdmin = _pushChannelAdmin;
        governance = _pushChannelAdmin;
        core = _core;
        PUSH_TOKEN_ADDRESS = _pushToken;
    }

    modifier onlyPushChannelAdmin() {
        if (msg.sender != pushChannelAdmin) {
            revert Errors.CallerNotAdmin();
        }
        _;
    }

    modifier onlyGovernance() {
        if (msg.sender != governance) {
            revert Errors.CallerNotGovernance();
        }
        _;
    }

    modifier isMigrated() {
        if (migrated) {
            revert Errors.PushStaking_MigrationCompleted();
        }
        _;
    }

    function setGovernanceAddress(address _governanceAddress) external onlyPushChannelAdmin {
        governance = _governanceAddress;
    }

    function initializeStake() external {
        require(
            genesisEpoch == 0,
            "PushCoreV2::initializeStake: Already Initialized"
        );
        genesisEpoch = block.number;
        lastEpochInitialized = genesisEpoch;

        _stake(core, 1e18);
    }

   /*
     * Fetching shares for a wallet 
     * 1. Internal helper function
     * 2. helps in getting the shares to be assigned for a wallet based on params passed in this function
   */ 
    function getSharesAmount(
        uint256 _totalShares,
        StakingTypes.Percentage memory _percentage
    )
        public
        pure
        returns (uint256 sharesToBeAllocated)
    {
        if (_percentage.percentageNumber / 10 ** _percentage.decimalPlaces >= 100) revert Errors.InvalidArg_MoreThanExpected( 99,_percentage.decimalPlaces);
        sharesToBeAllocated = (_percentage.percentageNumber * _totalShares) 
            / ((100 * (10 ** _percentage.decimalPlaces)) - _percentage.percentageNumber);
    }

   /*
     * Adding Wallet Share to a Wallet
     * 1. addWalletShare(address wallet, uint256 percentageOfShares)
     * 2. Can be called by governance.
     * 3. Uses the formulae to derive the percent of shares to be assigned to a specific wallet
     * 4. Updates WALLET_TOTAL_SHARES
     * 5. Updates WalletToShares mapping
     * 6. Emits out an event.
     * 7. If a wallet has already has a share, then it acts as a "increase share" function. And the percenatge passed
     *    should be greater than the already assigned percentge.
    */  
    function addWalletShare(address _walletAddress, StakingTypes.Percentage memory _percentage) public onlyGovernance{
        uint oldTotalShare = WALLET_TOTAL_SHARES;
        uint currentWalletShare = WalletToShares[_walletAddress];
        uint newTotalShare;

        if( currentWalletShare != 0) {
            newTotalShare = oldTotalShare - currentWalletShare;
        }else{
            newTotalShare = oldTotalShare;
        }
        uint256 sharesToBeAllocated = getSharesAmount(newTotalShare, _percentage);
         if (sharesToBeAllocated < currentWalletShare) revert Errors.InvalidArg_LessThanExpected(currentWalletShare, sharesToBeAllocated);
        WALLET_TOTAL_SHARES = newTotalShare + sharesToBeAllocated;
        WalletToShares[_walletAddress] = sharesToBeAllocated;
    }
   /*
     * Removing Wallet Share from a Wallet
     * 1. removes the shares from a wallet completely
     * 2. Can be called by governance.
     * 3. Updates WALLET_TOTAL_SHARES
     * 4. Emits out an event.
   */
    function removeWalletShare(address _walletAddress) public onlyGovernance {
        WalletToShares[FOUNDATION] += WalletToShares[_walletAddress];
        WalletToShares[_walletAddress] = 0;
    }

    function decreaseWalletShare(address _walletAddress, StakingTypes.Percentage memory _percentage) external onlyGovernance{
        removeWalletShare(_walletAddress);
        addWalletShare( _walletAddress, _percentage);

    }

    /*
     *Reward Calculation for a Given Wallet
     * 1. calculateWalletRewards(address wallet)
     * 2. public helper function
     * 3. Helps in calculating rewards for a specific wallet based on
       * a. Their Wallet Share 
        * b. Total Wallet Shares
        * c. Total Rewards available in WALLET_TOTAL_SHARES
     * 4. Once calculated rewards for a sepcific wallet can be updated in WalletToRewards mapping
     * 5. Reward can be calculated for wallets similar they are calculated for Token holders in a specific epoch.
        * Reward for a Given Wallet X = ( Wallet Share of X / WALLET_TOTAL_SHARES) * WALLET_FEE_POOL
    */
   //TODO logic yet to be finalized
   function calculateWalletRewards(address _wallet) public returns(uint) {
       return ( WalletToShares[_wallet] / WALLET_TOTAL_SHARES) * IPushCoreStaking(core).WALLET_FEE_POOL();
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
        if (block.number <= userFeesInfo[msg.sender].lastStakedBlock + epochDuration) {
            revert Errors.PushStaking_InvalidEpoch_LessThanExpected();
        }
        if (userFeesInfo[msg.sender].stakedAmount == 0) {
            revert Errors.UnauthorizedCaller(msg.sender);
        }
        harvestAll();
        uint256 stakedAmount = userFeesInfo[msg.sender].stakedAmount;
        IPushCoreStaking(core).sendFunds(msg.sender, stakedAmount);

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
        IPushCoreStaking(core).sendFunds(msg.sender, rewards);
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
        IPushCoreStaking(core).sendFunds(msg.sender, rewards);
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
            revert Errors.CallerNotAdmin();
        }
        uint256 rewards = harvest(core, _tillEpoch);
        IPushCoreStaking(core).sendFunds(msg.sender, rewards);
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
            uint256 PROTOCOL_POOL_FEES = IPushCoreStaking(core).PROTOCOL_POOL_FEES();
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
