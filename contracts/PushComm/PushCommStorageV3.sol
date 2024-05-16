pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/wormhole/INttManager.sol";
import "../interfaces/wormhole/ITransceiver.sol";
import "../interfaces/wormhole/IWormholeTransceiver.sol";
import "../interfaces/wormhole/IWormholeRelayer.sol";

contract PushCommStorageV3 {
    // WORMHOLE CROSS-CHAIN STATE VARIABLES
    // ToDo: Need to decide, which of below needs setter functions or can be made constant
    IERC20 public PUSH_NTT;
    INttManager public NTT_MANAGER;
    ITransceiver public TRANSCEIVER;
    IWormholeTransceiver public WORMHOLE_TRANSCEIVER;
    IWormholeRelayer public WORMHOLE_RELAYER;

    uint16 public WORMHOLE_RECIPIENT_CHAIN; // Wormhole's Core contract recipient Chain ID
    uint256 public GAS_LIMIT = 100_000; //@audit-info Should be checked if really needed

    uint256 public ADD_CHANNEL_MIN_FEES;
}
