pragma solidity ^0.8.20;

import { CoreTypes } from "../libraries/DataTypes.sol";

interface IPushCoreV3 {
    /* *****************************

       EVENTS

    ***************************** */

    /// @notice emits whenever a channel updates its metadata
    event UpdateChannel(address indexed channel, bytes identity, uint256 indexed amountDeposited);
    /// @notice emits whenever a channel is verified either by admin or any otherchannel with primary verification
    event ChannelVerified(address indexed channel, address indexed verifier);
    /// @notice emits whenever the verification is revoked for a channel
    event ChannelVerificationRevoked(address indexed channel, address indexed revoker);
    /// @notice emits whenever any channel is blocked by admin
    event ChannelBlocked(address indexed channel);
    /// @notice emits whenever a new channel is created
    event AddChannel(address indexed channel, CoreTypes.ChannelType indexed channelType, bytes identity);
    /// @notice emits whenever a channel changes the notification settings
    event ChannelNotifcationSettingsAdded(
        address _channel, uint256 totalNotifOptions, string _notifSettings, string _notifDescription
    );
    /// @notice emits whenever a subgraph is added(handled by backend)
    event AddSubGraph(address indexed channel, bytes _subGraphData);
    /// @notice emits whenever any time bound channel is deleted permanently
    // event TimeBoundChannelDestroyed(address indexed channel, uint256 indexed amountRefunded);
    /// @notice emits whenever a user stakes in the staking program
    event Staked(address indexed user, uint256 indexed amountStaked);
    /// @notice emits whenever a user unstakes from the staking program
    event Unstaked(address indexed user, uint256 indexed amountUnstaked);
    /// @notice emits whenever a users claims the rewards from the staking program(not unstake)
    event RewardsHarvested(address indexed user, uint256 indexed rewardAmount, uint256 fromEpoch, uint256 tillEpoch);
    /// @notice emits whenever any user receives an incentivized chat request from another user
    event IncentivizeChatReqReceived(
        address requestSender,
        address requestReceiver,
        uint256 amountForReqReceiver,
        uint256 feePoolAmount,
        uint256 timestamp
    );
    /// @notice emits whenever a user claims the remianing funds that they got from incentivized chat
    event ChatIncentiveClaimed(address indexed user, uint256 indexed amountClaimed);
    /// @notice emits when the state of a channel is updated from Active State to either Deactivated, Reactivated,
    /// Blocked or Deleted
    event ChannelStateUpdate(address indexed channel, uint256 amountRefunded, uint256 amountDeposited);

    /* *****************************

        READ-ONLY FUNCTIONS  

    ***************************** */
    /**
     * @notice    Function is designed to tell if a channel is verified or not
     * @dev       Get if channel is verified or not
     * @param    _channel Address of the channel to be Verified
     * @return   verificationStatus  Returns 0 for not verified, 1 for primary verification, 2 for secondary
     * verification
     *
     */
    function getChannelVerfication(address _channel) external view returns (uint8 verificationStatus);

    /* *****************************

        STATE-CHANGING FUNCTIONS  

    ***************************** */

    function addSubGraph(bytes calldata _subGraphData) external;
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
    function updateChannelMeta(address _channel, bytes calldata _newIdentity, uint256 _amount) external;

    /**
     * @notice An external function that allows users to Create their Own Channels by depositing a valid amount of PUSH
     * @dev    Only allows users to Create One Channel for a specific address.
     *         Only allows a Valid Channel Type to be assigned for the Channel Being created.
     *         Validates and Transfers the amount of PUSH  from the Channel Creator to the Push Core Contract
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
        external;

    /**
     * @notice Function that allows Channel Owners to Destroy their Time-Bound Channels
     * @dev    - Can only be called the owner of the Channel or by the Push Governance/Admin.
     *         - Push Governance/Admin can only destory a channel after 14 Days of its expriation timestamp.
     *         - Can only be called if the Channel is of type - TimeBound
     *         - Can only be called after the Channel Expiry time is up.
     *         - If Channel Owner destroys the channel after expiration, he/she recieves back refundable amount &
     * CHANNEL_POOL_FUNDS decreases.
     *         - If Channel is destroyed by Push Governance/Admin, No refunds for channel owner. Refundable Push tokens
     * are added to PROTOCOL_POOL_FEES.
     *         - Deletes the Channel completely
     *         - It transfers back refundable tokenAmount back to the USER.
     *
     */
    // function destroyTimeBoundChannel(address _channelAddress) external;
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
        external;

    /**
     * @notice Allows Channel Owners to change the state of their channel or remove Expired Channels (if channel was
     * time-bound)
     *         A channel's state can be => INACTIVE, ACTIVATED, DEACTIVATED or BLOCKED
     *
     * @dev    - Can only be called by the onwer of the channel
     *         - Channel must not be in an INACTIVE or BLOCKED state, else REVERTS
     *
     *          - If Channel is ACTIVE state, it can enter either of the two phases:
     *            - DEACTIVATION PHASE:
     *              a. Channel gets deactivated and refundable amount gets transferred back to Channel Owner.
     *            - TIME-BOUND CHANNEL DELETION PHASE:
     *              a. If Channel is expired, it gets deleted from the protocol. Refundable amount is refunded to
     * Channel Owner
     *              b. Channel Count is decreased in the protocol.
     *
     *         - If Channel is in DEACTIVATED state, it can only enter the REACTIVATION PHASE:
     *           - REACTIVATION PHASE:
     *              a. Chanel Owner pays fees to reactivate his/her channel
     *              b. Fees goes to Pool Funds
     *
     *         - Emit 'ChannelStateUpdate' Event
     * @param _amount Amount to be passed for reactivating a channel. If Channel is to be deactivated, or deleted,
     * amount can be ZERO.
     *
     */
    function updateChannelState(uint256 _amount) external;

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
    function blockChannel(address _channelAddress) external;

    /**
     * @notice    Function is designed to verify a channel
     * @dev       Channel will be verified by primary or secondary verification, will fail or upgrade if already
     * verified
     * @param    _channel Address of the channel to be Verified
     *
     */
    function verifyChannel(address _channel) external;

    /**
     * @notice    Function is designed to unverify a channel
     * @dev       Channel who verified this channel or Push Channel Admin can only revoke
     * @param    _channel Address of the channel to be unverified
     *
     */
    function unverifyChannel(address _channel) external;

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
    function handleChatRequestData(address requestSender, address requestReceiver, uint256 amount) external;

    /**
     * @notice Allows the Celeb User(for whom chat requests were triggered) to claim their PUSH token earings.
     * @dev    Only accessible if a particular user has a non-zero PUSH token earnings in contract.
     * @param  _amount Amount of PUSH tokens to be claimed
     */
    function claimChatIncentives(uint256 _amount) external;
}
