pragma solidity ^0.8.20;
// SPDX-License-Identifier: MIT

/**
 * @title PushComm V3
 * @author Push Protocol
 * @notice Push Communicator, as the name suggests, is more of a Communictation Layer
 *         between END USERS and Push Core Protocol.
 *         The Communicator Protocol is comparatively much simpler & involves basic
 *         details, specifically about the USERS of the Protocols
 *
 * @dev   Some imperative functionalities that the Push Communicator Protocol allows
 *        are Subscribing to a particular channel, Unsubscribing a channel, Sending
 *        Notifications to a particular recipient or all subscribers of a Channel etc.
 *
 */
import { PushCommStorageV2 } from "./PushCommStorageV2.sol";
import { Errors } from "../libraries/Errors.sol";
import { IPushCoreV3 } from "../interfaces/IPushCoreV3.sol";
import { IPushCommV3 } from "../interfaces/IPushCommV3.sol";
import { BaseHelper } from "../libraries/BaseHelper.sol";
import { CommTypes } from "../libraries/DataTypes.sol";
import { IERC1271 } from "../interfaces/signatures/IERC1271.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract PushCommV3 is Initializable, PushCommStorageV2, IPushCommV3 {
    using SafeERC20 for IERC20;

    /* *****************************

        MODIFIERS

    ***************************** */

    modifier onlyPushChannelAdmin() {
        if (msg.sender != pushChannelAdmin) {
            revert Errors.CallerNotAdmin();
        }
        _;
    }

    modifier onlyPushGovernance() {
        if (msg.sender != governance) {
            revert Errors.CallerNotGovernance();
        }
        _;
    }

    modifier onlyPushCore() {
        if (msg.sender != PushCoreAddress) {
            revert Errors.UnauthorizedCaller(msg.sender);
        }
        _;
    }

    /* *****************************

        INITIALIZER

    ***************************** */
    function initialize(address _pushChannelAdmin, string memory _chainName) public initializer returns (bool) {
        pushChannelAdmin = _pushChannelAdmin;
        governance = _pushChannelAdmin;
        chainName = _chainName;
        chainID = block.chainid;
        return true;
    }

    /* *****************************

        SETTER FUNCTIONS

    ***************************** */

    function verifyChannelAlias(string memory _channelAddress) external {
        emit ChannelAlias(chainName, chainID, msg.sender, _channelAddress);
    }

    function removeChannelAlias(string memory _channelAddress) external {
        emit RemoveChannelAlias(chainName, chainID, msg.sender, _channelAddress);
    }

    function completeMigration() external onlyPushChannelAdmin {
        isMigrationComplete = true;
    }

    function setPushCoreAddress(address _coreAddress) external onlyPushChannelAdmin {
        PushCoreAddress = _coreAddress;
    }

    function setGovernanceAddress(address _governanceAddress) external onlyPushChannelAdmin {
        governance = _governanceAddress;
    }

    function setPushTokenAddress(address _tokenAddress) external onlyPushChannelAdmin {
        PUSH_TOKEN_ADDRESS = _tokenAddress;
    }

    function transferPushChannelAdminControl(address _newAdmin) external onlyPushChannelAdmin {
        if (_newAdmin == address(0) || _newAdmin == pushChannelAdmin) {
            revert Errors.InvalidArgument_WrongAddress(_newAdmin);
        }
        pushChannelAdmin = _newAdmin;
    }

    /* *****************************

         SUBSCRIBE FUNCTIONS

    ***************************** */

    /// @inheritdoc  IPushCommV3
    function isUserSubscribed(address _channel, address _user) public view returns (bool) {
        CommTypes.User storage user = users[_user];
        if (user.isSubscribed[_channel] == 1) {
            return true;
        }
    }

    /// @inheritdoc  IPushCommV3
    function subscribe(address _channel) external returns (bool) {
        _subscribe(_channel, msg.sender);
        return true;
    }

    /// @inheritdoc  IPushCommV3
    function batchSubscribe(address[] calldata _channelList) external returns (bool) {
        uint256 channelListLength = _channelList.length;
        for (uint256 i = 0; i < channelListLength;) {
            _subscribe(_channelList[i], msg.sender);
            unchecked {
                i++;
            }
        }
        return true;
    }

    /**
     * @notice This Function helps in migrating the already existing Subscriber's data to the New protocol
     *
     * @dev     Can only be called by pushChannelAdmin
     *          Can only be called if the Migration is not yet complete, i.e., "isMigrationComplete" boolean must be
     * false
     *          Subscribes the Users to the respective Channels as per the arguments passed to the function
     *
     * @param _startIndex  starting Index for the LOOP
     * @param _endIndex    Last Index for the LOOP
     * @param _channelList array of addresses of the channels
     * @param _usersList   array of addresses of the Users or Subscribers of the Channels
     *
     */
    // function migrateSubscribeData(
    //     uint256 _startIndex,
    //     uint256 _endIndex,
    //     address[] calldata _channelList,
    //     address[] calldata _usersList
    // )
    //     external
    //     onlyPushChannelAdmin
    //     returns (bool)
    // {
    //     if (isMigrationComplete || _channelList.length != _usersList.length) {
    //         revert Errors.InvalidArg_ArrayLengthMismatch();
    //     }

    //     for (uint256 i = _startIndex; i < _endIndex;) {
    //         if (isUserSubscribed(_channelList[i], _usersList[i])) {
    //             unchecked {
    //                 i++;
    //             }
    //             continue;
    //         } else {
    //             _subscribe(_channelList[i], _usersList[i]);
    //         }
    //         unchecked {
    //             i++;
    //         }
    //     }
    //     return true;
    // }

    /**
     * @notice Base Subscribe Function that allows users to Subscribe to a Particular Channel
     *
     * @dev Initializes the User Struct with crucial details about the Channel Subscription
     *      Addes the caller as a an Activated User of the protocol. (Only if the user hasn't been added already)
     *
     * @param _channel address of the channel that the user is subscribing to
     * @param _user    address of the Subscriber
     *
     */
    function _subscribe(address _channel, address _user) private {
        if (!isUserSubscribed(_channel, _user)) {
            _addUser(_user);

            CommTypes.User storage user = users[_user];

            uint256 _subscribedCount = user.subscribedCount;

            user.isSubscribed[_channel] = 1;
            // treat the count as index and update user struct
            user.subscribed[_channel] = _subscribedCount;
            user.mapAddressSubscribed[_subscribedCount] = _channel;
            user.subscribedCount = _subscribedCount + 1; // Finally increment the subscribed count
            // Emit it
            emit Subscribe(_channel, _user);
        }
    }

    /// @inheritdoc  IPushCommV3
    function subscribeBySig(
        address channel,
        address subscriber,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
    {
        // EIP-712
        if (subscriber == address(0)) {
            revert Errors.InvalidArgument_WrongAddress(subscriber);
        }
        if (nonce != nonces[subscriber]++) {
            revert Errors.Comm_InvalidNonce();
        }
        if (block.timestamp > expiry) {
            revert Errors.Comm_TimeExpired(expiry, block.timestamp);
        }

        bytes32 domainSeparator = keccak256(abi.encode(DOMAIN_TYPEHASH, NAME_HASH, block.chainid, address(this)));
        bytes32 structHash = keccak256(abi.encode(SUBSCRIBE_TYPEHASH, channel, subscriber, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        if (BaseHelper.isContract(subscriber)) {
            // use EIP-1271
            bytes4 result = IERC1271(subscriber).isValidSignature(digest, abi.encodePacked(r, s, v));
            if (result != 0x1626ba7e) {
                revert Errors.Comm_InvalidSignature_FromContract();
            }
        } else {
            // validate with in contract
            address signatory = ecrecover(digest, v, r, s);
            if (signatory != subscriber) {
                revert Errors.Comm_InvalidSignature_FromEOA();
            }
        }

        _subscribe(channel, subscriber);
    }

    /// @inheritdoc  IPushCommV3
    function subscribeViaCore(address _channel, address _user) external onlyPushCore returns (bool) {
        _subscribe(_channel, _user);
        return true;
    }

    /* *****************************

         UNSUBSCRIBE FUNCTIONS

    ***************************** */

    /// @inheritdoc  IPushCommV3
    function unsubscribe(address _channel) external returns (bool) {
        // Call actual unsubscribe
        _unsubscribe(_channel, msg.sender);
        return true;
    }

    /// @inheritdoc  IPushCommV3
    function batchUnsubscribe(address[] calldata _channelList) external returns (bool) {
        uint256 channelListLength = _channelList.length;
        for (uint256 i = 0; i < channelListLength;) {
            _unsubscribe(_channelList[i], msg.sender);
            unchecked {
                i++;
            }
        }
        return true;
    }

    /**
     * @notice Base Usubscribe Function that allows users to UNSUBSCRIBE from a Particular Channel
     * @dev Modifies the User Struct with crucial details about the Channel Unsubscription
     * @param _channel address of the channel that the user is unsubscribing from
     * @param _user address of the unsubscriber
     *
     */
    function _unsubscribe(address _channel, address _user) private {
        if (isUserSubscribed(_channel, _user)) {
            CommTypes.User storage user = users[_user];

            uint256 _subscribedCount = user.subscribedCount - 1;

            user.isSubscribed[_channel] = 0;
            user.subscribed[user.mapAddressSubscribed[_subscribedCount]] = user.subscribed[_channel];
            user.mapAddressSubscribed[user.subscribed[_channel]] = user.mapAddressSubscribed[_subscribedCount];

            // delete the last one and substract
            delete (user.subscribed[_channel]);
            delete (user.mapAddressSubscribed[_subscribedCount]);
            user.subscribedCount = _subscribedCount;

            // Emit it
            emit Unsubscribe(_channel, _user);
        }
    }

    /// @inheritdoc  IPushCommV3
    function unsubscribeBySig(
        address channel,
        address subscriber,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
    {
        if (subscriber == address(0)) {
            revert Errors.InvalidArgument_WrongAddress(subscriber);
        }
        if (nonce != nonces[subscriber]++) {
            revert Errors.Comm_InvalidNonce();
        }
        if (block.timestamp > expiry) {
            revert Errors.Comm_TimeExpired(expiry, block.timestamp);
        }

        // EIP-712
        bytes32 domainSeparator = keccak256(abi.encode(DOMAIN_TYPEHASH, NAME_HASH, block.chainid, address(this)));
        bytes32 structHash = keccak256(abi.encode(UNSUBSCRIBE_TYPEHASH, channel, subscriber, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        if (BaseHelper.isContract(subscriber)) {
            // use EIP-1271
            bytes4 result = IERC1271(subscriber).isValidSignature(digest, abi.encodePacked(r, s, v));
            if (result != 0x1626ba7e) {
                revert Errors.Comm_InvalidSignature_FromContract();
            }
        } else {
            // validate with in contract
            address signatory = ecrecover(digest, v, r, s);
            if (signatory != subscriber) {
                revert Errors.Comm_InvalidSignature_FromEOA();
            }
        }
        _unsubscribe(channel, subscriber);
    }

    /// @inheritdoc  IPushCommV3
    function unSubscribeViaCore(address _channel, address _user) external onlyPushCore returns (bool) {
        _unsubscribe(_channel, _user);
        return true;
    }

    /**
     * @notice Activates/Adds a particular User's Address in the Protocol.
     *         Keeps track of the Total User Count
     * @dev   Executes its main actions only if the User is not activated yet.
     *        Does nothing if an address has already been added.
     *
     * @param _user address of the user
     */
    function _addUser(address _user) private {
        if (!users[_user].userActivated) {
            // Activates the user
            users[_user].userStartBlock = block.number;
            users[_user].userActivated = true;
            mapAddressUsers[usersCount] = _user;

            usersCount = usersCount + 1;
        }
    }

    /* *****************************

         SEND NOTIFICATOINS FUNCTIONS

    ***************************** */

    /// @inheritdoc  IPushCommV3
    function addDelegate(address _delegate) external {
        delegatedNotificationSenders[msg.sender][_delegate] = true;
        _subscribe(msg.sender, _delegate);
        emit AddDelegate(msg.sender, _delegate);
    }

    /// @inheritdoc  IPushCommV3
    function removeDelegate(address _delegate) external {
        delegatedNotificationSenders[msg.sender][_delegate] = false;
        emit RemoveDelegate(msg.sender, _delegate);
    }

    /**
     *
     * @notice Two main CALLERS for this function-
     *          1. Channel Owner sends Notif to all Subscribers / Subset of Subscribers / Individual Subscriber
     *          2. Delegatee of Channel sends Notif to Recipients
     *
     * @dev    When a CHANNEL OWNER Calls the Function and sends a Notif:
     *          -> We ensure -> "Channel Owner Must be Valid" && "Channel Owner is the Caller"
     *          -> NOTE - Validation of wether or not an address is a CHANNEL, is done via PUSH NODES
     *
     * @dev     When a Delegatee wants to send Notif to Recipient:
     *          -> We ensure "Delegate is the Caller" && "Delegatee is Approved by Chnnel Owner"
     *
     */
    function _checkNotifReq(address _channel, address _recipient) private view returns (bool) {
        if ((_channel == msg.sender) || (delegatedNotificationSenders[_channel][msg.sender])) {
            return true;
        }

        return false;
    }

    /// @inheritdoc  IPushCommV3
    function sendNotification(address _channel, address _recipient, bytes memory _identity) external returns (bool) {
        bool success = _checkNotifReq(_channel, _recipient);
        if (success) {
            // Emit the message out
            emit SendNotification(_channel, _recipient, _identity);
            return true;
        }

        return false;
    }

    /**
     * @notice Base Notification Function that Allows a Channel Owners, Delegates as well as Users to send Notifications
     *
     * @dev   Specifically designed to be called via the EIP 712 send notif function.
     *        Takes into consideration the Signatory address to perform all the imperative checks
     *
     * @param _channel address of the Channel
     * @param _recipient address of the reciever of the Notification
     * @param _signatory address of the SIGNER of the Send Notif Function call transaction
     * @param _identity Info about the Notification
     *
     */
    function _sendNotification(
        address _channel,
        address _recipient,
        address _signatory,
        bytes calldata _identity
    )
        private
        returns (bool)
    {
        if (_channel == _signatory || delegatedNotificationSenders[_channel][_signatory]) {
            // Emit the message out
            emit SendNotification(_channel, _recipient, _identity);
            return true;
        }

        return false;
    }

    /// @inheritdoc  IPushCommV3
    function sendNotifBySig(
        address _channel,
        address _recipient,
        address _signer,
        bytes calldata _identity,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        returns (bool)
    {
        if (_signer == address(0) || nonce != nonces[_signer] || block.timestamp > expiry) {
            return false;
        }

        bytes32 domainSeparator = keccak256(abi.encode(DOMAIN_TYPEHASH, NAME_HASH, block.chainid, address(this)));
        bytes32 structHash =
            keccak256(abi.encode(SEND_NOTIFICATION_TYPEHASH, _channel, _recipient, keccak256(_identity), nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        if (BaseHelper.isContract(_signer)) {
            // use EIP-1271 signature check
            bytes4 result = IERC1271(_signer).isValidSignature(digest, abi.encodePacked(r, s, v));
            if (result != 0x1626ba7e) return false;
        } else {
            address signatory = ecrecover(digest, v, r, s);
            if (signatory != _signer) return false;
        }

        // check sender & emit event
        bool success = _sendNotification(_channel, _recipient, _signer, _identity);

        // update nonce if signature valid
        nonces[_signer] = nonce + 1;

        return success;
    }

    /// @inheritdoc  IPushCommV3
    function changeUserChannelSettings(address _channel, uint256 _notifID, string calldata _notifSettings) external {
        if (!isUserSubscribed(_channel, msg.sender)) {
            revert Errors.Comm_InvalidSubscriber();
        }
        string memory notifSetting = string(abi.encodePacked(Strings.toString(_notifID), "+", _notifSettings));
        userToChannelNotifs[msg.sender][_channel] = notifSetting;
        emit UserNotifcationSettingsAdded(_channel, msg.sender, _notifID, notifSetting);
    }

    function createIncentivizeChatRequest(address requestReceiver, uint256 amount) external {
        if (amount == 0) {
            revert Errors.InvalidArg_LessThanExpected(1, amount);
        }
        address requestSender = msg.sender;
        address coreContract = PushCoreAddress;
        // Transfer incoming PUSH Token to core contract
        IERC20(PUSH_TOKEN_ADDRESS).safeTransferFrom(requestSender, coreContract, amount);

        CommTypes.ChatDetails storage chatData = userChatData[requestSender];
        if (chatData.amountDeposited == 0) {
            chatData.requestSender = requestSender;
        }
        chatData.timestamp = block.timestamp;
        chatData.amountDeposited += amount;

        // Trigger handleChatRequestData() on core directly from comm
        IPushCoreV3(coreContract).handleChatRequestData(requestSender, requestReceiver, amount);

        emit IncentivizeChatReqInitiated(requestSender, requestReceiver, amount, block.timestamp);
    }
}
