pragma solidity >=0.6.0 <0.7.0;

/**
 * @title Ethereum Push Notification Service (EPNS) Core Contract
 * @author Ethereum Push Notification Service (EPNS) | https://epns.io | https://github.com/ethereum-push-notification-service
 * @notice Core Contract to Create Channels, Manage Subscribers and overall features of EPNS
 * @notice Version 0.2.1
 * SPDX-License-Identifier: UNLICENSED
 */

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface ILendingPoolAddressesProvider {
    function getLendingPoolCore() external view returns (address payable);
    function getLendingPool() external view returns (address);
}
interface ILendingPool {
    function addressesProvider () external view returns ( address );
    function deposit ( address _reserve, uint256 _amount, uint16 _referralCode ) external payable;
    function redeemUnderlying ( address _reserve, address _user, uint256 _amount ) external;
    function borrow ( address _reserve, uint256 _amount, uint256 _interestRateMode, uint16 _referralCode ) external;
    function repay ( address _reserve, uint256 _amount, address _onBehalfOf ) external payable;
    function swapBorrowRateMode ( address _reserve ) external;
    function rebalanceFixedBorrowRate ( address _reserve, address _user ) external;
    function setUserUseReserveAsCollateral ( address _reserve, bool _useAsCollateral ) external;
    function liquidationCall ( address _collateral, address _reserve, address _user, uint256 _purchaseAmount, bool _receiveAToken ) external payable;
    function flashLoan ( address _receiver, address _reserve, uint256 _amount, bytes calldata _params ) external;
    function getReserveConfigurationData ( address _reserve ) external view returns ( uint256 ltv, uint256 liquidationThreshold, uint256 liquidationDiscount, address interestRateStrategyAddress, bool usageAsCollateralEnabled, bool borrowingEnabled, bool fixedBorrowRateEnabled, bool isActive );
    function getReserveData ( address _reserve ) external view returns ( uint256 totalLiquidity, uint256 availableLiquidity, uint256 totalBorrowsFixed, uint256 totalBorrowsVariable, uint256 liquidityRate, uint256 variableBorrowRate, uint256 fixedBorrowRate, uint256 averageFixedBorrowRate, uint256 utilizationRate, uint256 liquidityIndex, uint256 variableBorrowIndex, address aTokenAddress, uint40 lastUpdateTimestamp );
    function getUserAccountData ( address _user ) external view returns ( uint256 totalLiquidityETH, uint256 totalCollateralETH, uint256 totalBorrowsETH, uint256 availableBorrowsETH, uint256 currentLiquidationThreshold, uint256 ltv, uint256 healthFactor );
    function getUserReserveData ( address _reserve, address _user ) external view returns ( uint256 currentATokenBalance, uint256 currentUnderlyingBalance, uint256 currentBorrowBalance, uint256 principalBorrowBalance, uint256 borrowRateMode, uint256 borrowRate, uint256 liquidityRate, uint256 originationFee, uint256 variableBorrowIndex, uint256 lastUpdateTimestamp, bool usageAsCollateralEnabled );
    function getReserves () external view;
}

