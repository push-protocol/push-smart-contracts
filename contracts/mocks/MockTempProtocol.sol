// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

interface IPUSH {
    /**
     * @dev resets holder weight for the callee
     */
    function resetHolderWeight(address holder) external;
}

contract MockTempProtocol {
    constructor() { }

    // To claim reward and reset token holder weight
    function claimReward(address token) external {
        IPUSH push = IPUSH(token);
        push.resetHolderWeight(msg.sender);
    }
}
