// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseCCRTest } from "../BaseCCR.t.sol";

import "contracts/interfaces/wormhole/ITransceiver.sol";
import "contracts/interfaces/wormhole/IWormholeTransceiver.sol";
import "contracts/interfaces/wormhole/IWormholeRelayer.sol";
import { Errors } from "./../../../contracts/libraries/Errors.sol";

contract SetterFunctionstsol is BaseCCRTest {
    function setUp() public override {
        BaseCCRTest.setUp();
    }

    modifier whenInitializeBridgeContractsFunctionIsCalled() {
        _;
    }

    function test_RevertWhen_TheCallerIsNotAdmin() external whenInitializeBridgeContractsFunctionIsCalled {
        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotAdmin.selector));
        changePrank(actor.bob_channel_owner);
        commProxy.initializeBridgeContracts(
            ArbSepolia.PUSH_NTT_SOURCE,
            ArbSepolia.NTT_MANAGER,
            ITransceiver(ArbSepolia.TRANSCEIVER),
            ArbSepolia.wormholeTransceiverChain1,
           IWormholeRelayer(ArbSepolia.WORMHOLE_RELAYER_SOURCE),
            ArbSepolia.WORMHOLE_RECIPIENT_CHAIN
        );
    }

    function test_WhenTheCallerIsAdmin() external whenInitializeBridgeContractsFunctionIsCalled {
        // it should proceed and set all the addresses correctly
        changePrank(actor.admin);
        commProxy.initializeBridgeContracts(
            ArbSepolia.PUSH_NTT_SOURCE,
            ArbSepolia.NTT_MANAGER,
            ITransceiver(ArbSepolia.TRANSCEIVER),
            ArbSepolia.wormholeTransceiverChain1,
           IWormholeRelayer(ArbSepolia.WORMHOLE_RELAYER_SOURCE),
            ArbSepolia.WORMHOLE_RECIPIENT_CHAIN
        );

        assertEq(address(commProxy.PUSH_NTT()), ArbSepolia.PUSH_NTT_SOURCE);
        assertEq(address(commProxy.NTT_MANAGER()), ArbSepolia.NTT_MANAGER);
        assertEq(address(commProxy.TRANSCEIVER()), ArbSepolia.TRANSCEIVER);
        assertEq(address(commProxy.WORMHOLE_TRANSCEIVER()), ArbSepolia.TRANSCEIVER);
        assertEq(address(commProxy.WORMHOLE_RELAYER()), ArbSepolia.WORMHOLE_RELAYER_SOURCE);
        assertEq(commProxy.WORMHOLE_RECIPIENT_CHAIN(), ArbSepolia.WORMHOLE_RECIPIENT_CHAIN);
    }

    modifier whenRestOfTheSetterFunctionsAreCalledIndividually() {
        _;
    }

    function test_RevertWhen_CallerIsNotAdmin() external whenRestOfTheSetterFunctionsAreCalledIndividually {
        // it should revert
        changePrank(actor.bob_channel_owner);

        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotAdmin.selector));
        commProxy.seMinChannelCreationFee(10);

        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotAdmin.selector));
        commProxy.setPushNTTAddress(address(pushNtt));

        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotAdmin.selector));
        commProxy.setNttManagerAddress(address(ArbSepolia.NTT_MANAGER));

        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotAdmin.selector));
        commProxy.setTransceiverAddress(ArbSepolia.TRANSCEIVER);

        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotAdmin.selector));
        commProxy.setWormholeTransceiverAddress(ArbSepolia.TRANSCEIVER);

        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotAdmin.selector));
        commProxy.setWormholeRelayerAddress(ArbSepolia.WORMHOLE_RELAYER_SOURCE);

        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotAdmin.selector));
        commProxy.setWormholeRecipientChain(EthSepolia.DestChainId);
    }

    function test_WhenCallerIsAdmin() external whenRestOfTheSetterFunctionsAreCalledIndividually {
        // it should proceed and set the correct values

        changePrank(actor.admin);

        commProxy.seMinChannelCreationFee(10);
        assertEq(commProxy.ADD_CHANNEL_MIN_FEES(), 10);

        commProxy.setPushNTTAddress(address(pushNtt));
        assertEq(address(commProxy.PUSH_NTT()), address(pushNtt));

        commProxy.setNttManagerAddress(address(ArbSepolia.NTT_MANAGER));
        assertEq(address(commProxy.NTT_MANAGER()), ArbSepolia.NTT_MANAGER);

        commProxy.setTransceiverAddress(ArbSepolia.TRANSCEIVER);
        assertEq(address(commProxy.TRANSCEIVER()),ArbSepolia.TRANSCEIVER);

        commProxy.setWormholeTransceiverAddress(ArbSepolia.TRANSCEIVER);
        assertEq(address(commProxy.WORMHOLE_TRANSCEIVER()),ArbSepolia.TRANSCEIVER);

        commProxy.setWormholeRelayerAddress(ArbSepolia.WORMHOLE_RELAYER_SOURCE);
        assertEq(address(commProxy.WORMHOLE_RELAYER()), ArbSepolia.WORMHOLE_RELAYER_SOURCE);

        commProxy.setWormholeRecipientChain(EthSepolia.DestChainId);
        assertEq(commProxy.WORMHOLE_RECIPIENT_CHAIN(), EthSepolia.DestChainId);
    }
}
