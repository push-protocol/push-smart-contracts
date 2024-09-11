// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BaseCCRTest } from "../BaseCCR.t.sol";

import { TrimmedAmountLib, TrimmedAmount, eq } from "contracts/libraries/wormhole-lib/TrimmedAmount.sol";
import { MockNttManager } from "contracts/mocks/MockNttManager.sol";


contract RateLimitNtt is BaseCCRTest {
    using TrimmedAmountLib for uint256;
    using TrimmedAmountLib for TrimmedAmount;

    TrimmedAmount public maxWindowTrimmedAmount;

    function setUp() public override {
        BaseCCRTest.setUp();
        sourceAddress = toWormholeFormat(address(commProxy));

        maxWindowTrimmedAmount = MAX_WINDOW.trim(18, 18);
    }

    function testRateLimitConfigs() public {
        checkRateLimitConfigs(SourceChain.NTT_MANAGER, DestChain.DestChainId);

        setUpDestChain();
        checkRateLimitConfigs(DestChain.NTT_MANAGER, SourceChain.SourceChainId);
    }

    function checkRateLimitConfigs(address nttManager, uint16 peerId) public {
        assertEq(MockNttManager(nttManager).rateLimitDuration(), RATE_LIMIT_DURATION);

        assertTrue(eq(MockNttManager(nttManager).getOutboundLimitParams().limit, maxWindowTrimmedAmount));
        assertTrue(eq(MockNttManager(nttManager).getInboundLimitParams(peerId).limit, maxWindowTrimmedAmount));
    }
}
