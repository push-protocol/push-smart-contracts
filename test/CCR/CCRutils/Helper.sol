// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;
import { BasePushCommTest } from "../../PushComm/unit_tests/BasePushCommTest.t.sol";
import { console } from "forge-std/console.sol";
import "contracts/token/Push.sol";
import { CoreTypes, CrossChainRequestTypes } from "../../../../contracts/libraries/DataTypes.sol";

import "contracts/interfaces/wormhole/ITransceiver.sol";
import "contracts/interfaces/wormhole/IWormholeRelayer.sol";
import {CCRConfig} from "./CCRConfig.sol";
contract Helper is BasePushCommTest, CCRConfig{
    CrossChainRequestTypes.ArbitraryRequestPayload _arbitraryPayload;
    CrossChainRequestTypes.SpecificRequestPayload _specificPayload;

    bytes requestPayload;

    bytes[] additionalVaas;
    bytes32 deliveryHash = 0x97f309914aa8b670f4a9212ba06670557b0c92a7ad853b637be8a9a6c2ea6447;
    bytes32 sourceAddress;
    uint16 sourceChain = ArbSepolia.SourceChainId;

    function switchChains(string memory url) public {
        vm.createSelectFork(url);
    }

    function getPushTokenOnfork(address _addr, uint256 _amount) public {
        changePrank(ArbSepolia.PushHolder);
        pushNttToken.transfer(_addr, _amount);

        changePrank(_addr);
        pushNttToken.approve(address(commProxy), type(uint256).max);
    }

    function setUpChain1(string memory url) internal {
        switchChains(url);
        BasePushCommTest.setUp();
        pushNttToken = Push(ArbSepolia.PUSH_NTT_SOURCE);

        getPushTokenOnfork(actor.bob_channel_owner, 1000e18);
        getPushTokenOnfork(actor.charlie_channel_owner, 1000e18);

        changePrank(actor.admin);
        commProxy.initializeBridgeContracts(
            ArbSepolia.PUSH_NTT_SOURCE,
            ArbSepolia.NTT_MANAGER,
            ITransceiver(ArbSepolia.TRANSCEIVER),
            ArbSepolia.wormholeTransceiverChain1,
           IWormholeRelayer(ArbSepolia.WORMHOLE_RELAYER_SOURCE),
            ArbSepolia.WORMHOLE_RECIPIENT_CHAIN
        );
    }

    function setUpChain2(string memory url) internal {
        switchChains(url);
        BasePushCommTest.setUp();
        pushNttToken = Push(EthSepolia.PUSH_NTT_DEST);
        changePrank(actor.admin);
        coreProxy.setWormholeRelayer(EthSepolia.WORMHOLE_RELAYER_DEST);
        coreProxy.setRegisteredSender(ArbSepolia.SourceChainId, toWormholeFormat(address(commProxy)));
    }

    function toWormholeFormat(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    function getPoolFundsAndFees(uint256 _amountDeposited)
        internal
        view
        returns (uint256 CHANNEL_POOL_FUNDS, uint256 PROTOCOL_POOL_FEES)
    {
        uint256 poolFeeAmount = coreProxy.FEE_AMOUNT();
        uint256 poolFundAmount = _amountDeposited - poolFeeAmount;
        //store funds in pool_funds & pool_fees
        CHANNEL_POOL_FUNDS = coreProxy.CHANNEL_POOL_FUNDS() + poolFundAmount;
        PROTOCOL_POOL_FEES = coreProxy.PROTOCOL_POOL_FEES() + poolFeeAmount;
    }

    function getSpecificPayload(
        bytes4 functionSig,
        address amountRecipient,
        uint256 amount,
        string memory channleStr
    )
        internal
        view
        returns (CrossChainRequestTypes.SpecificRequestPayload memory payload, bytes memory reqPayload)
    {
        CrossChainRequestTypes.ChannelPayload memory channelData = CrossChainRequestTypes.ChannelPayload(
            channleStr, CoreTypes.ChannelType.InterestBearingMutual, 0, _testChannelUpdatedIdentity
        );

        payload = CrossChainRequestTypes.SpecificRequestPayload(functionSig, amountRecipient, amount, channelData);

        bytes memory specificReqPayload = abi.encode(payload);
        reqPayload =
            abi.encode(specificReqPayload, actor.bob_channel_owner, CrossChainRequestTypes.RequestType.SpecificReq);
    }

    function getArbitraryPayload(
        bytes4 functionSig,
        uint8 feeId,
        uint8 feePercentage,
        address amountRecipient,
        uint256 amount
    )
        internal
        view
        returns (CrossChainRequestTypes.ArbitraryRequestPayload memory _payload, bytes memory _requestPayload)
    {
        _payload =
            CrossChainRequestTypes.ArbitraryRequestPayload(functionSig, feeId, feePercentage, amountRecipient, amount);

            
        bytes memory arbitraryReqPayload = abi.encode(_payload);
        _requestPayload = abi.encode(arbitraryReqPayload,actor.bob_channel_owner, CrossChainRequestTypes.RequestType.ArbitraryReq);
    }

    function receiveWormholeMessage(bytes memory _requestPayload) internal {
        changePrank(EthSepolia.WORMHOLE_RELAYER_DEST);
        coreProxy.receiveWormholeMessages(_requestPayload, additionalVaas, sourceAddress, sourceChain, deliveryHash);
    }
}