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

    //  SourceConfig ArbSepolia = SourceConfig(
    //     IWormhole(0x6b9C8671cdDC8dEab9c719bB87cBd3e782bA6a35),
    //     IWormholeTransceiver(0xEFBeAAF530653576acf8a78a19fB7b28b085AF9F),
    //     0xFAB6A0Cb264D34B939A7eDcF83f5e8D447C21812,
    //     0xEFBeAAF530653576acf8a78a19fB7b28b085AF9F,
    //     0x7B1bD7a6b4E61c2a123AC6BC2cbfC614437D0470,
    //     0xa58F4F5FB4977151E99291FCa5b92d95021be0f4,
    //     0x778D3206374f8AC265728E18E3fE2Ae6b93E4ce4,
    //     10_003,
    //     "https://sepolia-rollup.arbitrum.io/rpc"
    // );

    DestConfig EthSepolia = DestConfig(
        IWormhole(0x4a8bc80Ed5a4067f1CCf107057b8270E0cC11A78),
        IWormholeTransceiver(0x9D85E6467d5069A7144E4f251E540bf9fA7ea5C6),
        0xCFA54a96fE19d9EB9395642225C62d0abe6Cd835,
        0x7B1bD7a6b4E61c2a123AC6BC2cbfC614437D0470,
        0xe1327FE9b457Ad1b4601FdD2afcAdAef198d6BA6,
        10_002,
        "https://eth-sepolia.public.blastapi.io"
    );
    // DestConfig BaseSepolia = DestConfig(
    //     IWormhole(0x4a8bc80Ed5a4067f1CCf107057b8270E0cC11A78),
    //     IWormholeTransceiver(0xE175E3aBa428d028D2CEdE8e1cB338D1f1D50d13),
    //     0x63Dd783A353ad0f8a654ba7a21D7Fd8637E278a1,
    //     0x93BAD53DDfB6132b0aC8E37f6029163E63372cEE,
    //     0x527F3692F5C53CfA83F7689885995606F93b6164,
    //     10004,
    //     "https://sepolia.base.org"
    // );


                  /// NEWEST DEPLOYED CONTRACT ///

// SourceConfig ArbSepolia = SourceConfig(
//         IWormhole(0x6b9C8671cdDC8dEab9c719bB87cBd3e782bA6a35),
//         IWormholeTransceiver(0x4F532db1ce4f33170b21F6a97A8973e9499BbD75),
//         0x5e1989B8681C91A90F33A82b22cf51210a7C31C0,
//         0x4F532db1ce4f33170b21F6a97A8973e9499BbD75,
//         0x7B1bD7a6b4E61c2a123AC6BC2cbfC614437D0470,
//         0x70c3C79d33A9b08F1bc1e7DB113D1588Dad7d8Bc,
//         0x778D3206374f8AC265728E18E3fE2Ae6b93E4ce4,
//         10_003,
//         "https://sepolia-rollup.arbitrum.io/rpc"
//     );

//     DestConfig EthSepolia = DestConfig(
//         IWormhole(0x4a8bc80Ed5a4067f1CCf107057b8270E0cC11A78),
//         IWormholeTransceiver(0x3cc5553e0ABfF03743c9c2cc785D184e72D45852),
//         0x76c636cb502Aa7eed6784Fde38b955bC15CC6bc1,
//         0x7B1bD7a6b4E61c2a123AC6BC2cbfC614437D0470,
//         0xe1327FE9b457Ad1b4601FdD2afcAdAef198d6BA6,
//         10_002,
//         "https://eth-sepolia.public.blastapi.io"
//     );
}
