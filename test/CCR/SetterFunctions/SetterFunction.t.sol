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


    assertEq(address(commProxy.PUSH_NTT()) , PUSH_NTT_SOURCE);
    assertEq(address(commProxy.NTT_MANAGER()) ,NTT_MANAGER );
    assertEq(address(commProxy.TRANSCEIVER()) , TRANSCEIVER);
    assertEq(address(commProxy.WORMHOLE_TRANSCEIVER()) ,WORMHOLE_TRANSCEIVER );
    assertEq(address(commProxy.WORMHOLE_RELAYER()) ,WORMHOLE_RELAYER );
    assertEq(commProxy.WORMHOLE_RECIPIENT_CHAIN (),WORMHOLE_RECIPIENT_CHAIN );
    }

    modifier whenRestOfTheSetterFunctionsAreCalledIndividually() {
        _;
    }

    function test_RevertWhen_CallerIsNotAdmin() external whenRestOfTheSetterFunctionsAreCalledIndividually {
        // it should revert
    }

    function test_WhenCallerIsAdmin() external whenRestOfTheSetterFunctionsAreCalledIndividually 
{
        // it should proceed and set the correct values
    }
}