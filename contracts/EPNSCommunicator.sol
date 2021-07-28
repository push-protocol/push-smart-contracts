pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;

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
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "hardhat/console.sol";

contract EPNSCommunicator is Initializable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /**
     * @notice User Struct that involves imperative details about
     * a specific User.
     **/
    struct User {
        bool userActivated; // Whether a user is activated or not
        bool publicKeyRegistered; // Will be false until public key is emitted
        bool channellized; // Marks if a user has opened a channel
        uint256 userStartBlock; // Events should not be polled before this block as user doesn't exist
        uint256 subscribedCount; // Keep track of subscribers
        uint256 subscriberCount; // (If User is Channel), Keep track of Total Subscriber for a Channel Address
        mapping(address => uint8) isSubscribed; // (1-> True. 0-> False )Depicts if User subscribed to a Specific Channel Address
        // keep track of all subscribed channels
        // TEMP - NOT SURE IF THESE MAPPING SERVE A SPECIFIC PURPOSE YET
        mapping(address => uint256) subscribed;
        mapping(uint256 => address) mapAddressSubscribed;
    }

    /** MAPPINGS **/
    mapping(address => User) public users;
    mapping(uint256 => address) public mapAddressUsers;
    mapping(address => mapping(address => bool))
        public delegated_NotificationSenders; // Keeps track of addresses allowed to send notifications on Behalf of a Channel
    mapping(address => uint256) public nonces; // A record of states for signing / validating signatures

    /** STATE VARIABLES **/
    uint256 public usersCount;
    string public constant name = "EPNSCommunicator";
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,uint256 chainId,address verifyingContract)"
        ); /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant SUBSCRIBE_TYPEHASH =
        keccak256("Subscribe(address channel,uint256 nonce,uint256 expiry)"); // The EIP-712 typehash for the SUBSCRIBE struct used by the contract
    bytes32 public constant UNSUBSCRIBE_TYPEHASH =
        keccak256("Unsubscribe(address channel,uint256 nonce,uint256 expiry)"); //The EIP-712 typehash for the SUBSCRIBE struct used by the contract

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

    /** MODIFIERS **/

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
        // b. Update Channel's Subscribed Count for User - TEMP-not sure yet
        // c. Update User Subscribed Count for Channel
        // d. Usual Subscribe Track

        user.isSubscribed[_channel] = 1;

        // treat the count as index and update user struct
        // TEMP - NOT SURE IF THE LINES BELOW SERVE A SPECIFIC PURPOSE YET
        user.subscribed[_channel] = user.subscribedCount;
        user.mapAddressSubscribed[user.subscribedCount] = _channel;

        user.subscribedCount = user.subscribedCount.add(1); // Finally increment the subscribed count

        // Emit it
        emit Subscribe(_channel, _user);
    }

    /**
     * @notice External Subscribe Function that allows users to Diretly interact with the Base Subscribe function
     * @dev Subscribers the caller of the function to a channl - Takes into Consideration the "msg.sender"
     * @param _channel address of the channel that the user is subscribing to
     **/
    function subscribe(address _channel) external returns (bool) {
        // Call actual subscribe
        _subscribe(_channel, msg.sender);
        return true;
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
     * @notice Base Usubscribe Function that allows users to UNSUBSCRIBE from a Particular Channel and Keeps track of it
     * @dev Modifies the User Struct with crucial details about the Channel Unsubscription
     * @param _channel address of the channel that the user is subscribing to
     * @param _user address of the Subscriber
     **/
    function _unsubscribe(address _channel, address _user)
        private
        returns (uint256 ratio)
    {
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
     * @notice External Unsubcribe Function that allows users to Diretly interact with the Base Unsubscribe function
     * @dev UnSubscribers the caller of the function to a channl - Takes into Consideration the "msg.sender"
     * @param _channel address of the channel that the user is subscribing to
     **/
    function unsubscribe(address _channel) external {
        // Call actual unsubscribe
        _unsubscribe(_channel, msg.sender);
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

    function getChainId() internal pure returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }
}
