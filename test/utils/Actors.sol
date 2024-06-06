// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

struct Actors {
    // Default admin for all Push Contracts
    address payable admin;
    // Default governance addr for all Push Contracts
    address payable governance;
    // Channel Owner Named - Bob
    address payable bob_channel_owner;
    // Channel Owner Named - Alice
    address payable alice_channel_owner;
    // Channel Owner Named - Charlie
    address payable charlie_channel_owner;
    // Channel Owner Named - tony
    address payable tony_channel_owner;
    // Push Token Holder - Dan
    address payable dan_push_holder;
    // Push Token Holder - tim
    address payable tim_push_holder;
}
struct ChannelCreators {
    // Default admin for all Push Contracts
    bytes32 admin_Bytes32;
    // Default governance addr for all Push Contracts
    bytes32 governance_Bytes32;
    // Channel Owner Named - Bob
    bytes32 bob_channel_owner_Bytes32;
    // Channel Owner Named - Alice
    bytes32 alice_channel_owner_Bytes32;
    // Channel Owner Named - Charlie
    bytes32 charlie_channel_owner_Bytes32;
    // Channel Owner Named - tony
    bytes32 tony_channel_owner_Bytes32;
    // Push Token Holder - Dan
    bytes32 dan_push_holder_Bytes32;
    // Push Token Holder - tim
    bytes32 tim_push_holder_Bytes32;
}
