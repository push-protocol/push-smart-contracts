pragma solidity ^0.8.20;
// SPDX-License-Identifier: MIT

import { GenericTypes } from "./DataTypes.sol";

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

    /**
     * @notice This function converts a bytes32 value to an address
     * @dev This function performs type casting to convert a bytes32 to an address.
     *      It first converts the bytes32 to a uint256, then to a uint160, and finally to an address.
     *      This conversion involves truncation from left side.
     *      For example, given a bytes32 value of 0x111122223333444455556666777788889999AAAABBBBCCCCDDDDEEEEFFFFCCCC:
     *      - Using address(uint160(uint256(b))) results in an address of 0x777788889999AaAAbBbbCcccddDdeeeEfFFfCcCc
     * @param _bytes The bytes32 value to be converted to an address
     * @return address The address representation of the bytes32 value
     */
    function bytes32ToAddress(bytes32 _bytes) internal pure returns (address) {
        return address(uint160(uint256(_bytes)));
    }

    /**
     * @notice This function calculates the percentage of a given amount using a Percentage struct.
     * @dev This function performs a simple percentage calculation.
     *      It multiplies the amount by the percentage number and divides the result by 10 raised to the power of
     * decimal places.
     *      It reverts if the percentage exceeds 100.
     * @param _amount The amount for which the percentage is calculated.
     * @param _percentage The percentage to be calculated, represented as a Percentage struct.
     * @return uint256 The calculated percentage value.
     *
     * Examples:
     * - If _amount is 1000 and _percentage is {percentageNumber: 20, decimalPlaces: 0}, it means (20% of 1000).
     * - If _amount is 1000 and _percentage is {percentageNumber: 2345, decimalPlaces: 2}, it means (23.45% of 1000).
     * - If _amount is 1000 and _percentage is {percentageNumber: 56789, decimalPlaces: 3}, it means (56.789% of 1000).
     */
    function calcPercentage(
        uint256 _amount,
        GenericTypes.Percentage memory _percentage
    )
        internal
        pure
        returns (uint256)
    {
        uint256 divisor = 10 ** _percentage.decimalPlaces;
        require(_percentage.percentageNumber <= 100 * divisor, "Percentage exceeds 100%");
        return (_amount * _percentage.percentageNumber) / (divisor * 100);
    }
}
