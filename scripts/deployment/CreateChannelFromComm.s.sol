// SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

import { PushCommV3 } from "contracts/PushComm/PushCommV3.sol";
import { PushCoreV3 } from "contracts/PushCore/PushCoreV3.sol";
import { BaseHelper } from "contracts/libraries/BaseHelper.sol";
import { CrossChainRequestTypes, CoreTypes } from "../../contracts/libraries/DataTypes.sol";

contract CreateChannelFromComm is Test {
    PushCommV3 public commProxy = PushCommV3(0x2ddB499C3a35a60c809d878eFf5Fa248bb5eAdbd);
    PushCoreV3 public coreProxy = PushCoreV3(0x09676C46aaE81a2E0e13ce201040400765BFe329);
    // EPNSCommProxy public epnsCommProxy = EPNSCommProxy(payable(0x96891F643777dF202b153DB9956226112FfA34a9));

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        address account = vm.addr(vm.envUint("PRIVATE_KEY"));

        uint16 _recipientChain = 10003;
        uint256 _amount = 50 ether;
        uint256 _gasLimit = 500_000;
        
        uint256 msgFee = commProxy.quoteMsgRelayCost(_recipientChain, _gasLimit);
        uint256 tokenFee = commProxy.quoteTokenBridgingCost();

        CoreTypes.ChannelType channelType = CoreTypes.ChannelType.InterestBearingOpen;
        bytes memory channelIdentity = hex"63b2e80cc302c7a13f5c3b0c1e9ef25c46c7f2de90b7ddbe933f8f518374c6f6";
        uint256 channelExpiry = 0;

         // Encode the payload
        bytes memory payload = abi.encode(channelType, channelIdentity, channelExpiry);

        commProxy.createCrossChainRequest{value: msgFee + tokenFee}(CrossChainRequestTypes.CrossChainFunction.AddChannel, payload, _amount, _gasLimit);

        // vm.prank(0x7B1bD7a6b4E61c2a123AC6BC2cbfC614437D0470);
        // bytes memory requestPayload = abi.encode(CrossChainRequestTypes.CrossChainFunction.AddChannel, payload, msg.sender);
        // bytes32 sourceAddress = BaseHelper.addressToBytes32(0x2ddB499C3a35a60c809d878eFf5Fa248bb5eAdbd);
        // bytes[] memory arr;
        // coreProxy.receiveWormholeMessages(requestPayload, arr, sourceAddress, 10004, sourceAddress);

        vm.stopBroadcast();
    }

    function toAsciiString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(42);
        s[0] = '0';
        s[1] = 'x';
        for (uint i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint(uint160(x)) / (2**(8*(19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2+i*2] = char(hi);
            s[3+i*2] = char(lo);            
        }
        return string(s);
    }

    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }
}
