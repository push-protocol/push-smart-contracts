// SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

import { PushCommV3 } from "contracts/PushComm/PushCommV3.sol";
import { CrossChainRequestTypes, CoreTypes } from "../../contracts/libraries/DataTypes.sol";

contract CreateChannelFromComm is Test {
    PushCommV3 public commProxy = PushCommV3(0x2ddB499C3a35a60c809d878eFf5Fa248bb5eAdbd);
    // EPNSCommProxy public epnsCommProxy = EPNSCommProxy(payable(0x96891F643777dF202b153DB9956226112FfA34a9));

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        address account = vm.addr(vm.envUint("PRIVATE_KEY"));

        uint16 _recipientChain = 10004;
        uint256 _amount = 10 ether;
        uint256 _gasLimit = 10_000_000;

        CrossChainRequestTypes.ArbitraryRequestPayload memory _payload = CrossChainRequestTypes.ArbitraryRequestPayload({
            functionSig: 0x12345678,
            feeId: 42,
            feePercentage: 10,
            amountRecipient: 0xE72b3dF298c2fb11e9C29D741A1B70C00b86A523,
            amount: _amount
        });

        uint256 msgFee = commProxy.quoteMsgRelayCost(_recipientChain, _gasLimit);
        uint256 tokenFee = commProxy.quoteTokenBridgingCost();

        bytes memory payload = abi.encode(_payload);

        commProxy.createCrossChainRequest{value: msgFee + tokenFee}(CrossChainRequestTypes.CrossChainFunction.ArbitraryRequest, payload, _amount, _gasLimit);

        vm.stopBroadcast();
    }
}
