// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import { INttManager } from "contracts/interfaces/wormhole/INttManager.sol";
import { IRateLimiter } from "contracts/interfaces/wormhole/IRateLimiter.sol";

abstract contract MockNttManager is INttManager, IRateLimiter {
    /// @dev The duration (in seconds) it takes for the limits to fully replenish.
    uint64 public rateLimitDuration;
}
