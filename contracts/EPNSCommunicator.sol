pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;

// SPDX-License-Identifier: MIT

/**
 * EPNS Communicator, as the name suggests, is more of a Communictation Layer
 * between END USERS and EPNS Core Protocol.
 * The Communicator Protocol is comparatively much simpler & involves basic
 * details, specifically about the USERS of the Protocols

 * Some imperative functionalities that the EPNS Communicator Protocol allows
 * are Subscribing to a particular channel, Unsubscribing a channel, Sending
 * Notifications to a particular recipient etc.
**/

// Essential Imports
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract EPNSCommunicator is Initializable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    enum SubscriberAction {
        SubscriberRemoved,
        SubscriberAdded,
        SubscriberUpdated
    }
    /**
     * @notice User Struct that involves imperative details about
     * a specific User.
     **/
    struct User {
        // @notice Depicts whether or not a user is ACTIVE
        bool userActivated;

        // @notice Will be false until public key is emitted
        bool publicKeyRegistered;

        // @notice Marks if a user has opened a channel
        bool channellized;

        // @notice Events should not be polled before this block as user doesn't exist
        uint256 userStartBlock;

        // @notice Keep track of subscribers
        uint256 subscribedCount;

        /**
         * Depicts if User subscribed to a Specific Channel Address
         * 1 -> User is Subscribed
         * 0 -> User is NOT SUBSCRIBED
         **/
        mapping(address => uint8) isSubscribed; // (1-> True. 0-> False )

        // Keeps track of all subscribed channels
        mapping(address => uint256) subscribed;
        mapping(uint256 => address) mapAddressSubscribed;
    }

    /** MAPPINGS **/
    mapping(address => User) public users;
    mapping(uint256 => address) public mapAddressUsers;
    mapping(address => mapping(address => bool))
        public delegatedNotificationSenders;
    mapping(address => uint256) public nonces;
    mapping(address => mapping(address => string)) public userToChannelNotifs;

    /** STATE VARIABLES **/
    address public governance;
    address public pushChannelAdmin;
    uint256 public usersCount;
    bool public isMigrationComplete;
    address public EPNSCoreAddress;
    string public constant name = "EPNS COMMUNICATOR";
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,uint256 chainId,address verifyingContract)"
        );
    bytes32 public constant SUBSCRIBE_TYPEHASH =
        keccak256("Subscribe(address channel,uint256 nonce,uint256 expiry)");
    bytes32 public constant UNSUBSCRIBE_TYPEHASH =
        keccak256("Unsubscribe(address channel,uint256 nonce,uint256 expiry)");
    bytes32 public constant SEND_NOTIFICATION_TYPEHASH =
        keccak256(
            "SendNotification(address channel,address delegate,address recipient,bytes identity,uint256 nonce,uint256 expiry)"
        );
    /** EVENTS **/
    event AddDelegate(address channel, address delegate); // Addition/Removal of Delegete Events
    event RemoveDelegate(address channel, address delegate);
    event Subscribe(address indexed channel, address indexed user); // Subscribe / Unsubscribe | This Event is listened by on All Infra Services
    event Unsubscribe(address indexed channel, address indexed user);
    event PublicKeyRegistered(address indexed owner, bytes publickey);
    event SendNotification(
        address indexed channel,
        address indexed recipient,
        bytes identity
    );
    event UserNotifcationSettingsAdded(
        address _channel,
        address _user,
        uint256 _notifID,
        string _notifSettings
    );

    /** MODIFIERS **/

    modifier onlyPushChannelAdmin() {
        require(msg.sender == pushChannelAdmin, "EPNSCore::onlyPushChannelAdmin, user is not pushChannelAdmin");
        _;
    }

    modifier onlyEPNSCore() {
        require(msg.sender == EPNSCoreAddress, "Caller is NOT EPNSCore");
        _;
    }

    modifier onlyValidUser(address _user) {
        require(users[_user].userActivated, "User not activated yet");
        _;
    }

    modifier onlyUserWithNoChannel() {
        require(
            !users[msg.sender].channellized,
            "User already a Channel Owner"
        );
        _;
    }

    // TBD - Should "recipient == signator" be a check for this modifier?
    modifier sendNotifViaSignRequirements(
        address _channel,
        address _notificationSender,
        address _recipient,
        address signatory
    ) {
        require(
            (_channel == signatory) ||
                (delegatedNotificationSenders[_channel][_notificationSender] &&
                    _notificationSender == signatory) ||
                (_recipient == signatory),
            "SendNotif Via Sig Error: Invalid Channel, Delegate Or Subscriber"
        );
        _;
    }

    function initialize(address _pushChannelAdmin) public initializer returns (bool) {
        pushChannelAdmin = _pushChannelAdmin;
        governance = pushChannelAdmin;
        return true;
    }

    function setEPNSCoreAddress(address _coreAddress) external onlyPushChannelAdmin {
        EPNSCoreAddress = _coreAddress;
    }

    function setGovernanceAddress(address _governanceAddress) external onlyPushChannelAdmin{
      governance = _governanceAddress;
    }

    function transferpushChannelAdminControl(address _newAdmin) public onlyPushChannelAdmin {
        require(_newAdmin != address(0), "Invalid Address");
        require(_newAdmin != pushChannelAdmin, "New pushChannelAdmin cannot be current pushChannelAdmin");
        pushChannelAdmin = _newAdmin;
    }

    function completeMigration() external onlyPushChannelAdmin{
        isMigrationComplete = true;
    }

    /****************

    => SUBSCRIBE & UNSUBSCRIBE FUNCTIOANLTIES <=

    ****************/

    /**
     * @notice Helper function to check if User is Subscribed to a Specific Address
     * @param _channel address of the channel that the user is subscribing to
     * @param _user address of the Subscriber
     * @return isSubscriber True if User is actually a subscriber of a Channel
     **/
    function isUserSubscribed(address _channel, address _user)
        public
        view
        returns (bool isSubscriber)
    {
        User storage user = users[_user];
        if (user.isSubscribed[_channel] == 1) {
            isSubscriber = true;
        }
    }

    /**
     * @notice External Subscribe Function that allows users to Diretly interact with the Base Subscribe function
     * @dev Subscribers the caller of the function to a channel - Takes into Consideration the "msg.sender"
     * @param _channel address of the channel that the user is subscribing to
     **/
    function subscribe(address _channel) external returns (bool) {
        // Call actual subscribe
        _subscribe(_channel, msg.sender);
        return true;
    }

    /**
     * @notice This Function allows users unsubscribe from a List of Channels at once
     *
     * @param _channelList array of addresses of the channels that the user wishes to Subscribe
     **/
    function batchSubscribe(address[] calldata _channelList)
        external
        returns (bool)
    {
        for (uint256 i = 0; i < _channelList.length; i++) {
            _subscribe(_channelList[i], msg.sender);
        }
        return true;
    }

    /**
     * @notice This Function helps in migrating the already existing Subscriber's data to the New protocol
     *
     * @dev     Can only be called by pushChannelAdmin
     *          Can only be called if the Migration is not yet complete, i.e., "isMigrationComplete" boolean must be false
     *          Subscribers the Users to the respective Channels as per the arguments passed to the function
     * @param _startIndex       starting Index for the LOOP
     * @param _endIndex         Last Index for the LOOP
     * @param _channelList array of addresses of the channels
     * @param _usersList   array of addresses of the Users or Subscribers of the Channels
     **/

    function migrateSubscribeData(
        uint256 _startIndex,
        uint256 _endIndex,
        address[] calldata _channelList,
        address[] calldata _usersList
    ) external onlyPushChannelAdmin returns (bool) {
        require(
            !isMigrationComplete,
            "Migration of Subscribe Data is Complete Already"
        );
        require(
            _channelList.length == _usersList.length,
            "Unequal Arrays passed as Argument"
        );

        for (uint256 i = _startIndex; i < _endIndex; i++) {
            if(isUserSubscribed(_channelList[i], _usersList[i])){
                continue;
            }else{
                _subscribe(_channelList[i], _usersList[i]);
            }
        }
        return true;
    }

    /**
     * @notice Base Subscribe Function that allows users to Subscribe to a Particular Channel and Keeps track of it
     * @dev Initializes the User Struct with crucial details about the Channel Subscription
     * @param _channel address of the channel that the user is subscribing to
     * @param _user address of the Subscriber
     **/
    function _subscribe(address _channel, address _user) private {
        require(
            !isUserSubscribed(_channel, _user),
            "User is Already Subscribed to this Channel"
        );
        // Add the user, will do nothing if added already, but is needed for all outpoints
        _addUser(_user);

        User storage user = users[_user];
        // Important Details to be stored on Communicator
        // a. Mark a User as a Subscriber for a Specific Channel
        // b. Update Channel's Subscribed Count for User - TBD-not sure yet
        // c. Update User Subscribed Count for Channel
        // d. Usual Subscribe Track

        user.isSubscribed[_channel] = 1;

        // treat the count as index and update user struct
        // TBD - NOT SURE IF THE LINES BELOW SERVE A SPECIFIC PURPOSE YET
        user.subscribed[_channel] = user.subscribedCount;
        user.mapAddressSubscribed[user.subscribedCount] = _channel;

        user.subscribedCount = user.subscribedCount.add(1); // Finally increment the subscribed count

        // Emit it
        emit Subscribe(_channel, _user);
    }

    /**
     * @notice Subscribe Function through Meta TX
     * @dev Takes into Consideration the Sign of the User
     **/
    function subscribeBySignature(
        address channel,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                getChainId(),
                address(this)
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(SUBSCRIBE_TYPEHASH, channel, nonce, expiry)
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "Invalid signature");
        require(nonce == nonces[signatory]++, "Invalid nonce");
        require(now <= expiry, "Signature expired");
        _subscribe(channel, signatory);
    }

    /**
     * @notice AllowsEPNSCore contract to call the Base Subscribe function whenever a User Creates his/her own Channel.
     *         This ensures that the Channel Owner is automatically subscribed to some imperative EPNS Channels as well as his/her own Channel.
     *
     * @dev    Only Callable by the EPNSCore. This is to ensure that Users should only able to Subscribe for their own addresses.
     *         The caller of the main Subscribe function should Either Be the USERS themselves(for their own addresses) or the EPNSCore contract
     *
     * @param _channel address of the channel that the user is subscribing to
     * @param _user address of the Subscriber of a Channel
     **/
    function subscribeViaCore(address _channel, address _user)
        external
        onlyEPNSCore
        returns (bool)
    {
        _subscribe(_channel, _user);
        return true;
    }

    /**
     * @notice External Unsubcribe Function that allows users to Diretly interact with the Base Unsubscribe function
     * @dev UnSubscribers the caller of the function to a channl - Takes into Consideration the "msg.sender"
     * @param _channel address of the channel that the user is subscribing to
     **/
    function unsubscribe(address _channel) external {
        // Call actual unsubscribe
        _unsubscribe(_channel, msg.sender);
    }

    /**
     * @notice This Function that allows users unsubscribe from a List of Channels at once
     *
     * @param _channelList array of addresses of the channels that the user wishes to Unsubscribe
     **/
    function batchUnsubscribe(address[] calldata _channelList)
        external
        returns (bool)
    {
        for (uint256 i = 0; i < _channelList.length; i++) {
            _unsubscribe(_channelList[i], msg.sender);
        }
        return true;
    }

    /**
     * @notice Base Usubscribe Function that allows users to UNSUBSCRIBE from a Particular Channel and Keeps track of it
     * @dev Modifies the User Struct with crucial details about the Channel Unsubscription
     * @param _channel address of the channel that the user is subscribing to
     * @param _user address of the Subscriber
     **/
    function _unsubscribe(address _channel, address _user) private {
        require(
            isUserSubscribed(_channel, _user),
            "User is NOT Subscribed to the Channel Yet"
        );
        // Add the channel to gray list so that it can't subscriber the user again as delegated
        User storage user = users[_user];

        user.isSubscribed[_channel] = 0;
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

        user.subscribed[user.mapAddressSubscribed[user.subscribedCount]] = user
            .subscribed[_channel];
        user.mapAddressSubscribed[user.subscribed[_channel]] = user
            .mapAddressSubscribed[user.subscribedCount];

        // delete the last one and substract
        delete (user.subscribed[_channel]);
        delete (user.mapAddressSubscribed[user.subscribedCount]);
        user.subscribedCount = user.subscribedCount.sub(1);

        // Emit it
        emit Unsubscribe(_channel, _user);
    }

    /**
     * @notice Unsubscribe Function through Meta TX
     * @dev Takes into Consideration the Signer of the transactioner
     **/
    function unsubscribeBySignature(
        address channel,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                getChainId(),
                address(this)
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(UNSUBSCRIBE_TYPEHASH, channel, nonce, expiry)
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "Invalid signature");
        require(nonce == nonces[signatory]++, "Invalid nonce");
        require(now <= expiry, "Signature expired");
        _unsubscribe(channel, signatory);
    }

    /* **************

    => PUBLIC KEY BROADCASTING & USER ADDING FUNCTIONALITIES <=

    *************** */

    /**
     * @notice The _addUser functions activates a particular User's Address in the Protocol and Keeps track of the Total User Count
     * @dev It executes its main actions only if the User is not activated yet. It does nothing if an address has already been added.
     * @param _user address of the user
     * @return userAlreadyAdded returns whether or not a user is already added.
     **/
    function _addUser(address _user) private returns (bool userAlreadyAdded) {
        if (users[_user].userActivated) {
            userAlreadyAdded = true;
        } else {
            // Activates the user
            users[_user].userStartBlock = block.number;
            users[_user].userActivated = true;
            mapAddressUsers[usersCount] = _user;

            usersCount = usersCount.add(1);
        }
    }

    /* @dev Internal system to handle broadcasting of public key,
     * is a entry point for subscribe, or create channel but is option
     */
    function _broadcastPublicKey(address _userAddr, bytes memory _publicKey)
        private
    {
        // Add the user, will do nothing if added already, but is needed before broadcast
        _addUser(_userAddr);

        // get address from public key
        address userAddr = getWalletFromPublicKey(_publicKey);

        if (_userAddr == userAddr) {
            // Only change it when verification suceeds, else assume the channel just wants to send group message
            users[userAddr].publicKeyRegistered = true;

            // Emit the event out
            emit PublicKeyRegistered(userAddr, _publicKey);
        } else {
            revert("Public Key Validation Failed");
        }
    }

    /// @dev Don't forget to add 0x into it
    function getWalletFromPublicKey(bytes memory _publicKey)
        public
        pure
        returns (address wallet)
    {
        if (_publicKey.length == 64) {
            wallet = address(uint160(uint256(keccak256(_publicKey))));
        } else {
            wallet = 0x0000000000000000000000000000000000000000;
        }
    }

    /// @dev Performs action by the user themself to broadcast their public key
    function broadcastUserPublicKey(bytes calldata _publicKey) external {
        // Will save gas
        if (users[msg.sender].publicKeyRegistered) {
            // Nothing to do, user already registered
            return;
        }

        // broadcast it
        _broadcastPublicKey(msg.sender, _publicKey);
    }

    /* **************

    => SEND NOTIFICATION FUNCTIONALITIES <=

    *************** */

    /**
     * @notice Allows a Channel Owner to ADD a Delegate who will be able to send Notification on the Channel's Behalf
     * @dev This function will be only be callable by the Channel Owner from the EPNSCore contract.
     *      The verification of whether or not a Channel Address is actually the owner of the Channel, will be done via the PUSH NODES
     * @param _delegate address of the delegate who is allowed to Send Notifications
     **/
    function addDelegate(address _delegate) external {
        delegatedNotificationSenders[msg.sender][_delegate] = true;
        emit AddDelegate(msg.sender, _delegate);
    }

    /**
     * @notice Allows a Channel Owner to Remove a Delegate's Permission to Send Notification
     * @dev This function will be only be callable by the Channel Owner from the EPNSCore contract.
     *      The verification of whether or not a Channel Address is actually the owner of the Channel, will be done via the PUSH NODES
     * @param _delegate address of the delegate who is allowed to Send Notifications
     **/
    function removeDelegate(address _delegate) external {
        delegatedNotificationSenders[msg.sender][_delegate] = false;
        emit RemoveDelegate(msg.sender, _delegate);
    }

    /***
      THREE main CALLERS for this function-
        1. Channel Owner sends Notif to Recipients
        2. Delegatee of Channel sends Notif to Recipients
        3. Recipients sends Notifs to Themselvs via a Channel
    <------------------------------------------------------------------------------------->

     * When a CHANNEL OWNER Calls the Function and sends a Notif-> We check "if (channel owner is the caller) and if(Is Channel Valid)"
     * NOTE - This check is performed via the PUSH NODES
     * When a Delegatee wants to send Notif to Recipient-> We check "if(delegate is the Caller) and If( Is delegatee Valid)":
     * When Recipient wants to Send a Notif to themselves -> We check that the If(Caller of the function is Recipient himself)
    **/

    function _checkNotifRequirements
    (
      address _channel,
      address _notificationSender,
      address _recipient
    ) private view
    {
      require(
          (_channel == 0x0000000000000000000000000000000000000000 &&
              msg.sender == pushChannelAdmin) ||
              (_channel == msg.sender) ||
              (delegatedNotificationSenders[_channel][_notificationSender] &&
                  msg.sender == _notificationSender) ||
              (_recipient == msg.sender),
          "SendNotif Error: Invalid Channel, Delegate or Subscriber"
      );
    }
    /**
     * @notice Allows a Channel Owners, Delegates as well as Users to send Notifications
     * @dev Emits out notification details once all the requirements are passed.
     * @param _channel address of the Channel
     * @param _delegate address of the delegate who is allowed to Send Notifications
     * @param _recipient address of the reciever of the Notification
     * @param _identity Info about the Notification
     **/
    function sendNotification(
        address _channel,
        address _delegate,
        address _recipient,
        bytes memory _identity
    ) public{
        _checkNotifRequirements(_channel, _delegate, _recipient);
        // Emit the message out
        emit SendNotification(_channel, _recipient, _identity);
    }

    /**
     * @notice Base Notification Function that Allows a Channel Owners, Delegates as well as Users to send Notifications
     *
     * @dev   Specifically designed to be called via the EIP 712 send notif function.
     *        Takes into consideration the Signatory address to perform all the imperative checks
     *
     * @param _channel address of the Channel
     * @param _delegate address of the delegate who is allowed to Send Notifications
     * @param _recipient address of the reciever of the Notification
     * @param _signatory address of the SIGNER of the Send Notif Function call transaction
     * @param _identity Info about the Notification
     **/
    function _sendNotification(
        address _channel,
        address _delegate,
        address _recipient,
        address _signatory,
        bytes calldata _identity
    )
        private
        sendNotifViaSignRequirements(
            _channel,
            _delegate,
            _recipient,
            _signatory
        )
    {
        // Emit the message out
        emit SendNotification(_channel, _recipient, _identity);
    }

    /**
     * @notice Meta transaction function for Sending Notifications
     * @dev   Allows the Caller to Simply Sign the transaction to initiate the Send Notif Function
     **/

    function sendNotifBySig(
        address _channel,
        address _delegate,
        address _recipient,
        bytes calldata _identity,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                getChainId(),
                address(this)
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(
                SEND_NOTIFICATION_TYPEHASH,
                _channel,
                _delegate,
                _recipient,
                _identity,
                nonce,
                expiry
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "Invalid signature");
        require(nonce == nonces[signatory]++, "Invalid nonce");
        require(now <= expiry, "Signature expired");
        _sendNotification(
            _channel,
            _delegate,
            _recipient,
            signatory,
            _identity
        );
    }

    /* **************

    => User Notification Settings Function <=
    *************** */

    /**
     * @notice  Allows Users to Create and Subscribe to a Specific Notication Setting for a Channel.
     * @dev     Updates the userToChannelNotifs mapping to keep track of a User's Notification Settings for a Specific Channel
     *
     *          Deliminated Notification Settings string contains -> Decimal Representation Notif Settings + Notification Settings
     *          For instance, for a Notif Setting that looks like -> 3+1-0+2-0+3-1+4-98
     *          3 -> Decimal Representation of the Notification Options selected by the User
     *
     *          For Boolean Type Notif Options
     *          1-0 -> 1 stands for Option 1 - 0 Means the user didn't choose that Notif Option.
     *          3-1 stands for Option 3      - 1 Means the User Selected the 3rd boolean Option
     *
     *          For SLIDER TYPE Notif Options
     *          2-0 -> 2 stands for Option 2 - 0 is user's Choice
     *          4-98-> 4 stands for Option 4 - 98is user's Choice
     *
     * @param   _channel - Address of the Channel for which the user is creating the Notif settings
     * @param   _notifID- Decimal Representation of the Options selected by the user
     * @param   _notifSettings - Deliminated string that depicts the User's Notifcation Settings
     *
     **/

    function subscribeToSpecificNotification(
        address _channel,
        uint256 _notifID,
        string calldata _notifSettings
    ) external {
        require(
            isUserSubscribed(_channel, msg.sender),
            "User is Not Subscribed to this Channel"
        );
        string memory notifSetting = string(
            abi.encodePacked(Strings.toString(_notifID), "+", _notifSettings)
        );
        userToChannelNotifs[msg.sender][_channel] = notifSetting;
        emit UserNotifcationSettingsAdded(
            _channel,
            msg.sender,
            _notifID,
            notifSetting
        );
    }

    function getChainId() internal pure returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }
}
