// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

/// @notice Namespace for the structs and enums used in {PushCoreV2}
library Core {
    // For Message Type
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

/// @notice Namespace for the structs and enums used in {PushCommV2}.
library Comm {
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
}

/// @notice Namespace for the structs used in both {PushFeePoolStaking}.
library PushStaking {
    //@notice: Stores all user's staking details
    struct UserFessInfo {
        uint256 stakedAmount;
        uint256 stakedWeight;
        uint256 lastStakedBlock;
        uint256 lastClaimedBlock;
        mapping(uint256 => uint256) epochToUserStakedWeight;
    }
}
