pragma solidity ^0.8.20;
pragma experimental ABIEncoderV2;

import { BasePushCommTest } from "../PushComm/unit_tests/BasePushCommTest.t.sol";
import { console } from "forge-std/console.sol";
import "contracts/token/Push.sol";

import "contracts/interfaces/wormhole/ITransceiver.sol";
import "contracts/interfaces/wormhole/IWormholeTransceiver.sol";
import "contracts/interfaces/wormhole/IWormholeRelayer.sol";
import { IWormhole } from "wormhole-solidity-sdk/interfaces/IWormhole.sol";

contract BaseCCRTest is BasePushCommTest {
    string ArbSepolia = "https://sepolia-rollup.arbitrum.io/rpc";
    string EthSepolia = "https://gateway.tenderly.co/public/sepolia";
    /* ***************
       Initializing Set-Up for Push Contracts
     *************** */

    // Source Chain Addresses
    IWormhole wormhole = IWormhole(0x4a8bc80Ed5a4067f1CCf107057b8270E0cC11A78);
    address NTT_MANAGER = 0xF73bC33A8Ad30B054B3f6b612339a9279ae7c58C;
    address TRANSCEIVER = 0xCa148906e776D19EbB9442f5Ac2Dc337975d3fdd;
    address WORMHOLE_TRANSCEIVER = 0xCa148906e776D19EbB9442f5Ac2Dc337975d3fdd;
    address WORMHOLE_RELAYER = 0x7B1bD7a6b4E61c2a123AC6BC2cbfC614437D0470;
    uint16 WORMHOLE_RECIPIENT_CHAIN = 10_002;
    address PUSH_NTT_SOURCE = 0x70c3C79d33A9b08F1bc1e7DB113D1588Dad7d8Bc;
    address PushHolder = 0x778D3206374f8AC265728E18E3fE2Ae6b93E4ce4;
    address WORMHOLE_RELAYER_SEPOLIA = 0x7B1bD7a6b4E61c2a123AC6BC2cbfC614437D0470;

    uint16 chainId1 = 10_003;
    uint16 chainId2 = 10_002;

    IWormholeTransceiver wormholeTransceiverChain1 = IWormholeTransceiver(0xCa148906e776D19EbB9442f5Ac2Dc337975d3fdd);
    IWormholeTransceiver wormholeTransceiverChain2 = IWormholeTransceiver(0x9D85E6467d5069A7144E4f251E540bf9fA7ea5C6);

    //Dest Chain Addresses
    address PUSH_NTT_DEST = 0xe1327FE9b457Ad1b4601FdD2afcAdAef198d6BA6;

    ///@notice start with forking the arbitrum testnet
    /// Wrap the token contract with the one deployed on arbitrum testnet
    /// getting the push tokens from whale address
    /// approving the tokens then initializing the Comm contract with already deployed
    /// bridge related contracts.

    function setUp() public virtual override {
        setUpChain1(ArbSepolia);
    }

    function switchChains(string memory url) public {
        vm.createSelectFork(url);
    }

    function getPushTokenOnfork(address _addr, uint256 _amount) public {
        changePrank(PushHolder);
        pushNttToken.transfer(_addr, _amount);

        changePrank(_addr);
        pushNttToken.approve(address(commProxy), type(uint256).max);
    }

    function setUpChain1(string memory url) internal {
        switchChains(url);
        BasePushCommTest.setUp();
        pushNttToken = Push(address(PUSH_NTT_SOURCE));

        getPushTokenOnfork(actor.bob_channel_owner, 1000e18);
        getPushTokenOnfork(actor.charlie_channel_owner, 1000e18);

        changePrank(actor.admin);
        commProxy.initializeBridgeContracts(
            PUSH_NTT_SOURCE,
            NTT_MANAGER,
            ITransceiver(TRANSCEIVER),
            IWormholeTransceiver(WORMHOLE_TRANSCEIVER),
            IWormholeRelayer(WORMHOLE_RELAYER),
            WORMHOLE_RECIPIENT_CHAIN
        );
    }

    function setUpChain2(string memory url) internal {
        switchChains(url);
        BasePushCommTest.setUp();
        pushNttToken = Push(address(PUSH_NTT_DEST));
        changePrank(actor.admin);
        coreProxy.setWormholeRelayer(WORMHOLE_RELAYER_SEPOLIA);
        coreProxy.setRegisteredSender(chainId1,toWormholeFormat(address(commProxy)));
    }

    function toWormholeFormat(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    function getPayload() internal returns (bytes memory) {
        
    }
}
