pragma solidity ^0.8.20;

/**
 * @title  PushCore v2.5
 * @author Push Protocol
 * @notice Push Core is the main protocol that deals with the imperative
 *         features and functionalities like Channel Creation, pushChannelAdmin etc.
 *
 * @dev This protocol will be specifically deployed on Ethereum Blockchain while the Communicator
 *      protocols can be deployed on Multiple Chains.
 *      The Push Core is more inclined towards the storing and handling the Channel related functionalties.
 *
 */
import { PushCoreStorageV1_5 } from "../PushCore/PushCoreStorageV1_5.sol";
import { PushCoreStorageV2 } from "../PushCore/PushCoreStorageV2.sol";
import { CoreTypes } from "../libraries/DataTypes.sol";
import { Errors } from "../libraries/Errors.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    PausableUpgradeable, Initializable
} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract PushCoreMock is Initializable, PushCoreStorageV1_5, PausableUpgradeable, PushCoreStorageV2 {
    using SafeERC20 for IERC20;

    event AddChannel(address indexed channel, CoreTypes.ChannelType indexed channelType, bytes identity);

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
    }
}
