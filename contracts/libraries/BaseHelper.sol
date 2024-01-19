pragma solidity ^0.8.20;
// SPDX-License-Identifier: MIT

/// @title BaseHelper
/// @notice Library with helper functions needed for both Push Core and Comm contract
library BaseHelper {
    /**
     * @notice This function can be used to check wether an address is a contract or not
     * @dev This method relies on extcodesize, which returns 0 for contracts in
     *      construction, since the code is only stored at the end of the constructor execution.
     * @param account address to check
     */
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}
