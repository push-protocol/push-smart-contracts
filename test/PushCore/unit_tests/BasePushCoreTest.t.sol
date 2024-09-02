pragma solidity ^0.8.20;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";

import { BaseTest } from "../../BaseTest.t.sol";
import { CoreTypes } from "contracts/libraries/DataTypes.sol";

contract BasePushCoreTest is BaseTest {
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
            CoreTypes.ChannelType.InterestBearingOpen, _testChannelIdentity, ADD_CHANNEL_MIN_FEES, 0
        );
    }

    function _getChannelState(address _channel) internal view returns (uint8 channelState) {
        bytes32 _channelBytesID = createChannelCreatorsID(_channel);
        (, uint8 actualChannelState,,,,,,,,,) = coreProxy.channelInfo(_channelBytesID);

        channelState = actualChannelState;
    }

    function _getChannelWeight(address _channel) internal view returns (uint256 channelWeight) {
        bytes32 _channelBytesID = createChannelCreatorsID(_channel);
        (,,,,,,,,, uint256 actualChannelWeight,) = coreProxy.channelInfo(_channelBytesID);

        channelWeight = actualChannelWeight;
    }

    function _getChannelExpiryTime(address _channel) internal view returns (uint256 channelExpiryTime) {
        bytes32 _channelBytesID = createChannelCreatorsID(_channel);
        (,,,,,,,,,, uint256 actualChannelExpiryTime) = coreProxy.channelInfo(_channelBytesID);

        channelExpiryTime = actualChannelExpiryTime;
    }

    function _getChannelUpdateBlock(address _channel) internal view returns (uint256 channelUpdateBlock) {
        bytes32 _channelBytesID = createChannelCreatorsID(_channel);
        (,,,,,,,, uint256 actualChannelUpdateBlock,,) = coreProxy.channelInfo(_channelBytesID);

        channelUpdateBlock = actualChannelUpdateBlock;
    }

    function _getChannelPoolContribution(address _channel) internal view returns (uint256 channelContribution) {
        bytes32 _channelBytesID = createChannelCreatorsID(_channel);
        (,,, uint256 actualPoolContribution,,,,,,,) = coreProxy.channelInfo(_channelBytesID);

        channelContribution = actualPoolContribution;
    }

    function _getVerifiedBy(address _channel) internal view returns (address _verifiedBy) {
        bytes32 _channelBytesID = createChannelCreatorsID(_channel);
        (,, _verifiedBy,,,,,,,,) = coreProxy.channelInfo(_channelBytesID);
    }
}
