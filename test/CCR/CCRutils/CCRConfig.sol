// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import { IWormhole } from "wormhole-solidity-sdk/interfaces/IWormhole.sol";
import "contracts/interfaces/wormhole/IWormholeTransceiver.sol";

contract CCRConfig {
    // Standard Structure defined to store Source chain and destination chain address.
    struct SourceConfig {
        IWormhole wormhole;
        IWormholeTransceiver wormholeTransceiverChain1;
        address NTT_MANAGER;
        address TRANSCEIVER;
        address WORMHOLE_RELAYER_SOURCE;
        address PUSH_NTT_SOURCE;
        address PushHolder;
        uint16 SourceChainId;
        string rpc;
    }

    struct DestConfig {
        IWormhole wormhole;
        IWormholeTransceiver wormholeTransceiverChain2;
        address NTT_MANAGER;
        address WORMHOLE_RELAYER_DEST;
        address PUSH_NTT_DEST;
        address DestPushHolder;
        uint16 DestChainId;
        string rpc;
    }

    //For Arbutrum Sepolia as a source chain
    SourceConfig ArbSepolia = SourceConfig(
        IWormhole(0x6b9C8671cdDC8dEab9c719bB87cBd3e782bA6a35),
        IWormholeTransceiver(0xCa148906e776D19EbB9442f5Ac2Dc337975d3fdd),
        0xF73bC33A8Ad30B054B3f6b612339a9279ae7c58C,
        0xCa148906e776D19EbB9442f5Ac2Dc337975d3fdd,
        0x7B1bD7a6b4E61c2a123AC6BC2cbfC614437D0470,
        0x70c3C79d33A9b08F1bc1e7DB113D1588Dad7d8Bc,
        0x778D3206374f8AC265728E18E3fE2Ae6b93E4ce4,
        10_003,
        "https://sepolia-rollup.arbitrum.io/rpc"
    );

    DestConfig EthSepolia = DestConfig(
        IWormhole(0x4a8bc80Ed5a4067f1CCf107057b8270E0cC11A78),
        IWormholeTransceiver(0x9D85E6467d5069A7144E4f251E540bf9fA7ea5C6),
        0xCFA54a96fE19d9EB9395642225C62d0abe6Cd835,
        0x7B1bD7a6b4E61c2a123AC6BC2cbfC614437D0470,
        0xe1327FE9b457Ad1b4601FdD2afcAdAef198d6BA6,
        0x778D3206374f8AC265728E18E3fE2Ae6b93E4ce4,
        10_002,
        "https://eth-sepolia.public.blastapi.io"
    );

    // chain agnostic constants
    // ToDo: to be changed
    uint256 public constant MAX_WINDOW = 100_000 ether; // considering both inbound and outbound
        // limits are same
    uint256 public constant RATE_LIMIT_DURATION = 900;
}
