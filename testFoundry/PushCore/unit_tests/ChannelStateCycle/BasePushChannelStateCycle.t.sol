pragma solidity ^0.8.20;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";

import {BaseTest} from "../../../BaseTest.t.sol";
import {PushCoreStorageV1_5} from "contracts/PushCore/PushCoreStorageV1_5.sol";

contract BasePushChannelStateCycle is BaseTest {
    bytes constant _testChannelIdentity = bytes("test-channel-hello-world");

    /* ***************
       Initializing Set-Up for Push Contracts
     *************** */

    function setUp() public virtual override {
        BaseTest.setUp();

        vm.prank(actor.admin);
        core.setMinPoolContribution(1 ether);
        MIN_POOL_CONTRIBUTION = 1 ether;

        _createChannel(actor.bob_channel_owner);
    }

    function _createChannel(address from) internal {
        approveTokens(from, address(core), ADD_CHANNEL_MIN_FEES);

        vm.prank(from);
        core.createChannelWithPUSH(
            PushCoreStorageV1_5.ChannelType.InterestBearingOpen,
            _testChannelIdentity,
            ADD_CHANNEL_MIN_FEES,
            0
        );
    }

    function _getChannelState(
        address from
    ) internal view returns (uint8 channelState) {
        (, uint8 actualChannelState, , , , , , , , , ) = core.channels(from);

        channelState = actualChannelState;
    }

    function _getChannelWeight(
        address from
    ) internal view returns (uint256 channelWeight) {
        (, , , , , , , , , uint256 actualChannelWeight, ) = core.channels(from);

        channelWeight = actualChannelWeight;
    }

    function _getChannelPoolContribution(
        address from
    ) internal view returns (uint256 channelContribution) {
        (, , , uint256 actualPoolContribution, , , , , , , ) = core.channels(
            from
        );

        channelContribution = actualPoolContribution;
    }
}
