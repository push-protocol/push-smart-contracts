pragma solidity ^0.8.0;
import {BasePushCoreTest} from "../BasePushCoreTest.t.sol";
import {Errors} from "contracts/libraries/Errors.sol";

contract CoreAdminActions_Test is BasePushCoreTest {
    function setUp() public virtual override {
        BasePushCoreTest.setUp();
    }

    function test_WhenNon_adminTriesToSetTheCommunicatorAddress() external {
        // it should REVERT
        vm.expectRevert(Errors.CallerNotAdmin.selector);
        changePrank(actor.bob_channel_owner);
        coreProxy.setEpnsCommunicatorAddress(address(123));
        assertTrue(coreProxy.epnsCommunicator() != address(123));
    }

    function test_WhenAdminTriesToSetTheCommunicatorAddress() external {
        // it should succesfuly set the communicator address
        changePrank(actor.admin);
        coreProxy.setEpnsCommunicatorAddress(address(0x0));
        assertTrue(coreProxy.epnsCommunicator() == address(0x0));
    }

    function test_REVERTWhen_Non_adminTriesToSetTheGovernanceAddress()
        external
    {
        // it should REVERT
        vm.expectRevert(Errors.CallerNotAdmin.selector);
        changePrank(actor.bob_channel_owner);
        coreProxy.setGovernanceAddress(actor.governance);
        assertTrue(coreProxy.governance() != actor.governance);
    }

    function test_WhenAdminTriesToSetTheGovernanceAddress() external {
        // it should succesfuly set the governance address
        changePrank(actor.admin);
        coreProxy.setGovernanceAddress(actor.governance);
        assertTrue(coreProxy.governance() == actor.governance);
    }

    modifier whenAdminTransfersTheAdminControl() {
        _;
    }

    function test_REVERTWhen_Non_adminTriesToTransferAdminControl()
        external
        whenAdminTransfersTheAdminControl
    {
        // it should REVERT
        vm.expectRevert(Errors.CallerNotAdmin.selector);
        changePrank(actor.bob_channel_owner);
        coreProxy.transferPushChannelAdminControl(actor.bob_channel_owner);
        assertTrue(coreProxy.pushChannelAdmin() == actor.admin);
    }

    function test_REVERTWhen_TheNewAdminAddressIsZeroAddress()
        external
        whenAdminTransfersTheAdminControl
    {
        // it should REVERT Errors.InvalidArgument_WrongAddress
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidArgument_WrongAddress.selector,
                address(0)
            )
        );
        changePrank(actor.admin);
        coreProxy.transferPushChannelAdminControl(address(0));
        assertTrue(coreProxy.pushChannelAdmin() == actor.admin);
    }

    function test_REVERTWhen_TheNewAdminAddressIsSameAsOldAdminAddress()
        external
        whenAdminTransfersTheAdminControl
    {
        // it should REVERT
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidArgument_WrongAddress.selector,
                actor.admin
            )
        );
        changePrank(actor.admin);
        coreProxy.transferPushChannelAdminControl(actor.admin);
    }

    function test_WhenTheNewAdminAddressIsCorrect()
        external
        whenAdminTransfersTheAdminControl
    {
        // it should change the admin address
        changePrank(actor.admin);
        coreProxy.transferPushChannelAdminControl(actor.charlie_channel_owner);
        assertTrue(coreProxy.pushChannelAdmin() == actor.charlie_channel_owner);
    }

    modifier whenTheGovernanceCallsTheSetterFunctions() {
        changePrank(actor.admin);
        coreProxy.setGovernanceAddress(actor.governance);
        _;
    }

    function test_REVERTWhen_NewFeeIsGreaterThanOrEqualToAddChannelFees()
        external
        whenTheGovernanceCallsTheSetterFunctions
    {
        // it should REVERT
        uint addChannelMin = coreProxy.ADD_CHANNEL_MIN_FEES();
        vm.expectRevert();
        changePrank(actor.governance);
        coreProxy.setFeeAmount(addChannelMin);
        vm.expectRevert();
        coreProxy.setFeeAmount(addChannelMin + 1000);
    }

    function test_WhenNewFeeIsSmallerThanAddChannelFees()
        external
        whenTheGovernanceCallsTheSetterFunctions
    {
        // it should update the FEE_AMOUNT
        uint addChannelMin = coreProxy.ADD_CHANNEL_MIN_FEES();
        changePrank(actor.governance);
        coreProxy.setFeeAmount(addChannelMin - 1);
        assertEq(coreProxy.FEE_AMOUNT(), addChannelMin - 1);
    }

    //TODO - add a test for FEE_AMOUNT never being 0 after merging PR- 260

    function test_RevertWhen_TheNewValueIsZero()
        external
        whenTheGovernanceCallsTheSetterFunctions
    {
        // it should revert Errors.InvalidArg_LessThanExpected(0, _newAmount);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidArg_LessThanExpected.selector,
                0,
                0
            )
        );
        changePrank(actor.governance);
        coreProxy.setMinPoolContribution(0);
    }

    function test_WhenTheNewValueIsGreaterThanZero()
        external
        whenTheGovernanceCallsTheSetterFunctions
    {
        // it should update the MinPoolContribution
        changePrank(actor.governance);
        coreProxy.setMinPoolContribution(1);
        assertEq(coreProxy.MIN_POOL_CONTRIBUTION(), 1);
    }

    modifier whenGovernanceSetsTheMinChannelCreationFees() {
        _;
    }

    function test_WhenNewFeesIsSmallerThanMinRequiredFees()
        external
        whenTheGovernanceCallsTheSetterFunctions
        whenGovernanceSetsTheMinChannelCreationFees
    {
        uint256 minFeeRequired = coreProxy.MIN_POOL_CONTRIBUTION() +
            coreProxy.FEE_AMOUNT();
        // it should REVERT
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InvalidArg_LessThanExpected.selector,
                minFeeRequired,
                minFeeRequired - 10
            )
        );
        changePrank(actor.governance);
        coreProxy.setMinChannelCreationFees(minFeeRequired - 10);
    }

    function test_WhenNewFeesIsGreaterOrEqualToMinRequiredFees()
        external
        whenTheGovernanceCallsTheSetterFunctions
        whenGovernanceSetsTheMinChannelCreationFees
    {
        // it should update the minChannelCreationFees
        uint256 minFeeRequired = coreProxy.MIN_POOL_CONTRIBUTION() +
            coreProxy.FEE_AMOUNT();
        // it should REVERT
        changePrank(actor.governance);
        coreProxy.setMinChannelCreationFees(minFeeRequired);
        assertEq(coreProxy.ADD_CHANNEL_MIN_FEES(), minFeeRequired);
        coreProxy.setMinChannelCreationFees(minFeeRequired + 10);
        assertEq(coreProxy.ADD_CHANNEL_MIN_FEES(), minFeeRequired + 10);
    }
}
