// SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

import { PushCommV3 } from "contracts/PushComm/PushCommV3.sol";
import { CrossChainRequestTypes, CoreTypes } from "../../contracts/libraries/DataTypes.sol";

contract CreateChatRequestFromComm is Test {
    PushCommV3 public commProxy = PushCommV3(0x2ddB499C3a35a60c809d878eFf5Fa248bb5eAdbd);
    // EPNSCommProxy public epnsCommProxy = EPNSCommProxy(payable(0x96891F643777dF202b153DB9956226112FfA34a9));

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        address account = vm.addr(vm.envUint("PRIVATE_KEY"));

        uint16 _recipientChain = 10004;
        uint256 _amount = 15 ether;
        uint256 _gasLimit = 250_000;

        // Encode the payload
        bytes memory payload = abi.encode(0xE72b3dF298c2fb11e9C29D741A1B70C00b86A523);

        uint256 msgFee = commProxy.quoteMsgRelayCost(_recipientChain, _gasLimit);
        uint256 tokenFee = commProxy.quoteTokenBridgingCost();

        commProxy.createCrossChainRequest{value: msgFee + tokenFee}(CrossChainRequestTypes.CrossChainFunction.IncentivizedChat, payload, _amount, _gasLimit);

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
