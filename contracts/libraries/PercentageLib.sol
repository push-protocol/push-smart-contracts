// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { GenericTypes } from "./DataTypes.sol";

/// @title PercentageLib
/// @notice Library with helper functions for percentage operations
library PercentageLib {
    using GenericTypes for GenericTypes.Percentage;

    /**
     * @notice This function calculates the percentage of a given amount using a Percentage struct.
     * @dev This function performs a simple percentage calculation.
     *      It multiplies the amount by the percentage number and divides the result by 10 raised to the power of decimal places.
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
    function calcPercentage(uint256 _amount, GenericTypes.Percentage memory _percentage) internal pure returns (uint256) {
        uint256 divisor = 10 ** _percentage.decimalPlaces;
        require(_percentage.percentageNumber <= 100 * divisor, "Percentage exceeds 100%");
        return (_amount * _percentage.percentageNumber) / ( divisor * 100);
    }
}