contract EPNSCoreV2 is Ownable, ReentrancyGuard, Initializable {
    using SafeMath for uint;

    /* ***************
    * DEFINE ENUMS AND CONSTANTS
    *************** */
    // For Message Type
    enum ChannelType { InterestBearingChannel, NonInterestBearing }
    enum ChannelAction { ChannelRemoved, ChannelAdded, ChannelUpdated }
    enum SubscriberAction { SubscriberRemoved, SubscriberAdded, SubscriberUpdated }

    // // 500 DAI is a lot but channel should not update to avoid spoofing 
    // // For a serious player to rebrand, this should be ok
    // // The deposit goes to channel interest proceed so users should be happy
    // // There is also an inverse relation of fees per subscribers count which decreases the fees considerably
    // uint8 UPDATE_CHANNEL_INVERSE_START_FEES = 500; 
    // uint8 UPDATE_CHANNEL_INVERSE_MIN_FEES = 10; // Need to be 50 even if the inverse graph is maxed out
    // uint8 UPDATE_CHANNEL_INVERSE_GRAPH_SUBSCRIBER = 200; // 200 subscribers is -1% fees, 20k subscribers mean you only pay 10 DAI for update

    uint ADD_CHANNEL_MIN_POOL_CONTRIBUTION = 50; // 50 DAI or above to create the channel
    uint ADD_CHANNEL_MAX_POOL_CONTRIBUTION = 500 * 50 * 10**18; // 500 DAI or below, we don't want channel to make a costly mistake as well, for test it's 25k

    uint UPDATE_CHANNEL_POOL_CONTRIBUTION = 500 * 10**18; // 500 DAI or above to update the channel
    uint DELEGATED_CONTRACT_FEES = 1 * 10**17; // 0.1 DAI to perform any delegate call

    uint ADJUST_FOR_FLOAT = 10**7;

    uint REFERRAL_CODE;

    bytes EPNS_FIRST_MESSAGE_HASH = "3+QmZbff755tAPZ22REdF5PDLLjtbRUKu2THaXSZ7pkRf2qV";

    /* ***************
    // DEFINE STRUCTURES AND VARIABLES
    *************** */
    /* Create for testnet strict owner only channel whitelist
     * Will not be available on mainnet since that has real defi involed, use staging contract
     * for developers looking to try on hand
    */
    mapping (address => bool) channelizationWhitelist;

    /* Users are everyone in the EPNS Ecosystem
     * the struct creates a registry for public key signing and maintains the users subscribed channels
    */
    struct User {
        bool userActivated; // Whether a user is activated or not 
        bool publicKeyRegistered; // Will be false until public key is emitted
        bool channellized; // Marks if a user has opened a channel

        uint userStartBlock; // Events should not be polled before this block as user doesn't exist
        uint subscribedCount; // Keep track of subscribers

        uint timeWeightedBalance;

        // keep track of all subscribed channels
        mapping(address => uint) subscribed;
        mapping(uint => address) mapAddressSubscribed;

        // keep track of greylist, useful for unsubscribe so the channel can't subscribe you back
        mapping(address => bool) graylistedChannels;
    }

    // To keep a track of all users
    mapping(address => User) public users;
    mapping(uint => address) public mapAddressUsers;
    uint public usersCount;

    // To keep track of interest claimed and interest in wallet
    mapping(address => uint) public usersInterestClaimed;
    mapping(address => uint) public usersInterestInWallet;

    /* Channels are addresses who have wants their broadcasting network,
    * the channel can never go back to being a plain user but can be marked inactive
    */
    struct Channel {
        // Channel Type
        ChannelType channelType;

        // Flag to deactive channel
        bool deactivated;

        // Channel Pool Contribution
        uint poolContribution;
        uint memberCount;

        uint channelHistoricalZ;
        uint channelFairShareCount;
        uint channelLastUpdate; // The last update block number, used to calculate fair share

        // To calculate fair share of profit from the pool of channels generating interest
        uint channelStartBlock; // Helps in defining when channel started for pool and profit calculation
        uint channelWeight; // The individual weight to be applied as per pool contribution

        // To keep track of subscribers info 
        mapping(address => bool) memberExists;

        // For iterable mapping
        mapping(address => uint) members;
        mapping(uint => address) mapAddressMember; // This maps to the user

        // To calculate fair share of profit for a subscriber
        // The historical constant that is applied with (wnx0 + wnx1 + .... + wnxZ) 
        // Read more in the repo: https://github.com/ethereum-push-notification-system
        mapping(address => uint) memberLastUpdate;
    }

    // To keep track of channels 
    mapping(address => Channel) public channels;
    mapping(uint => address) public mapAddressChannels;
    uint public channelsCount;

    // Helper for calculating fair share of pool, group are all channels, renamed to avoid confusion
    uint public groupNormalizedWeight;
    uint public groupHistoricalZ; // Abbre
    uint public groupLastUpdate; // The last update block number, used to calculate fair share
    uint public groupFairShareCount; // They are alias to channels count but seperating them for brevity

    /* For maintaining the #DeFi finances
    */
    uint public poolFunds; // Always in DAI
    uint public ownerDaiFunds;

    /* for referencing AAVE, DAI and aDAI contracts.
     * used to earn interest on the pool of subscribers
     */
    address public lendingPoolProviderAddress;
    address public daiAddress;
    address public aDaiAddress;

    /* ***************
    * Events
    *************** */
    // For Public Key Registration Emit
    event PublicKeyRegistered(address indexed owner, bytes publickey);

    // Channel Related | // This Event is listened by on All Infra Services
    event AddChannel(address indexed channel, bytes identity);
    event UpdateChannel(address indexed channel, bytes identity);
    event DeactivateChannel(address indexed channel);

    // Subscribe / Unsubscribe | This Event is listened by on All Infra Services
    event Subscribe(address indexed channel, address indexed user);
    event Unsubscribe(address indexed channel, address indexed user);

    // Send Notification | This Event is listened by on All Infra Services
    event SendNotification(address indexed channel, address indexed recipient, bytes identity);

    // Emit Claimed Interest
    event InterestClaimed(address indexed user, uint indexed amount);

    // Withdrawl Related
    event Donation(address indexed donator, uint amt);
    event Withdrawal(address indexed to, address token, uint amount);

    /* ***************
    * CONSTRUCTORS, MODIFIERS AND FUNCTIONS
    *************** */
//    constructor (address _lendingPoolProviderAddress, address _daiAddress, address _aDaiAddress, uint _referralCode) public {
//        // Set aDai, Dai and Lending Pool Address
//        lendingPoolProviderAddress = _lendingPoolProviderAddress;
//        daiAddress = _daiAddress;
//        aDaiAddress = _aDaiAddress;
//        REFERRAL_CODE = _referralCode;
    constructor () public {
             // Set aDai, Dai and Lending Pool Address

    }

    initialize() external {
        lendingPoolProviderAddress = address(0x1c8756FD2B28e9426CDBDcC7E3c4d64fa9A54728);
        daiAddress = address(0xf80A32A835F79D7787E8a8ee5721D0fEaFd78108);
        aDaiAddress = address(0xcB1Fe6F440c49E9290c3eb7f158534c2dC374201);

        // Do fair share update
        groupLastUpdate = block.number;
        groupNormalizedWeight = ADJUST_FOR_FLOAT; // Always Starts with 1 * ADJUST FOR FLOAT

        // Add EPNS Channels
        // First is for all users
        // Second is all channel alerter, amount deposited for both is 0
        // to save gas, emit both the events out
        emit AddChannel(0x0000000000000000000000000000000000000000, "QmTCKYL2HRbwD6nGNvFLe4wPvDNuaYGr6RiVeCvWjVpn5s");
        emit AddChannel(msg.sender, "QmSbRT16JVF922yAB26YxWFD6DmGsnSHm8VBrGUQnXTS74");

        // Also, call the EPNSServer contract to which the server is listening, will be removed after alpha
        // Create Channel
        _createChannel(0x0000000000000000000000000000000000000000, ChannelType.NonInterestBearing, 0);
        _createChannel(msg.sender, ChannelType.NonInterestBearing, 0);
        }

    receive() external payable {}

    fallback() external {}

    // Modifiers
    /// @dev Testnet only function to check permission from owner
    modifier onlyChannelizationWhitelist(address _addr) {
        require ((msg.sender == owner() || channelizationWhitelist[_addr] == true), "User not in Channelization Whitelist");
        _;
    }

    modifier onlyValidUser(address _addr) {
        require( users[_addr].userActivated == true, "User not activated yet" );
        _;
    }

    modifier onlyUserWithNoChannel() {
        require( users[msg.sender].channellized == false, "User already a Channel Owner" );
        _;
    }

    modifier onlyValidChannel(address _channel) {
        require( users[_channel].channellized == true, "Channel doesn't Exists" );
        _;
    }

    modifier onlyActivatedChannels(address _channel) {
        require( users[_channel].channellized == true && channels[_channel].deactivated == false, "Channel deactivated or doesn't exists");
        _;
    }

    modifier onlyChannelOwner(address _channel) {
        require(
            ((users[_channel].channellized == true && msg.sender == _channel) || (msg.sender == owner() && _channel == 0x0000000000000000000000000000000000000000)),
            "Channel doesn't Exists"
        );
        _;
    }

    modifier onlySubscribed(address _channel, address _subscriber) {
        require( channels[_channel].memberExists[_subscriber] == true, "Subscriber doesn't Exists" );
        _;
    }

    modifier onlyNonOwnerSubscribed(address _channel, address _subscriber) {
        require( _channel != _subscriber && channels[_channel].memberExists[_subscriber] == true, "Either Channel Owner or Not Subscribed" );
        _;
    }

    modifier onlyNonSubscribed(address _channel, address _subscriber) {
        require( channels[_channel].memberExists[_subscriber] == false, "Subscriber already Exists" );
        _;
    }

    modifier onlyNonGraylistedChannel(address _channel, address _user) {
        require( users[_user].graylistedChannels[_channel] == false, "Channel is graylisted" );
        _;
    }

    /// @dev Testnet only function to enable owner permission for channelizationWhitelist addition
    function addToChannelizationWhitelist(address _addr) external onlyOwner {
        channelizationWhitelist[_addr] = true;
    }

    /// @dev Testnet only function  to enable owner permission for channelizationWhitelist removal
    function removeFromChannelizationWhitelist(address _addr) external onlyOwner {
        channelizationWhitelist[_addr] = false;
    }

    /// @dev Performs action by the user themself to broadcast their public key
    function broadcastUserPublicKey(bytes calldata _publicKey) external {
        // Will save gas
        if (users[msg.sender].publicKeyRegistered == true) {
            // Nothing to do, user already registered
            return;
        }

        // broadcast it
        _broadcastPublicKey(msg.sender, _publicKey);
    }

    /// @dev Create channel with fees and public key
    function createChannelWithFeesAndPublicKey(bytes calldata _identity, bytes calldata _publickey)
    external onlyUserWithNoChannel onlyChannelizationWhitelist(msg.sender) {
        // Save gas, Emit the event out
        emit AddChannel(msg.sender, _identity);

        // Broadcast public key
        // @TODO Find a way to save cost

        // Will save gas
        if (users[msg.sender].publicKeyRegistered == false) {
            _broadcastPublicKey(msg.sender, _publickey);
        }

        // Bubble down to create channel
        _createChannelWithFees();
    }

    /// @dev Create channel with fees
    function createChannelWithFees(bytes calldata _identity) external onlyUserWithNoChannel onlyChannelizationWhitelist(msg.sender) {
        // Save gas, Emit the event out
        emit AddChannel(msg.sender, _identity);

        // Bubble down to create channel
        _createChannelWithFees();
    }

    /// @dev Deactivate channel
    function deactivateChannel() onlyActivatedChannels(msg.sender) external {
        channels[msg.sender].deactivated = true;
    }

    /// @dev delegate subscription to channel
    function subscribeWithPublicKeyDelegated(
        address _channel,
        address _user,
        bytes calldata _publicKey
    ) external onlyActivatedChannels(_channel) onlyNonGraylistedChannel(_channel, _user) {
        // Take delegation fees
        _takeDelegationFees();

        // Will save gas as it prevents calldata to be copied unless need be
        if (users[_user].publicKeyRegistered == false) {
            // broadcast it
            _broadcastPublicKey(msg.sender, _publicKey);
        }

        // Call actual subscribe
        _subscribe(_channel, _user);
    }

    /// @dev subscribe to channel delegated
    function subscribeDelegated(address _channel, address _user) external onlyActivatedChannels(_channel) onlyNonGraylistedChannel(_channel, _user) {
        // Take delegation fees
        _takeDelegationFees();

        // Call actual subscribe
        _subscribe(_channel, _user);
    }

    /// @dev subscribe to channel with public key
    function subscribeWithPublicKey(address _channel, bytes calldata _publicKey) onlyActivatedChannels(_channel) external {
        // Will save gas as it prevents calldata to be copied unless need be
        if (users[msg.sender].publicKeyRegistered == false) {

            // broadcast it
            _broadcastPublicKey(msg.sender, _publicKey);
        }

        // Call actual subscribe
        _subscribe(_channel, msg.sender);
    }

    /// @dev subscribe to channel
    function subscribe(address _channel) onlyActivatedChannels(_channel) external {
        // Call actual subscribe
        _subscribe(_channel, msg.sender);
    }

    /// @dev to unsubscribe from channel
    function unsubscribe(address _channel) external onlyValidChannel(_channel) onlyNonOwnerSubscribed(_channel, msg.sender) returns (uint ratio) {
        // Add the channel to gray list so that it can't subscriber the user again as delegated
        User storage user = users[msg.sender];

        // Treat it as graylisting
        user.graylistedChannels[_channel] = true;

        // first get ratio of earning
        ratio = 0;
        ratio = calcSingleChannelEarnRatio(_channel, msg.sender, block.number);

        // Take the fair share out

        // Remove the mappings and cleanup
        // a bit tricky, swap and delete to maintain mapping 
        // Remove From Users mapping
        // Find the id of the channel and swap it with the last id, use channel.memberCount as index
        // Slack too deep fix
        // address usrSubToSwapAdrr = user.mapAddressSubscribed[user.subscribedCount];
        // uint usrSubSwapID = user.subscribed[_channel];

        // // swap to last one and then
        // user.subscribed[usrSubToSwapAdrr] = usrSubSwapID;
        // user.mapAddressSubscribed[usrSubSwapID] = usrSubToSwapAdrr;

        user.subscribed[user.mapAddressSubscribed[user.subscribedCount]] = user.subscribed[_channel];
        user.mapAddressSubscribed[user.subscribed[_channel]] = user.mapAddressSubscribed[user.subscribedCount];

        // delete the last one and substract
        delete(user.subscribed[_channel]);
        delete(user.mapAddressSubscribed[user.subscribedCount]);
        user.subscribedCount = user.subscribedCount.sub(1);

        // Remove from Channels mapping
        Channel storage channel = channels[_channel];

        // Set additional flag to false
        channel.memberExists[msg.sender] = false;

        // Find the id of the channel and swap it with the last id, use channel.memberCount as index
        // Slack too deep fix
        // address chnMemToSwapAdrr = channel.mapAddressMember[channel.memberCount];
        // uint chnMemSwapID = channel.members[msg.sender];

        // swap to last one and then
        channel.members[channel.mapAddressMember[channel.memberCount]] = channel.members[msg.sender];
        channel.mapAddressMember[channel.members[msg.sender]] = channel.mapAddressMember[channel.memberCount];

        // delete the last one and substract
        delete(channel.members[msg.sender]);
        delete(channel.mapAddressMember[channel.memberCount]);
        channel.memberCount = channel.memberCount.sub(1);

        // Next readjust fair share
        (
        channels[_channel].channelFairShareCount,
        channels[_channel].channelHistoricalZ,
        channels[_channel].channelLastUpdate
        ) = _readjustFairShareOfSubscribers(
            SubscriberAction.SubscriberRemoved,
            channels[_channel].channelFairShareCount,
            channels[_channel].channelHistoricalZ,
            channels[_channel].channelLastUpdate
        );

        // Next calculate and send the fair share earning of the user from this channel
        if (channel.channelType == ChannelType.InterestBearingChannel) {
            _withdrawFundsFromPool(ratio);
        }

        // Emit it
        emit Unsubscribe(_channel, msg.sender);
    }

    /// @dev to claim fair share of all earnings
    function claimFairShare() onlyValidUser(msg.sender) external returns (uint ratio){
        // Calculate entire FS Share, since we are looping for reset... let's calculate over there
        ratio = 0;

        // Reset member last update for every channel that are interest bearing
        // WARN: This unbounded for loop is an anti-pattern
        for (uint i = 0; i < users[msg.sender].subscribedCount; i++) {
            address channel = users[msg.sender].mapAddressSubscribed[i];

            if (channels[channel].channelType == ChannelType.InterestBearingChannel) {
                // Reset last updated block
                channels[channel].memberLastUpdate[msg.sender] = block.number;

                // Next readjust fair share and that's it
                (
                channels[channel].channelFairShareCount,
                channels[channel].channelHistoricalZ,
                channels[channel].channelLastUpdate
                ) = _readjustFairShareOfSubscribers(
                    SubscriberAction.SubscriberUpdated,
                    channels[channel].channelFairShareCount,
                    channels[channel].channelHistoricalZ,
                    channels[channel].channelLastUpdate
                );

                // Calculate share
                uint individualChannelShare = calcSingleChannelEarnRatio(channel, msg.sender, block.number);
                ratio = ratio.add(individualChannelShare);
            }

        }

        // Finally, withdraw for user
        _withdrawFundsFromPool(ratio);
    }

    /* @dev to send message to reciepient of a group, the first digit of msg type contains rhe push server flag
    ** So msg type 1 with using push is 11, without push is 10, in the future this can also be 12 (silent push)
    */
    function sendNotification(
        address _recipient,
        bytes calldata _identity
    ) external onlyChannelOwner(msg.sender) {
        // Just check if the msg is a secret, if so the user public key should be in the system
        // On second thought, leave it upon the channel, they might have used an alternate way to 
        // encrypt the message using the public key

        // Emit the message out
        emit SendNotification(msg.sender, _recipient, _identity);
    }

    /// @dev to send message to reciepient of a group
    function sendNotificationOverrideChannel(
        address _channel,
        address _recipient,
        bytes calldata _identity
    ) external onlyChannelOwner(msg.sender) onlyOwner {
        // Emit the message out
        emit SendNotification(_channel, _recipient, _identity);
    }

    /// @dev to withraw funds coming from delegate fees
    function withdrawDaiFunds() external onlyOwner {
        // Get and transfer funds
        uint funds = ownerDaiFunds;
        IERC20(daiAddress).transferFrom(address(this), msg.sender, funds);

        // Rest funds to 0
        ownerDaiFunds = 0;

        // Emit Evenet
        emit Withdrawal(msg.sender, daiAddress, funds);
    }

    /// @dev to withraw funds coming from donate
    function withdrawEthFunds() external onlyOwner {
        uint bal = address(this).balance;

        payable(owner()).transfer(bal);

        // Emit Event
        emit Withdrawal(msg.sender, daiAddress, bal);
    }

    /// @dev To check if member exists
    function memberExists(address _user, address _channel) external view returns (bool subscribed) {
        subscribed = channels[_channel].memberExists[_user];
    }

    /// @dev To fetch subscriber address for a channel
    function getChannelSubscriberAddress(address _channel, uint _subscriberId) external view returns (address subscriber) {
        subscriber = channels[_channel].mapAddressMember[_subscriberId];
    }

    /// @dev To fetch user id for a subscriber of a channel
    function getChannelSubscriberUserID(address _channel, uint _subscriberId) external view returns (uint userId) {
        userId = channels[_channel].members[channels[_channel].mapAddressMember[_subscriberId]];
    }

    /// @dev donate functionality for the smart contract
    function donate() public payable {
        require(msg.value >= 0.001 ether, "Minimum Donation amount is 0.001 ether");

        // Emit Event
        emit Donation(msg.sender, msg.value);
    }

    /// @dev to get channel fair share ratio for a given block
    function getChannelFSRatio(address _channel, uint _block) public view returns (uint ratio) {
        // formula is ratio = da / z + (nxw)
        // d is the difference of blocks from given block and the last update block of the entire group 
        // a is the actual weight of that specific group
        // z is the historical constant
        // n is the number of channels 
        // x is the difference of blocks from given block and the last changed start block of group
        // w is the normalized weight of the groups
        uint d = _block.sub(channels[_channel].channelStartBlock); // _block.sub(groupLastUpdate);
        uint a = channels[_channel].channelWeight;
        uint z = groupHistoricalZ;
        uint n = groupFairShareCount;
        uint x = _block.sub(groupLastUpdate);
        uint w = groupNormalizedWeight;

        uint nxw = n.mul(x.mul(w));
        uint z_nxw = z.add(nxw);
        uint da = d.mul(a);

        ratio = (da.mul(ADJUST_FOR_FLOAT)).div(z_nxw);
    }

    /// @dev to get subscriber fair share ratio for a given channel at a block
    function getSubscriberFSRatio(
        address _channel,
        address _user,
        uint _block
    ) public view onlySubscribed(_channel, _user) returns (uint ratio) {
        // formula is ratio = d / z + (nx)
        // d is the difference of blocks from given block and the start block of subscriber 
        // z is the historical constant
        // n is the number of subscribers of channel
        // x is the difference of blocks from given block and the last changed start block of channel

        uint d = _block.sub(channels[_channel].memberLastUpdate[_user]);
        uint z = channels[_channel].channelHistoricalZ;
        uint x = _block.sub(channels[_channel].channelLastUpdate);

        uint nx = channels[_channel].channelFairShareCount.mul(x);

        ratio = (d.mul(ADJUST_FOR_FLOAT)).div(z.add(nx)); // == d / z + n * x
    }

    /* @dev to get the fair share of user for a single channel, different from subscriber fair share
     * as it's multiplication of channel fair share with subscriber fair share
     */
    function calcSingleChannelEarnRatio(
        address _channel,
        address _user,
        uint _block
    ) public view onlySubscribed(_channel, _user) returns (uint ratio) {
        // First get the channel fair share
        if (channels[_channel].channelType == ChannelType.InterestBearingChannel) {
            uint channelFS = getChannelFSRatio(_channel, _block);
            uint subscriberFS = getSubscriberFSRatio(_channel, _user, _block);

            ratio = channelFS.mul(subscriberFS).div(ADJUST_FOR_FLOAT);
        }
    }

    /// @dev to get the fair share of user overall
    function calcAllChannelsRatio(address _user, uint _block) onlyValidUser(_user) public view returns (uint ratio) {
        // loop all channels for the user
        uint subscribedCount = users[_user].subscribedCount;

        // WARN: This unbounded for loop is an anti-pattern
        for (uint i = 0; i < subscribedCount; i++) {
            if (channels[users[_user].mapAddressSubscribed[i]].channelType == ChannelType.InterestBearingChannel) {
                uint individualChannelShare = calcSingleChannelEarnRatio(users[_user].mapAddressSubscribed[i], _user, _block);
                ratio = ratio.add(individualChannelShare);
            }
        }
    }

    /// @dev Add the user to the ecosystem if they don't exists, the returned response is used to deliver a message to the user if they are recently added
    function _addUser(address _addr) private returns (bool userAlreadyAdded) {
        if (users[_addr].userActivated) {
            userAlreadyAdded = true;
        }
        else {
            // Activates the user
            users[_addr].userStartBlock = block.number;
            users[_addr].userActivated = true;
            mapAddressUsers[usersCount] = _addr;

            usersCount = usersCount.add(1);

            // Send Welcome Message
            emit SendNotification(owner(), _addr, EPNS_FIRST_MESSAGE_HASH);
        }
    }

    /* @dev Internal system to handle broadcasting of public key, 
    * is a entry point for subscribe, or create channel but is option
    */
    function _broadcastPublicKey(address _userAddr, bytes memory _publicKey) private {
        // Add the user, will do nothing if added already, but is needed before broadcast
        _addUser(_userAddr);

        // get address from public key
        address userAddr = getWalletFromPublicKey(_publicKey);

        if (_userAddr == userAddr) {
            // Only change it when verification suceeds, else assume the channel just wants to send group message
            users[userAddr].publicKeyRegistered = true;

            // Emit the event out
            emit PublicKeyRegistered(userAddr, _publicKey);
        }
        else {
            revert("Public Key Validation Failed");
        }
    }

    /// @dev Don't forget to add 0x into it
    function getWalletFromPublicKey (bytes memory _publicKey) public pure returns (address wallet) {
        if (_publicKey.length == 64) {
            wallet = address (uint160 (uint256 (keccak256 (_publicKey))));
        }
        else {
            wallet = 0x0000000000000000000000000000000000000000;
        }
    }

    /// @dev add channel with fees
    function _createChannelWithFees() private {
        // This module should be completely independent from the private _createChannel() so constructor can do it's magic
        // Get the approved allowance
        uint allowedAllowance = IERC20(daiAddress).allowance(msg.sender, address(this));

        // Check if it's equal or above Channel Pool Contribution
        require(
            allowedAllowance >= ADD_CHANNEL_MIN_POOL_CONTRIBUTION && allowedAllowance <= ADD_CHANNEL_MAX_POOL_CONTRIBUTION,
            "Insufficient Funds or max ceiling reached"
        );

        // Check and transfer funds
        IERC20(daiAddress).transferFrom(msg.sender, address(this), allowedAllowance);

        // Deposit funds to pool
        _depositFundsToPool(allowedAllowance);

        // // Generate a random allowed allowance, for testing Generates 50 to 25000 range
        // uint allowedAllowance = ((uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % 24950) + 50) * 10 ** 18;
        // poolFunds = poolFunds.add(allowedAllowance);
        // Testing Endss

        // Call Create Channel
        _createChannel(msg.sender, ChannelType.InterestBearingChannel, allowedAllowance);
    }

    /// @dev Create channel internal method that runs
    function _createChannel(address _channel, ChannelType _channelType, uint _amountDeposited) private {
        // Add the user, will do nothing if added already, but is needed for all outpoints
        bool userAlreadyAdded = _addUser(_channel);

        // Calculate channel weight
        uint _channelWeight = _amountDeposited.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

        // Next create the channel and mark user as channellized
        users[_channel].channellized = true;

        channels[_channel].poolContribution = _amountDeposited;
        channels[_channel].channelType = _channelType;
        channels[_channel].channelStartBlock = block.number;
        channels[_channel].channelWeight = _channelWeight;

        // Add to map of addresses and increment channel count
        mapAddressChannels[channelsCount] = _channel;
        channelsCount = channelsCount.add(1);

        // Readjust fair share if interest bearing
        if (_channelType == ChannelType.InterestBearingChannel) {
            (groupFairShareCount, groupNormalizedWeight, groupHistoricalZ, groupLastUpdate) = _readjustFairShareOfChannels(
                ChannelAction.ChannelAdded,
                _channelWeight,
                groupFairShareCount,
                groupNormalizedWeight,
                groupHistoricalZ,
                groupLastUpdate
            );
        }

        // If this is a new user than subscribe them to EPNS Channel
        if (userAlreadyAdded == false && _channel != 0x0000000000000000000000000000000000000000) {
            // Call actual subscribe, owner channel
            _subscribe(owner(), _channel);
        }

        // All Channels are subscribed to EPNS Alerter as well, unless it's the EPNS Alerter channel iteself
        if (_channel != 0x0000000000000000000000000000000000000000) {
            _subscribe(0x0000000000000000000000000000000000000000, _channel);
        }

        // Subscribe them to their own channel as well
        if (_channel != owner()) {
            _subscribe(_channel, _channel);
        }
    }

    /// @dev private function that eventually handles the subscribing onlyValidChannel(_channel)
    function _subscribe(address _channel, address _user) private onlyNonSubscribed(_channel, _user) {
        // Add the user, will do nothing if added already, but is needed for all outpoints
        _addUser(_user);

        User storage user = users[_user];
        Channel storage channel = channels[_channel];

        // treat the count as index and update user struct
        user.subscribed[_channel] = user.subscribedCount;
        user.mapAddressSubscribed[user.subscribedCount] = _channel;
        user.subscribedCount = user.subscribedCount.add(1); // Finally increment the subscribed count

        // Do the same for the channel to maintain sync, treat member count as index
        channel.members[_user] = channel.memberCount;
        channel.mapAddressMember[channel.memberCount] = _user;
        channel.memberCount = channel.memberCount.add(1); // Finally increment the member count

        // Set Additional flag for some conditions and set last update of member
        channel.memberLastUpdate[_user] = block.number;
        channel.memberExists[_user] = true;

        // Next readjust fair share and that's it
        (
        channels[_channel].channelFairShareCount,
        channels[_channel].channelHistoricalZ,
        channels[_channel].channelLastUpdate
        ) = _readjustFairShareOfSubscribers(
            SubscriberAction.SubscriberAdded,
            channels[_channel].channelFairShareCount,
            channels[_channel].channelHistoricalZ,
            channels[_channel].channelLastUpdate
        );

        // Emit it
        emit Subscribe(_channel, _user);
    }

    /// @dev charge delegation fee, small enough for serious players but thwarts bad actors
    function _takeDelegationFees() private {
        // Check and transfer funds
        // require( IERC20(daiAddress).transferFrom(msg.sender, address(this), DELEGATED_CONTRACT_FEES), "Insufficient Funds");
        IERC20(daiAddress).transferFrom(msg.sender, address(this), DELEGATED_CONTRACT_FEES);

        // Add it to owner kitty
        ownerDaiFunds.add(DELEGATED_CONTRACT_FEES);
    }

    /// @dev deposit funds to pool
    function _depositFundsToPool(uint amount) private {
        // Got the funds, add it to the channels dai pool
        poolFunds = poolFunds.add(amount);

        // Next swap it via AAVE for aDAI
        // mainnet address, for other addresses: https://docs.aave.com/developers/developing-on-aave/deployed-contract-instances
        ILendingPoolAddressesProvider provider = ILendingPoolAddressesProvider(lendingPoolProviderAddress);
        ILendingPool lendingPool = ILendingPool(provider.getLendingPool());
        IERC20(daiAddress).approve(provider.getLendingPoolCore(), amount);

        // Deposit to AAVE 
        lendingPool.deposit(daiAddress, amount, uint16(REFERRAL_CODE)); // set to 0 in constructor presently
    }

    /// @dev withdraw funds from pool
    function _withdrawFundsFromPool(uint ratio) private nonReentrant {
        uint totalBalanceWithProfit = IERC20(aDaiAddress).balanceOf(address(this));

        // // Random for testing
        // uint totalBalanceWithProfit = ((uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % 24950) + 50) * 10 ** 19; // 10 times
        // // End Testing

        uint totalProfit = totalBalanceWithProfit.sub(poolFunds);
        uint userAmount = totalProfit.mul(ratio);

        // adjust poolFunds first
        uint userAmountAdjusted = userAmount.div(ADJUST_FOR_FLOAT);
        poolFunds = poolFunds.sub(userAmountAdjusted);

        // Add to interest claimed
        usersInterestClaimed[msg.sender] = usersInterestClaimed[msg.sender].add(userAmountAdjusted);

        // Finally transfer
        IERC20(aDaiAddress).transfer(msg.sender, userAmountAdjusted);

        // Emit Event
        emit InterestClaimed(msg.sender, userAmountAdjusted);
    }

    /// @dev readjust fair share runs on channel addition, removal or update of channel
    function _readjustFairShareOfChannels(
        ChannelAction _action,
        uint _channelWeight,
        uint _groupFairShareCount,
        uint _groupNormalizedWeight,
        uint _groupHistoricalZ,
        uint _groupLastUpdate
    )
    private
    view
    returns (
        uint groupNewCount,
        uint groupNewNormalizedWeight,
        uint groupNewHistoricalZ,
        uint groupNewLastUpdate
    )
    {
        // readjusts the group count and do deconstruction of weight
        uint groupModCount = _groupFairShareCount;
        uint prevGroupCount = groupModCount;

        uint totalWeight;
        uint adjustedNormalizedWeight = _groupNormalizedWeight; //_groupNormalizedWeight;

        // Increment or decrement count based on flag
        if (_action == ChannelAction.ChannelAdded) {
            groupModCount = groupModCount.add(1);

            totalWeight = adjustedNormalizedWeight.mul(prevGroupCount);
            totalWeight = totalWeight.add(_channelWeight);
        }
        else if (_action == ChannelAction.ChannelRemoved) {
            groupModCount = groupModCount.sub(1);

            totalWeight = adjustedNormalizedWeight.mul(prevGroupCount);
            totalWeight = totalWeight.sub(_channelWeight);
        }
        else if (_action == ChannelAction.ChannelUpdated) {
            totalWeight = adjustedNormalizedWeight.mul(prevGroupCount.sub(1));
            totalWeight = totalWeight.add(_channelWeight);
        }
        else {
            revert("Invalid Channel Action");
        }

        // now calculate the historical constant
        // z = z + nxw
        // z is the historical constant
        // n is the previous count of group fair share
        // x is the differential between the latest block and the last update block of the group
        // w is the normalized average of the group (ie, groupA weight is 1 and groupB is 2 then w is (1+2)/2 = 1.5)
        uint n = groupModCount;
        uint x = block.number.sub(_groupLastUpdate);
        uint w = totalWeight.div(groupModCount);
        uint z = _groupHistoricalZ;

        uint nx = n.mul(x);
        uint nxw = nx.mul(w);

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

    /// @dev readjust fair share runs on user addition or removal
    function _readjustFairShareOfSubscribers(
        SubscriberAction action,
        uint _channelFairShareCount,
        uint _channelHistoricalZ,
        uint _channelLastUpdate
    )
    private
    view
    returns (
        uint channelNewFairShareCount,
        uint channelNewHistoricalZ,
        uint channelNewLastUpdate
    )
    {
        uint channelModCount = _channelFairShareCount;
        uint prevChannelCount = channelModCount;

        // Increment or decrement count based on flag
        if (action == SubscriberAction.SubscriberAdded) {
            channelModCount = channelModCount.add(1);
        }
        else if (action == SubscriberAction.SubscriberRemoved) {
            channelModCount = channelModCount.sub(1);
        }
        else if (action == SubscriberAction.SubscriberUpdated) {
            // do nothing, it's happening after a reset of subscriber last update count

        }
        else {
            revert("Invalid Channel Action");
        }

        // to calculate the historical constant
        // z = z + nx
        // z is the historical constant
        // n is the total prevoius subscriber count
        // x is the difference bewtween the last changed block and the current block
        uint x = block.number.sub(_channelLastUpdate);
        uint nx = prevChannelCount.mul(x);
        uint z = _channelHistoricalZ.add(nx);

        // Define Values
        channelNewFairShareCount = channelModCount;
        channelNewHistoricalZ = z;
        channelNewLastUpdate = block.number;
    }
}