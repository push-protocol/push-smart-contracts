pragma solidity ^0.8.20;


library CoreTypes{
     /* ***************

    ENUMS AND CONSTANTS

    *************** */

    //For Message Type
    enum ChannelType {
        ProtocolNonInterest,
        ProtocolPromotion,
        InterestBearingOpen,
        InterestBearingMutual,
        TimeBound,
        TokenGaited
    }
    
    enum ChannelAction {
        ChannelRemoved,
        ChannelAdded,
        ChannelUpdated
    }

    /**
     * @notice Channel Struct that includes imperative details about a specific Channel.
     *
     */
    struct Channel {
        // @notice Denotes the Channel Type
        ChannelType channelType;
        /**
         * @notice Symbolizes Channel's State:
         * 0 -> INACTIVE,
         * 1 -> ACTIVATED
         * 2 -> DeActivated By Channel Owner,
         * 3 -> BLOCKED by pushChannelAdmin/Governance
         *
         */
        uint8 channelState;
        // @notice denotes the address of the verifier of the Channel
        address verifiedBy;
        // @notice Total Amount of Dai deposited during Channel Creation
        uint256 poolContribution;
        // @notice Represents the Historical Constant
        uint256 channelHistoricalZ;
        // @notice Represents the FS Count
        uint256 channelFairShareCount;
        // @notice The last update block number, used to calculate fair share
        uint256 channelLastUpdate;
        // @notice Helps in defining when channel started for pool and profit calculation
        uint256 channelStartBlock;
        // @notice Helps in outlining when channel was updated
        uint256 channelUpdateBlock;
        // @notice The individual weight to be applied as per pool contribution
        uint256 channelWeight;
        // @notice The Expiry TimeStamp in case of TimeBound Channel Types
        uint256 expiryTime;
    }
}

library CommTypes{
    /**
     * @notice User Struct that involves imperative details about
     * a specific User.
     *
     */
    struct User {
        // @notice Depicts whether or not a user is ACTIVE
        bool userActivated;
        // @notice Will be false until public key is emitted
        bool publicKeyRegistered;
        // @notice Events should not be polled before this block as user doesn't exist
        uint256 userStartBlock;
        // @notice Keep track of subscribers
        uint256 subscribedCount;
        /**
         * Depicts if User subscribed to a Specific Channel Address
         * 1 -> User is Subscribed
         * 0 -> User is NOT SUBSCRIBED
         *
         */
        mapping(address => uint8) isSubscribed;
        // Keeps track of all subscribed channels
        mapping(address => uint256) subscribed;
        mapping(uint256 => address) mapAddressSubscribed;
    }

    struct ChatDetails {
        address requestSender;
        uint256 timestamp;
        uint256 amountDeposited;
    }
}
   