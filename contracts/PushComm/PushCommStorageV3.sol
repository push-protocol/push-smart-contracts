pragma solidity ^0.8.20;

import { CommTypes } from "../libraries/DataTypes.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/wormhole/ITransceiver.sol";

contract PushCommStorageV3 {
    /**
     * MAPPINGS *
     */
    mapping(address => CommTypes.User) public users;
    mapping(address => uint256) public nonces;
    mapping(uint256 => address) public mapAddressUsers;
    mapping(address => mapping(address => string)) public userToChannelNotifs;
    mapping(address => mapping(address => bool)) public delegatedNotificationSenders;

    /**
     * STATE VARIABLES *
     */
    address public governance;
    address public pushChannelAdmin;
    uint256 public chainID;
    uint256 public usersCount;
    bool public isMigrationComplete;
    address public EPNSCoreAddress;
    string public chainName;
    string public constant name = "EPNS COMM V1";
    bytes32 public constant NAME_HASH = keccak256(bytes(name));
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
    bytes32 public constant SUBSCRIBE_TYPEHASH =
        keccak256("Subscribe(address channel,address subscriber,uint256 nonce,uint256 expiry)");
    bytes32 public constant UNSUBSCRIBE_TYPEHASH =
        keccak256("Unsubscribe(address channel,address subscriber,uint256 nonce,uint256 expiry)");
    bytes32 public constant SEND_NOTIFICATION_TYPEHASH =
        keccak256("SendNotification(address channel,address recipient,bytes identity,uint256 nonce,uint256 expiry)");
    // New State Variables
    address public PUSH_TOKEN_ADDRESS;

    mapping(address => CommTypes.ChatDetails) public userChatData;

    // WORMHOLE CROSS-CHAIN STATE VARIABLES
    // ToDo: Need to decide, which of below needs setter functions or can be made constant
    IERC20 public PUSH_NTT;
    address public NTT_MANAGER;
    ITransceiver public TRANSCEIVER;
    IWormholeTransceiver public WORMHOLE_TRANSCEIVER;
    IWormholeRelayer public WORMHOLE_RELAYER;

    uint16 public WORMHOLE_RECIPIENT_CHAIN = 10002; // Wormhole's Core contract recipient Chain ID
    uint256 public GAS_LIMIT = 100_000; //@audit-info Should be checked if really needed
}
