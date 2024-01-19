pragma solidity ^0.8.20;
// SPDX-License-Identifier: MIT

/// @title BaseHelper
/// @notice Library with helper functions needed for both Push Core and Comm contract
library BaseHelper {
    function isContract(address account) internal view returns (bool) {

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}
