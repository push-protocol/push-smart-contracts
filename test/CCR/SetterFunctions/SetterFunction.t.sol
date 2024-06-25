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
            PUSH_NTT_SOURCE,
            NTT_MANAGER,
            ITransceiver(TRANSCEIVER),
            IWormholeTransceiver(WORMHOLE_TRANSCEIVER),
            IWormholeRelayer(WORMHOLE_RELAYER),
            WORMHOLE_RECIPIENT_CHAIN
        );
    }

    function test_WhenTheCallerIsAdmin() external whenInitializeBridgeContractsFunctionIsCalled {
        // it should proceed and set all the addresses correctly
        changePrank(actor.admin);
        commProxy.initializeBridgeContracts(
            PUSH_NTT_SOURCE,
            NTT_MANAGER,
            ITransceiver(TRANSCEIVER),
            IWormholeTransceiver(WORMHOLE_TRANSCEIVER),
            IWormholeRelayer(WORMHOLE_RELAYER),
            WORMHOLE_RECIPIENT_CHAIN
        );

        assertEq(address(commProxy.PUSH_NTT()), PUSH_NTT_SOURCE);
        assertEq(address(commProxy.NTT_MANAGER()), NTT_MANAGER);
        assertEq(address(commProxy.TRANSCEIVER()), TRANSCEIVER);
        assertEq(address(commProxy.WORMHOLE_TRANSCEIVER()), WORMHOLE_TRANSCEIVER);
        assertEq(address(commProxy.WORMHOLE_RELAYER()), WORMHOLE_RELAYER);
        assertEq(commProxy.WORMHOLE_RECIPIENT_CHAIN(), WORMHOLE_RECIPIENT_CHAIN);
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
        commProxy.setNttManagerAddress(address(NTT_MANAGER));

        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotAdmin.selector));
        commProxy.setTransceiverAddress(address(TRANSCEIVER));

        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotAdmin.selector));
        commProxy.setWormholeTransceiverAddress(address(WORMHOLE_TRANSCEIVER));

        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotAdmin.selector));
        commProxy.setWormholeRelayerAddress(address(WORMHOLE_RELAYER));

        vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotAdmin.selector));
        commProxy.setWormholeRecipientChain(10_003);
    }

    function test_WhenCallerIsAdmin() external whenRestOfTheSetterFunctionsAreCalledIndividually {
        // it should proceed and set the correct values

        changePrank(actor.admin);

        commProxy.seMinChannelCreationFee(10);
        assertEq(commProxy.ADD_CHANNEL_MIN_FEES(), 10);

        commProxy.setPushNTTAddress(address(pushNtt));
        assertEq(address(commProxy.PUSH_NTT()), address(pushNtt));

        commProxy.setNttManagerAddress(address(NTT_MANAGER));
        assertEq(address(commProxy.NTT_MANAGER()), address(NTT_MANAGER));

        commProxy.setTransceiverAddress(address(TRANSCEIVER));
        assertEq(address(commProxy.TRANSCEIVER()), address(TRANSCEIVER));

        commProxy.setWormholeTransceiverAddress(address(WORMHOLE_TRANSCEIVER));
        assertEq(address(commProxy.WORMHOLE_TRANSCEIVER()), address(WORMHOLE_TRANSCEIVER));

        commProxy.setWormholeRelayerAddress(address(WORMHOLE_RELAYER));
        assertEq(address(commProxy.WORMHOLE_RELAYER()), address(WORMHOLE_RELAYER));

        commProxy.setWormholeRecipientChain(10_003);
        assertEq(commProxy.WORMHOLE_RECIPIENT_CHAIN(), 10_003);
    }
}
