pragma solidity ^0.8.20;

import {BasePushCoreTest} from "../BasePushCoreTest.t.sol";
import {CoreTypes} from "../../../../contracts/libraries/DataTypes.sol";
import {Errors} from "contracts/libraries/Errors.sol";

contract CreateChannelWithPUSH_Test is BasePushCoreTest {

    function setUp() public virtual override {
        BasePushCoreTest.setUp();
    }

    modifier whenNotPaused() {
        _;
    }

    function test_Revertwhen_PushAllowanceNotEnough() public whenNotPaused {
        uint256 _amountBeingTransferred = 10 ether;
        approveTokens(
            actor.bob_channel_owner,
            address(coreProxy),
            _amountBeingTransferred
        );

        vm.prank(actor.bob_channel_owner);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidArg_LessThanExpected.selector,50 ether, _amountBeingTransferred));
        coreProxy.createChannelWithPUSH(
            CoreTypes.ChannelType.InterestBearingOpen,
            _testChannelIdentity,
            _amountBeingTransferred,
            0
        );
    }

    function test_Revertwhen_AlreadyActivatedChannel() public whenNotPaused {
        vm.startPrank(actor.bob_channel_owner);
        coreProxy.createChannelWithPUSH(
            CoreTypes.ChannelType.InterestBearingOpen,
            _testChannelIdentity,
            ADD_CHANNEL_MIN_FEES,
            0
        );

        vm.expectRevert(Errors.Core_InvalidChannel.selector);
        coreProxy.createChannelWithPUSH(
            CoreTypes.ChannelType.InterestBearingOpen,
            _testChannelIdentity,
            ADD_CHANNEL_MIN_FEES,
            0
        );
        vm.stopPrank();
    }

    function test_Revertwhen_ChannelTypeNotAllowed() public whenNotPaused {
        vm.startPrank(actor.bob_channel_owner);

        vm.expectRevert(Errors.Core_InvalidChannelType.selector);
        coreProxy.createChannelWithPUSH(
            CoreTypes.ChannelType.ProtocolPromotion,
            _testChannelIdentity,
            ADD_CHANNEL_MIN_FEES,
            0
        );
        vm.stopPrank();
    }

    function test_Revertwhen_PushTranferredMoreThanApproval()
        public
        whenNotPaused
    {
        approveTokens(
            actor.bob_channel_owner,
            address(coreProxy),
            ADD_CHANNEL_MIN_FEES
        );

        vm.prank(actor.bob_channel_owner);
        vm.expectRevert(
            bytes(
                "Push::transferFrom: transfer amount exceeds spender allowance"
            )
        );
        coreProxy.createChannelWithPUSH(
            CoreTypes.ChannelType.InterestBearingOpen,
            _testChannelIdentity,
            ADD_CHANNEL_MAX_POOL_CONTRIBUTION,
            0
        );
    }

    function test_CoreGetsFeeAmount() public whenNotPaused {
        vm.startPrank(actor.bob_channel_owner);
        uint256 pushBalanceBeforeUser = pushToken.balanceOf(
            actor.bob_channel_owner
        );
        uint256 pushBalanceBeforeCore = pushToken.balanceOf(address(coreProxy));

        coreProxy.createChannelWithPUSH(
            CoreTypes.ChannelType.InterestBearingOpen,
            _testChannelIdentity,
            ADD_CHANNEL_MIN_FEES,
            0
        );

        uint256 pushBalanceAfterUser = pushToken.balanceOf(
            actor.bob_channel_owner
        );
        uint256 pushBalanceAfterCore = pushToken.balanceOf(address(coreProxy));

        assertEq(
            pushBalanceBeforeUser - pushBalanceAfterUser,
            pushBalanceAfterCore - pushBalanceBeforeCore
        );
        assertEq(
            pushBalanceAfterCore - pushBalanceBeforeCore,
            ADD_CHANNEL_MIN_FEES
        );
        vm.stopPrank();
    }

    function test_CreateChannel() public whenNotPaused {
        vm.startPrank(actor.bob_channel_owner);
        uint256 channelsCountBefore = coreProxy.channelsCount();

        coreProxy.createChannelWithPUSH(
            CoreTypes.ChannelType.InterestBearingOpen,
            _testChannelIdentity,
            ADD_CHANNEL_MIN_FEES,
            0
        );

        uint256 expectedPoolContribution = ADD_CHANNEL_MIN_FEES - FEE_AMOUNT;
        uint256 expectedBlockNumber = block.number;
        uint256 expectedChannelsCount = channelsCountBefore + 1;
        uint8 expectedChannelState = 1;
        uint256 expectedChannelWeight = (expectedPoolContribution *
            ADJUST_FOR_FLOAT) / MIN_POOL_CONTRIBUTION;
        uint256 expectedChannelExpiryTime = 0;
        uint256 expectedProtocolPoolFees = FEE_AMOUNT;

        (
            ,
            uint8 actualChannelState,
            ,
            uint256 actualPoolContribution,
            ,
            ,
            ,
            uint256 actualChannelStartBlock,
            uint256 actualChannelUpdateBlock,
            uint256 actualChannelWeight,
            uint256 actualExpiryTime
        ) = coreProxy.channels(actor.bob_channel_owner);

        assertEq(expectedPoolContribution, coreProxy.CHANNEL_POOL_FUNDS());
        assertEq(expectedChannelsCount, coreProxy.channelsCount());
        assertEq(expectedChannelState, actualChannelState);
        assertEq(expectedPoolContribution, actualPoolContribution);
        assertEq(expectedBlockNumber, actualChannelStartBlock);
        assertEq(expectedBlockNumber, actualChannelUpdateBlock);
        assertEq(expectedChannelWeight, actualChannelWeight);
        assertEq(expectedChannelExpiryTime, actualExpiryTime);
        assertEq(expectedProtocolPoolFees, coreProxy.PROTOCOL_POOL_FEES());

        vm.stopPrank();
    }

    function test_ProtocolPoolFeesCorrectForMultipleChannelsCreation() public whenNotPaused {
        vm.prank(actor.bob_channel_owner);
        coreProxy.createChannelWithPUSH(
            CoreTypes.ChannelType.InterestBearingOpen,
            _testChannelIdentity,
            ADD_CHANNEL_MIN_FEES,
            0
        );

        vm.prank(actor.charlie_channel_owner);
        coreProxy.createChannelWithPUSH(
            CoreTypes.ChannelType.InterestBearingOpen,
            _testChannelIdentity,
            ADD_CHANNEL_MIN_FEES * 2,
            0
        );

        uint256 expectedProtocolPoolFees = FEE_AMOUNT * 2;
        uint256 expectedChannelPoolFunds = (ADD_CHANNEL_MIN_FEES +
            (ADD_CHANNEL_MIN_FEES * 2)) - expectedProtocolPoolFees;
        assertEq(expectedProtocolPoolFees, coreProxy.PROTOCOL_POOL_FEES());
        assertEq(expectedChannelPoolFunds, coreProxy.CHANNEL_POOL_FUNDS());
    }

    function test_Revertwhen_ChannelExpiryLessThanBlockTimestamp() public whenNotPaused {
        vm.startPrank(actor.bob_channel_owner);

        vm.expectRevert(Errors.Core_InvalidExpiryTime.selector);
        coreProxy.createChannelWithPUSH(
            CoreTypes.ChannelType.TimeBound,
            _testChannelIdentity,
            ADD_CHANNEL_MIN_FEES,
            0
        );
        vm.stopPrank();
    }

    function test_CoreInteractWithComm() public whenNotPaused {
        vm.startPrank(actor.bob_channel_owner);
        address EPNS_ALERTER = address(0);

        bool isChannelSubscribedToOwn_Before = commProxy.isUserSubscribed(
            actor.bob_channel_owner,
            actor.bob_channel_owner
        );
        bool isChannelSubscribedToEPNS_Before = commProxy.isUserSubscribed(
            EPNS_ALERTER,
            actor.bob_channel_owner
        );
        bool isAdminSubscribedToChannel_Before = commProxy.isUserSubscribed(
            actor.bob_channel_owner,
            actor.admin
        );

        coreProxy.createChannelWithPUSH(
            CoreTypes.ChannelType.InterestBearingOpen,
            _testChannelIdentity,
            ADD_CHANNEL_MIN_FEES,
            0
        );

        bool isChannelSubscribedToOwn_After = commProxy.isUserSubscribed(
            actor.bob_channel_owner,
            actor.bob_channel_owner
        );
        bool isChannelSubscribedToEPNS_After = commProxy.isUserSubscribed(
            EPNS_ALERTER,
            actor.bob_channel_owner
        );
        bool isAdminSubscribedToChannel_After = commProxy.isUserSubscribed(
            actor.bob_channel_owner,
            actor.admin
        );

        assertEq(isChannelSubscribedToOwn_Before, false);
        assertEq(isChannelSubscribedToEPNS_Before, false);
        assertEq(isAdminSubscribedToChannel_Before, false);

        assertEq(isChannelSubscribedToOwn_After, true);
        assertEq(isChannelSubscribedToEPNS_After, true);
        assertEq(isAdminSubscribedToChannel_After, true);

        vm.stopPrank();
    }

    function test_EmitRelevantEvents() public whenNotPaused {
        vm.expectEmit(true, true, false, true, address(coreProxy));
        emit AddChannel(
            actor.bob_channel_owner,
            CoreTypes.ChannelType.InterestBearingOpen,
            _testChannelIdentity
        );

        vm.prank(actor.bob_channel_owner);
        coreProxy.createChannelWithPUSH(
            CoreTypes.ChannelType.InterestBearingOpen,
            _testChannelIdentity,
            ADD_CHANNEL_MIN_FEES,
            0
        );
    }
}