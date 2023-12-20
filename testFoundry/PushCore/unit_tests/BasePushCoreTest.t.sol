pragma solidity ^0.8.20;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";

import {BaseTest} from "../../BaseTest.t.sol";
import {PushCoreStorageV1_5} from "contracts/PushCore/PushCoreStorageV1_5.sol";

contract BasePushCoreTest is BaseTest {
    bytes constant _testChannelIdentity = bytes("test-channel-hello-world");
    bytes constant _testChannelUpdatedIdentity = bytes("test-updated-channel-hello-world");

    /* ***************
       Initializing Set-Up for Push Contracts
     *************** */

    function setUp() public virtual override {
        BaseTest.setUp();

        vm.prank(actor.admin);
        coreProxy.setMinPoolContribution(1 ether);
        MIN_POOL_CONTRIBUTION = 1 ether;
    }

    function _createChannel(address from) internal {
        vm.prank(from);
        coreProxy.createChannelWithPUSH(
            PushCoreStorageV1_5.ChannelType.InterestBearingOpen,
            _testChannelIdentity,
            ADD_CHANNEL_MIN_FEES,
            0
        );
    }

    function _getChannelState(
        address _channel
    ) internal view returns (uint8 channelState) {
        (, uint8 actualChannelState, , , , , , , , , ) = coreProxy.channels(_channel);

        channelState = actualChannelState;
    }

    function _getChannelWeight(
        address _channel
    ) internal view returns (uint256 channelWeight) {
        (, , , , , , , , , uint256 actualChannelWeight, ) = coreProxy.channels(_channel);

        channelWeight = actualChannelWeight;
    }

    function _getChannelUpdateBlock(
        address _channel
    ) internal view returns (uint256 channelUpdateBlock) {
        (, , , , , , , , uint256 actualChannelUpdateBlock, , ) = coreProxy.channels(_channel);

        channelUpdateBlock = actualChannelUpdateBlock;
    }

    function _getChannelPoolContribution(
        address _channel
    ) internal view returns (uint256 channelContribution) {
        (, , , uint256 actualPoolContribution, , , , , , , ) = coreProxy.channels(
            _channel
        );

        channelContribution = actualPoolContribution;
    }
}
