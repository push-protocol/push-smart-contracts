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

    /**
     * @notice This function converts an address to a bytes32 value
     * @dev This function performs type casting to convert an address to a bytes32.
     *      It first converts the address to a uint160, then to a uint256, and finally to a bytes32.
     * @param _addr The EVM address to be converted to bytes32
     * @return bytes32 The bytes32 representation of the address
     */
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
