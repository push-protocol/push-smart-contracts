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
