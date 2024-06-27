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
        uint16 WORMHOLE_RECIPIENT_CHAIN;
        address PUSH_NTT_SOURCE;
        address PushHolder;
        uint16 SourceChainId;
        string rpc;
    }

    struct DestConfig {
        uint16 DestChainId;
        IWormholeTransceiver wormholeTransceiverChain2;
        //Dest Chain Addresses
        address PUSH_NTT_DEST;
        string rpc;
        address WORMHOLE_RELAYER_DEST;
    }

    //For Arbutrum Sepolia as a source chain
    SourceConfig ArbSepolia = SourceConfig(
        IWormhole(0x4a8bc80Ed5a4067f1CCf107057b8270E0cC11A78),
        IWormholeTransceiver(0xCa148906e776D19EbB9442f5Ac2Dc337975d3fdd),
        0xF73bC33A8Ad30B054B3f6b612339a9279ae7c58C,
        0xCa148906e776D19EbB9442f5Ac2Dc337975d3fdd,
        0x7B1bD7a6b4E61c2a123AC6BC2cbfC614437D0470,
        10_002,
        0x70c3C79d33A9b08F1bc1e7DB113D1588Dad7d8Bc,
        0x778D3206374f8AC265728E18E3fE2Ae6b93E4ce4,
        10_003,
        "https://sepolia-rollup.arbitrum.io/rpc"
    );

    //For Ethereum Sepolia as a destination chain
    DestConfig EthSepolia = DestConfig(
        10_002,
        IWormholeTransceiver(0x9D85E6467d5069A7144E4f251E540bf9fA7ea5C6),
        0xe1327FE9b457Ad1b4601FdD2afcAdAef198d6BA6,
        "https://gateway.tenderly.co/public/sepolia",
        0x7B1bD7a6b4E61c2a123AC6BC2cbfC614437D0470
    );
}
