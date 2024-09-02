// SPDX-License-Identifier: Apache 2
/// @dev TrimmedAmount is a utility library to handle token amounts with different decimals
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

/// @dev TrimmedAmount is a bit-packed representation of a token amount and its decimals.
/// @dev 64 bits: [0 - 64] amount
/// @dev 8 bits: [64 - 72] decimals
type TrimmedAmount is uint72;

using { gt as >, lt as <, sub as -, add as +, eq as ==, min, unwrap } for TrimmedAmount global;

function minUint8(uint8 a, uint8 b) pure returns (uint8) {
    return a < b ? a : b;
}

/// @notice Error when the decimals of two TrimmedAmounts are not equal
/// @dev Selector. b9cdb6c2
/// @param decimals the decimals of the first TrimmedAmount
/// @param decimalsOther the decimals of the second TrimmedAmount
error NumberOfDecimalsNotEqual(uint8 decimals, uint8 decimalsOther);

uint8 constant TRIMMED_DECIMALS = 8;

function unwrap(TrimmedAmount a) pure returns (uint72) {
    return TrimmedAmount.unwrap(a);
}

function packTrimmedAmount(uint64 amt, uint8 decimals) pure returns (TrimmedAmount) {
    // cast to u72 first to prevent overflow
    uint72 amount = uint72(amt);
    uint72 dec = uint72(decimals);

    // shift the amount to the left 8 bits
    amount <<= 8;

    return TrimmedAmount.wrap(amount | dec);
}

function eq(TrimmedAmount a, TrimmedAmount b) pure returns (bool) {
    return TrimmedAmountLib.getAmount(a) == TrimmedAmountLib.getAmount(b)
        && TrimmedAmountLib.getDecimals(a) == TrimmedAmountLib.getDecimals(b);
}

function checkDecimals(TrimmedAmount a, TrimmedAmount b) pure {
    uint8 aDecimals = TrimmedAmountLib.getDecimals(a);
    uint8 bDecimals = TrimmedAmountLib.getDecimals(b);
    if (aDecimals != bDecimals) {
        revert NumberOfDecimalsNotEqual(aDecimals, bDecimals);
    }
}

function gt(TrimmedAmount a, TrimmedAmount b) pure returns (bool) {
    checkDecimals(a, b);

    return TrimmedAmountLib.getAmount(a) > TrimmedAmountLib.getAmount(b);
}

function lt(TrimmedAmount a, TrimmedAmount b) pure returns (bool) {
    checkDecimals(a, b);

    return TrimmedAmountLib.getAmount(a) < TrimmedAmountLib.getAmount(b);
}

function sub(TrimmedAmount a, TrimmedAmount b) pure returns (TrimmedAmount) {
    checkDecimals(a, b);

    return packTrimmedAmount(
        TrimmedAmountLib.getAmount(a) - TrimmedAmountLib.getAmount(b), TrimmedAmountLib.getDecimals(a)
    );
}

function add(TrimmedAmount a, TrimmedAmount b) pure returns (TrimmedAmount) {
    checkDecimals(a, b);

    return packTrimmedAmount(
        TrimmedAmountLib.getAmount(a) + TrimmedAmountLib.getAmount(b), TrimmedAmountLib.getDecimals(b)
    );
}

function min(TrimmedAmount a, TrimmedAmount b) pure returns (TrimmedAmount) {
    checkDecimals(a, b);

    return TrimmedAmountLib.getAmount(a) < TrimmedAmountLib.getAmount(b) ? a : b;
}

library TrimmedAmountLib {
    /// @notice Error when the amount to be trimmed is greater than u64MAX.
    /// @dev Selector 0x08083b2a.
    /// @param amount The amount to be trimmed.
    error AmountTooLarge(uint256 amount);

    function getAmount(TrimmedAmount a) internal pure returns (uint64) {
        // Extract the raw integer value from TrimmedAmount
        uint72 rawValue = TrimmedAmount.unwrap(a);

        // Right shift to keep only the higher 64 bits
        uint64 result = uint64(rawValue >> 8);
        return result;
    }

    function getDecimals(TrimmedAmount a) internal pure returns (uint8) {
        return uint8(TrimmedAmount.unwrap(a) & 0xFF);
    }

    function isNull(TrimmedAmount a) internal pure returns (bool) {
        return (getAmount(a) == 0 && getDecimals(a) == 0);
    }

    function saturatingAdd(TrimmedAmount a, TrimmedAmount b) internal pure returns (TrimmedAmount) {
        checkDecimals(a, b);

        uint256 saturatedSum;
        uint64 aAmount = getAmount(a);
        uint64 bAmount = getAmount(b);
        unchecked {
            saturatedSum = uint256(aAmount) + uint256(bAmount);
            saturatedSum = saturatedSum > type(uint64).max ? type(uint64).max : saturatedSum;
        }

        return packTrimmedAmount(SafeCast.toUint64(saturatedSum), getDecimals(a));
    }

    /// @dev scale the amount from original decimals to target decimals (base 10)
    function scale(uint256 amount, uint8 fromDecimals, uint8 toDecimals) internal pure returns (uint256) {
        if (fromDecimals == toDecimals) {
            return amount;
        }

        if (fromDecimals > toDecimals) {
            return amount / (10 ** (fromDecimals - toDecimals));
        } else {
            return amount * (10 ** (toDecimals - fromDecimals));
        }
    }

    function shift(TrimmedAmount amount, uint8 toDecimals) internal pure returns (TrimmedAmount) {
        uint8 actualToDecimals = minUint8(TRIMMED_DECIMALS, toDecimals);
        return packTrimmedAmount(
            SafeCast.toUint64(scale(getAmount(amount), getDecimals(amount), actualToDecimals)), actualToDecimals
        );
    }

    function max(uint8 decimals) internal pure returns (TrimmedAmount) {
        uint8 actualDecimals = minUint8(TRIMMED_DECIMALS, decimals);
        return packTrimmedAmount(type(uint64).max, actualDecimals);
    }

    /// @dev trim the amount to target decimals.
    ///      The actual resulting decimals is the minimum of TRIMMED_DECIMALS,
    ///      fromDecimals, and toDecimals. This ensures that no dust is
    ///      destroyed on either side of the transfer.
    /// @param amt the amount to be trimmed
    /// @param fromDecimals the original decimals of the amount
    /// @param toDecimals the target decimals of the amount
    /// @return TrimmedAmount uint72 value type bit-packed with decimals
    function trim(uint256 amt, uint8 fromDecimals, uint8 toDecimals) internal pure returns (TrimmedAmount) {
        uint8 actualToDecimals = minUint8(minUint8(TRIMMED_DECIMALS, fromDecimals), toDecimals);
        uint256 amountScaled = scale(amt, fromDecimals, actualToDecimals);

        // NOTE: amt after trimming must fit into uint64 (that's the point of
        // trimming, as Solana only supports uint64 for token amts)
        return packTrimmedAmount(SafeCast.toUint64(amountScaled), actualToDecimals);
    }

    function untrim(TrimmedAmount amt, uint8 toDecimals) internal pure returns (uint256) {
        uint256 deNorm = uint256(getAmount(amt));
        uint8 fromDecimals = getDecimals(amt);
        uint256 amountScaled = scale(deNorm, fromDecimals, toDecimals);

        return amountScaled;
    }
}
