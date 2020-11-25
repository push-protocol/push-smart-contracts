// Sources flattened with buidler v1.4.7 https://buidler.dev

// File @openzeppelin/contracts/math/SafeMath.sol@v3.2.0

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}


// File @openzeppelin/contracts/proxy/Initializable.sol@v3.2.0

// SPDX-License-Identifier: MIT

pragma solidity >=0.4.24 <0.7.0;


/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 * 
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {UpgradeableProxy-constructor}.
 * 
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 */
abstract contract Initializable {

    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        require(_initializing || _isConstructor() || !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    /// @dev Returns true if and only if the function is running in the constructor
    function _isConstructor() private view returns (bool) {
        // extcodesize checks the size of the code stored in an address, and
        // address returns the current address. Since the code is still not
        // deployed when running a constructor, any checks on its code size will
        // yield zero, making it an effective way to detect if a contract is
        // under construction or not.
        address self = address(this);
        uint256 cs;
        // solhint-disable-next-line no-inline-assembly
        assembly { cs := extcodesize(self) }
        return cs == 0;
    }
}


// File @openzeppelin/contracts/token/ERC20/IERC20.sol@v3.2.0

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


// File @openzeppelin/contracts/utils/Address.sol@v3.2.0

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.2;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies in extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
      return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        return _functionCallWithValue(target, data, value, errorMessage);
    }

    function _functionCallWithValue(address target, bytes memory data, uint256 weiValue, string memory errorMessage) private returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: weiValue }(data);
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}


// File @openzeppelin/contracts/token/ERC20/SafeERC20.sol@v3.2.0

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;




/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}


// File @openzeppelin/contracts/utils/ReentrancyGuard.sol@v3.2.0

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor () internal {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}


// File hardhat/console.sol@v1.4.7

// SPDX-License-Identifier: MIT
pragma solidity >= 0.4.22 <0.8.0;

library console {
	address constant CONSOLE_ADDRESS = address(0x000000000000000000636F6e736F6c652e6c6f67);

	function _sendLogPayload(bytes memory payload) private view {
		uint256 payloadLength = payload.length;
		address consoleAddress = CONSOLE_ADDRESS;
		assembly {
			let payloadStart := add(payload, 32)
			let r := staticcall(gas(), consoleAddress, payloadStart, payloadLength, 0, 0)
		}
	}

	function log() internal view {
		_sendLogPayload(abi.encodeWithSignature("log()"));
	}

	function logInt(int p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(int)", p0));
	}

	function logUint(uint p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint)", p0));
	}

	function logString(string memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string)", p0));
	}

	function logBool(bool p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
	}

	function logAddress(address p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address)", p0));
	}

	function logBytes(bytes memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes)", p0));
	}

	function logByte(byte p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(byte)", p0));
	}

	function logBytes1(bytes1 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes1)", p0));
	}

	function logBytes2(bytes2 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes2)", p0));
	}

	function logBytes3(bytes3 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes3)", p0));
	}

	function logBytes4(bytes4 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes4)", p0));
	}

	function logBytes5(bytes5 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes5)", p0));
	}

	function logBytes6(bytes6 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes6)", p0));
	}

	function logBytes7(bytes7 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes7)", p0));
	}

	function logBytes8(bytes8 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes8)", p0));
	}

	function logBytes9(bytes9 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes9)", p0));
	}

	function logBytes10(bytes10 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes10)", p0));
	}

	function logBytes11(bytes11 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes11)", p0));
	}

	function logBytes12(bytes12 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes12)", p0));
	}

	function logBytes13(bytes13 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes13)", p0));
	}

	function logBytes14(bytes14 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes14)", p0));
	}

	function logBytes15(bytes15 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes15)", p0));
	}

	function logBytes16(bytes16 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes16)", p0));
	}

	function logBytes17(bytes17 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes17)", p0));
	}

	function logBytes18(bytes18 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes18)", p0));
	}

	function logBytes19(bytes19 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes19)", p0));
	}

	function logBytes20(bytes20 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes20)", p0));
	}

	function logBytes21(bytes21 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes21)", p0));
	}

	function logBytes22(bytes22 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes22)", p0));
	}

	function logBytes23(bytes23 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes23)", p0));
	}

	function logBytes24(bytes24 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes24)", p0));
	}

	function logBytes25(bytes25 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes25)", p0));
	}

	function logBytes26(bytes26 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes26)", p0));
	}

	function logBytes27(bytes27 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes27)", p0));
	}

	function logBytes28(bytes28 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes28)", p0));
	}

	function logBytes29(bytes29 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes29)", p0));
	}

	function logBytes30(bytes30 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes30)", p0));
	}

	function logBytes31(bytes31 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes31)", p0));
	}

	function logBytes32(bytes32 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes32)", p0));
	}

	function log(uint p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint)", p0));
	}

	function log(string memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string)", p0));
	}

	function log(bool p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
	}

	function log(address p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address)", p0));
	}

	function log(uint p0, uint p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint)", p0, p1));
	}

	function log(uint p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string)", p0, p1));
	}

	function log(uint p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool)", p0, p1));
	}

	function log(uint p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address)", p0, p1));
	}

	function log(string memory p0, uint p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint)", p0, p1));
	}

	function log(string memory p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string)", p0, p1));
	}

	function log(string memory p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool)", p0, p1));
	}

	function log(string memory p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address)", p0, p1));
	}

	function log(bool p0, uint p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint)", p0, p1));
	}

	function log(bool p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string)", p0, p1));
	}

	function log(bool p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool)", p0, p1));
	}

	function log(bool p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address)", p0, p1));
	}

	function log(address p0, uint p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint)", p0, p1));
	}

	function log(address p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string)", p0, p1));
	}

	function log(address p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool)", p0, p1));
	}

	function log(address p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address)", p0, p1));
	}

	function log(uint p0, uint p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint)", p0, p1, p2));
	}

	function log(uint p0, uint p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string)", p0, p1, p2));
	}

	function log(uint p0, uint p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool)", p0, p1, p2));
	}

	function log(uint p0, uint p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address)", p0, p1, p2));
	}

	function log(uint p0, string memory p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint)", p0, p1, p2));
	}

	function log(uint p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string)", p0, p1, p2));
	}

	function log(uint p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool)", p0, p1, p2));
	}

	function log(uint p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address)", p0, p1, p2));
	}

	function log(uint p0, bool p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint)", p0, p1, p2));
	}

	function log(uint p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string)", p0, p1, p2));
	}

	function log(uint p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool)", p0, p1, p2));
	}

	function log(uint p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address)", p0, p1, p2));
	}

	function log(uint p0, address p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint)", p0, p1, p2));
	}

	function log(uint p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string)", p0, p1, p2));
	}

	function log(uint p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool)", p0, p1, p2));
	}

	function log(uint p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address)", p0, p1, p2));
	}

	function log(string memory p0, uint p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint)", p0, p1, p2));
	}

	function log(string memory p0, uint p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string)", p0, p1, p2));
	}

	function log(string memory p0, uint p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool)", p0, p1, p2));
	}

	function log(string memory p0, uint p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address)", p0, p1, p2));
	}

	function log(string memory p0, address p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint)", p0, p1, p2));
	}

	function log(string memory p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string)", p0, p1, p2));
	}

	function log(string memory p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool)", p0, p1, p2));
	}

	function log(string memory p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address)", p0, p1, p2));
	}

	function log(bool p0, uint p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint)", p0, p1, p2));
	}

	function log(bool p0, uint p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string)", p0, p1, p2));
	}

	function log(bool p0, uint p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool)", p0, p1, p2));
	}

	function log(bool p0, uint p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address)", p0, p1, p2));
	}

	function log(bool p0, bool p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint)", p0, p1, p2));
	}

	function log(bool p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string)", p0, p1, p2));
	}

	function log(bool p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool)", p0, p1, p2));
	}

	function log(bool p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address)", p0, p1, p2));
	}

	function log(bool p0, address p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint)", p0, p1, p2));
	}

	function log(bool p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string)", p0, p1, p2));
	}

	function log(bool p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool)", p0, p1, p2));
	}

	function log(bool p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address)", p0, p1, p2));
	}

	function log(address p0, uint p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint)", p0, p1, p2));
	}

	function log(address p0, uint p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string)", p0, p1, p2));
	}

	function log(address p0, uint p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool)", p0, p1, p2));
	}

	function log(address p0, uint p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address)", p0, p1, p2));
	}

	function log(address p0, string memory p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint)", p0, p1, p2));
	}

	function log(address p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string)", p0, p1, p2));
	}

	function log(address p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool)", p0, p1, p2));
	}

	function log(address p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address)", p0, p1, p2));
	}

	function log(address p0, bool p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint)", p0, p1, p2));
	}

	function log(address p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string)", p0, p1, p2));
	}

	function log(address p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool)", p0, p1, p2));
	}

	function log(address p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address)", p0, p1, p2));
	}

	function log(address p0, address p1, uint p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint)", p0, p1, p2));
	}

	function log(address p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string)", p0, p1, p2));
	}

	function log(address p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool)", p0, p1, p2));
	}

	function log(address p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address)", p0, p1, p2));
	}

	function log(uint p0, uint p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,string)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,uint,address)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,string)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,string,address)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,string)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,bool,address)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,string)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, uint p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,uint,address,address)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,string)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,uint,address)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string,string)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,string,address)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,string)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,bool,address)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address,string)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,string,address,address)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,string)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,uint,address)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,string)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,string,address)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,string)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,bool,address,address)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,string)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,uint,address)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string,string)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,string,address)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,string)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,bool,address)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address,uint)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address,string)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address,bool)", p0, p1, p2, p3));
	}

	function log(uint p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint,address,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,uint,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,uint)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,uint,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,uint)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,uint)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,uint,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string,uint)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,uint)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address,uint)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint,uint)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,uint)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,uint)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,uint)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,uint)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,uint)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,uint)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,uint)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint,uint)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,uint)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,uint)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, uint p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,uint)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,address)", p0, p1, p2, p3));
	}

}


// File contracts/EPNSCore.sol

pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;







interface ILendingPoolAddressesProvider {
    function getLendingPoolCore() external view returns (address payable);

    function getLendingPool() external view returns (address);
}

interface ILendingPool {
    function addressesProvider() external view returns (address);

    function deposit(address _reserve, uint256 _amount, uint16 _referralCode) external payable;

    function redeemUnderlying(address _reserve, address _user, uint256 _amount) external;

    function borrow(address _reserve, uint256 _amount, uint256 _interestRateMode, uint16 _referralCode) external;

    function repay(address _reserve, uint256 _amount, address _onBehalfOf) external payable;

    function swapBorrowRateMode(address _reserve) external;

    function rebalanceFixedBorrowRate(address _reserve, address _user) external;

    function setUserUseReserveAsCollateral(address _reserve, bool _useAsCollateral) external;

    function liquidationCall(address _collateral, address _reserve, address _user, uint256 _purchaseAmount, bool _receiveAToken) external payable;

    function flashLoan(address _receiver, address _reserve, uint256 _amount, bytes calldata _params) external;

    function getReserveConfigurationData(address _reserve) external view returns (uint256 ltv, uint256 liquidationThreshold, uint256 liquidationDiscount, address interestRateStrategyAddress, bool usageAsCollateralEnabled, bool borrowingEnabled, bool fixedBorrowRateEnabled, bool isActive);

    function getReserveData(address _reserve) external view returns (uint256 totalLiquidity, uint256 availableLiquidity, uint256 totalBorrowsFixed, uint256 totalBorrowsVariable, uint256 liquidityRate, uint256 variableBorrowRate, uint256 fixedBorrowRate, uint256 averageFixedBorrowRate, uint256 utilizationRate, uint256 liquidityIndex, uint256 variableBorrowIndex, address aTokenAddress, uint40 lastUpdateTimestamp);

    function getUserAccountData(address _user) external view returns (uint256 totalLiquidityETH, uint256 totalCollateralETH, uint256 totalBorrowsETH, uint256 availableBorrowsETH, uint256 currentLiquidationThreshold, uint256 ltv, uint256 healthFactor);

    function getUserReserveData(address _reserve, address _user) external view returns (uint256 currentATokenBalance, uint256 currentUnderlyingBalance, uint256 currentBorrowBalance, uint256 principalBorrowBalance, uint256 borrowRateMode, uint256 borrowRate, uint256 liquidityRate, uint256 originationFee, uint256 variableBorrowIndex, uint256 lastUpdateTimestamp, bool usageAsCollateralEnabled);

    function getReserves() external view;
}


interface IEPNSCore {}

contract EPNSCore is Initializable, ReentrancyGuard  {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    /* ***************
    * DEFINE ENUMS AND CONSTANTS
    *************** */
    // For Message Type
    enum ChannelType {InterestBearingChannel, NonInterestBearing}
    enum ChannelAction {ChannelRemoved, ChannelAdded, ChannelUpdated}
    enum SubscriberAction {SubscriberRemoved, SubscriberAdded, SubscriberUpdated}



    /* ***************
    // DEFINE STRUCTURES AND VARIABLES
    *************** */


    /* Users are everyone in the EPNS Ecosystem
     * the struct creates a registry for public key signing and maintains the users subscribed channels
    */
    struct User {
        bool userActivated; // Whether a user is activated or not
        bool publicKeyRegistered; // Will be false until public key is emitted
        bool channellized; // Marks if a user has opened a channel

        uint userStartBlock; // Events should not be polled before this block as user doesn't exist
        uint subscribedCount; // Keep track of subscribers

        uint timeWeightedBalance;

        // keep track of all subscribed channels
        mapping(address => uint) subscribed;
        mapping(uint => address) mapAddressSubscribed;

        // keep track of greylist, useful for unsubscribe so the channel can't subscribe you back
        mapping(address => bool) graylistedChannels;
    }


    /* Channels are addresses who have wants their broadcasting network,
    * the channel can never go back to being a plain user but can be marked inactive
    */
    struct Channel {
        // Channel Type
        ChannelType channelType;

        // Flag to deactive channel
        bool deactivated;

        // Channel Pool Contribution
        uint poolContribution;
        uint memberCount;

        uint channelHistoricalZ;
        uint channelFairShareCount;
        uint channelLastUpdate; // The last update block number, used to calculate fair share

        // To calculate fair share of profit from the pool of channels generating interest
        uint channelStartBlock; // Helps in defining when channel started for pool and profit calculation
        uint channelWeight; // The individual weight to be applied as per pool contribution

        // To keep track of subscribers info
        mapping(address => bool) memberExists;

        // For iterable mapping
        mapping(address => uint) members;
        mapping(uint => address) mapAddressMember; // This maps to the user

        // To calculate fair share of profit for a subscriber
        // The historical constant that is applied with (wnx0 + wnx1 + .... + wnxZ)
        // Read more in the repo: https://github.com/ethereum-push-notification-system
        mapping(address => uint) memberLastUpdate;
    }

    /* Create for testnet strict owner only channel whitelist
     * Will not be available on mainnet since that has real defi involed, use staging contract
     * for developers looking to try on hand
    */
    mapping(address => bool) channelizationWhitelist;

    // To keep track of channels
    mapping(address => Channel) public channels;
    mapping(uint => address) public mapAddressChannels;

    // To keep a track of all users
    mapping(address => User) public users;
    mapping(uint => address) public mapAddressUsers;

    // To keep track of interest claimed and interest in wallet
    mapping(address => uint) public usersInterestClaimed;
    mapping(address => uint) public usersInterestInWallet;


    bytes EPNS_FIRST_MESSAGE_HASH;


    /**
        Address Lists
    */
    address public lendingPoolProviderAddress;
    address public daiAddress;
    address public aDaiAddress;
    address public governance;

    // Track assetCounts
    uint public channelsCount;
    uint public usersCount;

    // Helper for calculating fair share of pool, group are all channels, renamed to avoid confusion
    uint public groupNormalizedWeight;
    uint public groupHistoricalZ;
    uint public groupLastUpdate;
    uint public groupFairShareCount;

    /*
        For maintaining the #DeFi finances
    */
    uint public poolFunds;
    uint public ownerDaiFunds;

    uint public REFERRAL_CODE;

    uint ADD_CHANNEL_MAX_POOL_CONTRIBUTION;

    uint UPDATE_CHANNEL_POOL_CONTRIBUTION;
    uint DELEGATED_CONTRACT_FEES;

    uint ADJUST_FOR_FLOAT;
    uint ADD_CHANNEL_MIN_POOL_CONTRIBUTION;



    /* ***************
    * Events
    *************** */
    // For Public Key Registration Emit
    event PublicKeyRegistered(address indexed owner, bytes publickey);

    // Channel Related | // This Event is listened by on All Infra Services
    event AddChannel(address indexed channel, bytes identity);
    event UpdateChannel(address indexed channel, bytes identity);
    event DeactivateChannel(address indexed channel);

    // Subscribe / Unsubscribe | This Event is listened by on All Infra Services
    event Subscribe(address indexed channel, address indexed user);
    event Unsubscribe(address indexed channel, address indexed user);

    // Send Notification | This Event is listened by on All Infra Services
    event SendNotification(address indexed channel, address indexed recipient, bytes identity);

    // Emit Claimed Interest
    event InterestClaimed(address indexed user, uint indexed amount);

    // Withdrawl Related
    event Donation(address indexed donator, uint amt);
    event Withdrawal(address indexed to, address token, uint amount);

    /* ***************
    * INITIALIZER,
    *************** */

    function initialize(
        address _governance,
        address _lendingPoolProviderAddress,
        address _daiAddress,
        address _aDaiAddress,
        uint _referralCode
    ) public initializer returns (bool success) {


        // setup addresses
        governance = _governance; // multisig/timelock, also controls the proxy
        lendingPoolProviderAddress = _lendingPoolProviderAddress;
        daiAddress = _daiAddress;
        aDaiAddress = _aDaiAddress;
        REFERRAL_CODE = _referralCode;


        UPDATE_CHANNEL_POOL_CONTRIBUTION = 500 * 10 ** 18; // 500 DAI or above to update the channel
        DELEGATED_CONTRACT_FEES = 1 * 10 ** 17; // 0.1 DAI to perform any delegate call

        ADD_CHANNEL_MIN_POOL_CONTRIBUTION = 50; // 50 DAI or above to create the channel
        ADD_CHANNEL_MAX_POOL_CONTRIBUTION = 500 * 50 * 10 ** 18; // 500 DAI or below, we don't want channel to make a costly mistake as well, for test it's 25k

        EPNS_FIRST_MESSAGE_HASH = "3+QmZbff755tAPZ22REdF5PDLLjtbRUKu2THaXSZ7pkRf2qV";
        groupLastUpdate = block.number;
        groupNormalizedWeight = ADJUST_FOR_FLOAT; // Always Starts with 1 * ADJUST FOR FLOAT

        ADJUST_FOR_FLOAT = 10 ** 7; // TODO: checkout dsmath
        channelsCount = 0;
        usersCount = 0;

        // Helper for calculating fair share of pool, group are all channels, renamed to avoid confusion
        groupNormalizedWeight = 0;
        groupHistoricalZ = 0; // Abbre
        groupLastUpdate = 0; // The last update block number, used to calculate fair share
        groupFairShareCount = 0; // They are alias to channels count but seperating them for brevity

        /*
        For maintaining the #DeFi finances
        */
        poolFunds = 0; // Always in DAI
        ownerDaiFunds = 0;

        // Add EPNS Channels
        // First is for all users
        // Second is all channel alerter, amount deposited for both is 0
        // to save gas, emit both the events out
        emit AddChannel(0x0000000000000000000000000000000000000000, "QmTCKYL2HRbwD6nGNvFLe4wPvDNuaYGr6RiVeCvWjVpn5s");
        emit AddChannel(governance, "QmSbRT16JVF922yAB26YxWFD6DmGsnSHm8VBrGUQnXTS74");

        // Also, call the EPNSServer contract to which the server is listening, will be removed after alpha
        // Create Channel
        _createChannel(0x0000000000000000000000000000000000000000, ChannelType.NonInterestBearing, 0);
        _createChannel(governance, ChannelType.NonInterestBearing, 0); // should the owner of the contract be the channel? should it be governance in this case?
        success = true;
    }

    receive() external payable {}

    fallback() external {
        console.logString('in fallback of core');
    }

    // Modifiers

    modifier onlyGov() {
        require (msg.sender == governance, "EPNSCore::onlyGov, user is not governance");
        _;
    }

    /// @dev Testnet only function to check permission from owner
    modifier onlyChannelizationWhitelist(address _addr) {
        require ((msg.sender == governance || channelizationWhitelist[_addr] == true), "User not in Channelization Whitelist");
        _;
    }

    modifier onlyValidUser(address _addr) {
        require(users[_addr].userActivated == true, "User not activated yet");
        _;
    }

    modifier onlyUserWithNoChannel() {
        require(users[msg.sender].channellized == false, "User already a Channel Owner");
        _;
    }

    modifier onlyValidChannel(address _channel) {
        require(users[_channel].channellized == true, "Channel doesn't Exists");
        _;
    }

    modifier onlyActivatedChannels(address _channel) {
        require(users[_channel].channellized == true && channels[_channel].deactivated == false, "Channel deactivated or doesn't exists");
        _;
    }

    modifier onlyChannelOwner(address _channel) {
        require(
        ((users[_channel].channellized == true && msg.sender == _channel) || (msg.sender == governance && _channel == 0x0000000000000000000000000000000000000000)),
        "Channel doesn't Exists"
        );
        _;
    }

    modifier onlySubscribed(address _channel, address _subscriber) {
        require(channels[_channel].memberExists[_subscriber] == true, "Subscriber doesn't Exists");
        _;
    }

    modifier onlyNonOwnerSubscribed(address _channel, address _subscriber) {
        require(_channel != _subscriber && channels[_channel].memberExists[_subscriber] == true, "Either Channel Owner or Not Subscribed");
        _;
    }

    modifier onlyNonSubscribed(address _channel, address _subscriber) {
        require(channels[_channel].memberExists[_subscriber] == false, "Subscriber already Exists");
        _;
    }

    modifier onlyNonGraylistedChannel(address _channel, address _user) {
        require(users[_user].graylistedChannels[_channel] == false, "Channel is graylisted");
        _;
    }
    
    function transferGovernance(address _newGovernance) onlyGov public {
        require (_newGovernance != address(0), "EPNSCore::transferGovernance, new governance can't be none");
        require (_newGovernance != governance, "EPNSCore::transferGovernance, new governance can't be current governance");
        governance = _newGovernance;
    }

    /// @dev Testnet only function to enable owner permission for channelizationWhitelist addition
    function addToChannelizationWhitelist(address _addr) external onlyGov {
        channelizationWhitelist[_addr] = true;
    }

    /// @dev Testnet only function  to enable owner permission for channelizationWhitelist removal
    function removeFromChannelizationWhitelist(address _addr) external onlyGov {
        channelizationWhitelist[_addr] = false;
    }

    /// @dev Performs action by the user themself to broadcast their public key
    function broadcastUserPublicKey(bytes calldata _publicKey) external {
        // Will save gas
        if (users[msg.sender].publicKeyRegistered == true) {
        // Nothing to do, user already registered
        return;
        }

        // broadcast it
        _broadcastPublicKey(msg.sender, _publicKey);
    }

    /// @dev Create channel with fees and public key
    function createChannelWithFeesAndPublicKey(bytes calldata _identity, bytes calldata _publickey)
        external onlyUserWithNoChannel onlyChannelizationWhitelist(msg.sender) {
        // Save gas, Emit the event out
        emit AddChannel(msg.sender, _identity);

        // Broadcast public key
        // @TODO Find a way to save cost

        // Will save gas
        if (users[msg.sender].publicKeyRegistered == false) {
            _broadcastPublicKey(msg.sender, _publickey);
        }

        // Bubble down to create channel
        _createChannelWithFees();
    }

    /// @dev Create channel with fees
    function createChannelWithFees(bytes calldata _identity) external onlyUserWithNoChannel onlyChannelizationWhitelist(msg.sender) {
        // Save gas, Emit the event out
        emit AddChannel(msg.sender, _identity);

        // Bubble down to create channel
        _createChannelWithFees();
    }

    /// @dev Deactivate channel
    function deactivateChannel() onlyActivatedChannels(msg.sender) external {
        channels[msg.sender].deactivated = true;
    }

    /// @dev delegate subscription to channel
    function subscribeWithPublicKeyDelegated(
        address _channel,
        address _user,
    bytes calldata _publicKey
    ) external onlyActivatedChannels(_channel) onlyNonGraylistedChannel(_channel, _user) {
        // Take delegation fees
        _takeDelegationFees();

        // Will save gas as it prevents calldata to be copied unless need be
        if (users[_user].publicKeyRegistered == false) {
        // broadcast it
        _broadcastPublicKey(msg.sender, _publicKey);
        }

        // Call actual subscribe
        _subscribe(_channel, _user);
    }

    /// @dev subscribe to channel delegated
    function subscribeDelegated(address _channel, address _user) external onlyActivatedChannels(_channel) onlyNonGraylistedChannel(_channel, _user) {
        // Take delegation fees
        _takeDelegationFees();

        // Call actual subscribe
        _subscribe(_channel, _user);
    }

    /// @dev subscribe to channel with public key
    function subscribeWithPublicKey(address _channel, bytes calldata _publicKey) onlyActivatedChannels(_channel) external {
        // Will save gas as it prevents calldata to be copied unless need be
        if (users[msg.sender].publicKeyRegistered == false) {

        // broadcast it
        _broadcastPublicKey(msg.sender, _publicKey);
        }

        // Call actual subscribe
        _subscribe(_channel, msg.sender);
    }

    /// @dev subscribe to channel
    function subscribe(address _channel) onlyActivatedChannels(_channel) external {
        // Call actual subscribe
        _subscribe(_channel, msg.sender);
    }

    /// @dev to unsubscribe from channel
    function unsubscribe(address _channel) external onlyValidChannel(_channel) onlyNonOwnerSubscribed(_channel, msg.sender) returns (uint ratio) {
        // Add the channel to gray list so that it can't subscriber the user again as delegated
        User storage user = users[msg.sender];

        // Treat it as graylisting
        user.graylistedChannels[_channel] = true;

        // first get ratio of earning
        ratio = 0;
        ratio = calcSingleChannelEarnRatio(_channel, msg.sender, block.number);

        // Take the fair share out

        // Remove the mappings and cleanup
        // a bit tricky, swap and delete to maintain mapping
        // Remove From Users mapping
        // Find the id of the channel and swap it with the last id, use channel.memberCount as index
        // Slack too deep fix
        // address usrSubToSwapAdrr = user.mapAddressSubscribed[user.subscribedCount];
        // uint usrSubSwapID = user.subscribed[_channel];

        // // swap to last one and then
        // user.subscribed[usrSubToSwapAdrr] = usrSubSwapID;
        // user.mapAddressSubscribed[usrSubSwapID] = usrSubToSwapAdrr;

        user.subscribed[user.mapAddressSubscribed[user.subscribedCount]] = user.subscribed[_channel];
        user.mapAddressSubscribed[user.subscribed[_channel]] = user.mapAddressSubscribed[user.subscribedCount];

        // delete the last one and substract
        delete(user.subscribed[_channel]);
        delete(user.mapAddressSubscribed[user.subscribedCount]);
        user.subscribedCount = user.subscribedCount.sub(1);

        // Remove from Channels mapping
        Channel storage channel = channels[_channel];

        // Set additional flag to false
        channel.memberExists[msg.sender] = false;

        // Find the id of the channel and swap it with the last id, use channel.memberCount as index
        // Slack too deep fix
        // address chnMemToSwapAdrr = channel.mapAddressMember[channel.memberCount];
        // uint chnMemSwapID = channel.members[msg.sender];

        // swap to last one and then
        channel.members[channel.mapAddressMember[channel.memberCount]] = channel.members[msg.sender];
        channel.mapAddressMember[channel.members[msg.sender]] = channel.mapAddressMember[channel.memberCount];

        // delete the last one and substract
        delete(channel.members[msg.sender]);
        delete(channel.mapAddressMember[channel.memberCount]);
        channel.memberCount = channel.memberCount.sub(1);

        // Next readjust fair share
        (
            channels[_channel].channelFairShareCount,
            channels[_channel].channelHistoricalZ,
            channels[_channel].channelLastUpdate
        ) = _readjustFairShareOfSubscribers(
            SubscriberAction.SubscriberRemoved,
            channels[_channel].channelFairShareCount,
            channels[_channel].channelHistoricalZ,
            channels[_channel].channelLastUpdate
        );

        // Next calculate and send the fair share earning of the user from this channel
        if (channel.channelType == ChannelType.InterestBearingChannel) {
            _withdrawFundsFromPool(ratio);
        }

        // Emit it
        emit Unsubscribe(_channel, msg.sender);
    }

    /// @dev to claim fair share of all earnings
    function claimFairShare() onlyValidUser(msg.sender) external returns (uint ratio){
        // Calculate entire FS Share, since we are looping for reset... let's calculate over there
        ratio = 0;

        // Reset member last update for every channel that are interest bearing
        // WARN: This unbounded for loop is an anti-pattern
        for (uint i = 0; i < users[msg.sender].subscribedCount; i++) {
            address channel = users[msg.sender].mapAddressSubscribed[i];

            if (channels[channel].channelType == ChannelType.InterestBearingChannel) {
                // Reset last updated block
                channels[channel].memberLastUpdate[msg.sender] = block.number;

                // Next readjust fair share and that's it
                (
                channels[channel].channelFairShareCount,
                channels[channel].channelHistoricalZ,
                channels[channel].channelLastUpdate
                ) = _readjustFairShareOfSubscribers(
                SubscriberAction.SubscriberUpdated,
                channels[channel].channelFairShareCount,
                channels[channel].channelHistoricalZ,
                channels[channel].channelLastUpdate
                );

                // Calculate share
                uint individualChannelShare = calcSingleChannelEarnRatio(channel, msg.sender, block.number);
                ratio = ratio.add(individualChannelShare);
            }

        }
        // Finally, withdraw for user
        _withdrawFundsFromPool(ratio);
    }

    /* @dev to send message to reciepient of a group, the first digit of msg type contains rhe push server flag
    ** So msg type 1 with using push is 11, without push is 10, in the future this can also be 12 (silent push)
    */
    function sendNotification(
        address _recipient,
        bytes calldata _identity
    ) external onlyChannelOwner(msg.sender) {
        // Just check if the msg is a secret, if so the user public key should be in the system
        // On second thought, leave it upon the channel, they might have used an alternate way to
        // encrypt the message using the public key

        // Emit the message out
        emit SendNotification(msg.sender, _recipient, _identity);
    }

    /// @dev to send message to reciepient of a group
    function sendNotificationOverrideChannel(
        address _channel,
        address _recipient,
        bytes calldata _identity
    ) external onlyChannelOwner(msg.sender) onlyGov {
        // Emit the message out
        emit SendNotification(_channel, _recipient, _identity);
    }

    /// @dev to withraw funds coming from delegate fees
    function withdrawDaiFunds() external onlyGov {
        // Get and transfer funds
        uint funds = ownerDaiFunds;
        IERC20(daiAddress).safeTransferFrom(address(this), msg.sender, funds);

        // Rest funds to 0
        ownerDaiFunds = 0;

        // Emit Evenet
        emit Withdrawal(msg.sender, daiAddress, funds);
    }

    /// @dev to withraw funds coming from donate
    function withdrawEthFunds() external onlyGov {
        uint bal = address(this).balance;

        payable(governance).transfer(bal);

        // Emit Event
        emit Withdrawal(msg.sender, daiAddress, bal);
    }

    /// @dev To check if member exists
    function memberExists(address _user, address _channel) external view returns (bool subscribed) {
        subscribed = channels[_channel].memberExists[_user];
    }

    /// @dev To fetch subscriber address for a channel
    function getChannelSubscriberAddress(address _channel, uint _subscriberId) external view returns (address subscriber) {
        subscriber = channels[_channel].mapAddressMember[_subscriberId];
    }

    /// @dev To fetch user id for a subscriber of a channel
    function getChannelSubscriberUserID(address _channel, uint _subscriberId) external view returns (uint userId) {
        userId = channels[_channel].members[channels[_channel].mapAddressMember[_subscriberId]];
    }

    /// @dev donate functionality for the smart contract
    function donate() public payable {
        require(msg.value >= 0.001 ether, "Minimum Donation amount is 0.001 ether");

        // Emit Event
        emit Donation(msg.sender, msg.value);
    }

    /// @dev to get channel fair share ratio for a given block
    function getChannelFSRatio(address _channel, uint _block) public view returns (uint ratio) {
        // formula is ratio = da / z + (nxw)
        // d is the difference of blocks from given block and the last update block of the entire group
        // a is the actual weight of that specific group
        // z is the historical constant
        // n is the number of channels
        // x is the difference of blocks from given block and the last changed start block of group
        // w is the normalized weight of the groups
        uint d = _block.sub(channels[_channel].channelStartBlock); // _block.sub(groupLastUpdate);
        uint a = channels[_channel].channelWeight;
        uint z = groupHistoricalZ;
        uint n = groupFairShareCount;
        uint x = _block.sub(groupLastUpdate);
        uint w = groupNormalizedWeight;

        uint nxw = n.mul(x.mul(w));
        uint z_nxw = z.add(nxw);
        uint da = d.mul(a);

        ratio = (da.mul(ADJUST_FOR_FLOAT)).div(z_nxw);
    }

    /// @dev to get subscriber fair share ratio for a given channel at a block
    function getSubscriberFSRatio(
        address _channel,
        address _user,
        uint _block
    ) public view onlySubscribed(_channel, _user) returns (uint ratio) {
        // formula is ratio = d / z + (nx)
        // d is the difference of blocks from given block and the start block of subscriber
        // z is the historical constant
        // n is the number of subscribers of channel
        // x is the difference of blocks from given block and the last changed start block of channel

        uint d = _block.sub(channels[_channel].memberLastUpdate[_user]);
        uint z = channels[_channel].channelHistoricalZ;
        uint x = _block.sub(channels[_channel].channelLastUpdate);

        uint nx = channels[_channel].channelFairShareCount.mul(x);

        ratio = (d.mul(ADJUST_FOR_FLOAT)).div(z.add(nx)); // == d / z + n * x
    }

    /* @dev to get the fair share of user for a single channel, different from subscriber fair share
     * as it's multiplication of channel fair share with subscriber fair share
     */
    function calcSingleChannelEarnRatio(
        address _channel,
        address _user,
        uint _block
    ) public view onlySubscribed(_channel, _user) returns (uint ratio) {
        // First get the channel fair share
        if (channels[_channel].channelType == ChannelType.InterestBearingChannel) {
            uint channelFS = getChannelFSRatio(_channel, _block);
            uint subscriberFS = getSubscriberFSRatio(_channel, _user, _block);

            ratio = channelFS.mul(subscriberFS).div(ADJUST_FOR_FLOAT);
        }
    }

    /// @dev to get the fair share of user overall
    function calcAllChannelsRatio(address _user, uint _block) onlyValidUser(_user) public view returns (uint ratio) {
        // loop all channels for the user
        uint subscribedCount = users[_user].subscribedCount;

        // WARN: This unbounded for loop is an anti-pattern
        for (uint i = 0; i < subscribedCount; i++) {
            if (channels[users[_user].mapAddressSubscribed[i]].channelType == ChannelType.InterestBearingChannel) {
                uint individualChannelShare = calcSingleChannelEarnRatio(users[_user].mapAddressSubscribed[i], _user, _block);
                ratio = ratio.add(individualChannelShare);
            }
        }
    }

    /// @dev Add the user to the ecosystem if they don't exists, the returned response is used to deliver a message to the user if they are recently added
    function _addUser(address _addr) private returns (bool userAlreadyAdded) {
        if (users[_addr].userActivated) {
            userAlreadyAdded = true;
        }
        else {
            // Activates the user
            users[_addr].userStartBlock = block.number;
            users[_addr].userActivated = true;
            mapAddressUsers[usersCount] = _addr;

            usersCount = usersCount.add(1);

            // Send Welcome Message
            emit SendNotification(governance, _addr, EPNS_FIRST_MESSAGE_HASH);
        }
    }

    /* @dev Internal system to handle broadcasting of public key,
    * is a entry point for subscribe, or create channel but is option
    */
    function _broadcastPublicKey(address _userAddr, bytes memory _publicKey) private {
        // Add the user, will do nothing if added already, but is needed before broadcast
        _addUser(_userAddr);

        // get address from public key
        address userAddr = getWalletFromPublicKey(_publicKey);

        if (_userAddr == userAddr) {
            // Only change it when verification suceeds, else assume the channel just wants to send group message
            users[userAddr].publicKeyRegistered = true;

            // Emit the event out
            emit PublicKeyRegistered(userAddr, _publicKey);
        }
        else {
            revert("Public Key Validation Failed");
        }
    }

    /// @dev Don't forget to add 0x into it
    function getWalletFromPublicKey (bytes memory _publicKey) public pure returns (address wallet) {
        if (_publicKey.length == 64) {
            wallet = address (uint160 (uint256 (keccak256 (_publicKey))));
        }
        else {
            wallet = 0x0000000000000000000000000000000000000000;
        }
    }

    /// @dev add channel with fees
    function _createChannelWithFees() private {
        // This module should be completely independent from the private _createChannel() so constructor can do it's magic
        // Get the approved allowance
        uint allowedAllowance = IERC20(daiAddress).allowance(msg.sender, address(this));

        // Check if it's equal or above Channel Pool Contribution
        require(
            allowedAllowance >= ADD_CHANNEL_MIN_POOL_CONTRIBUTION && allowedAllowance <= ADD_CHANNEL_MAX_POOL_CONTRIBUTION,
            "Insufficient Funds or max ceiling reached"
        );

        // Check and transfer funds
        IERC20(daiAddress).safeTransferFrom(msg.sender, address(this), allowedAllowance);

        // Deposit funds to pool
        _depositFundsToPool(allowedAllowance);

        // // Generate a random allowed allowance, for testing Generates 50 to 25000 range
        // uint allowedAllowance = ((uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % 24950) + 50) * 10 ** 18;
        // poolFunds = poolFunds.add(allowedAllowance);
        // Testing Endss

        // Call Create Channel
        _createChannel(msg.sender, ChannelType.InterestBearingChannel, allowedAllowance);
    }

    /// @dev Create channel internal method that runs
    function _createChannel(address _channel, ChannelType _channelType, uint _amountDeposited) private {
        // Add the user, will do nothing if added already, but is needed for all outpoints
        bool userAlreadyAdded = _addUser(_channel);

        // Calculate channel weight
        uint _channelWeight = _amountDeposited.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

        // Next create the channel and mark user as channellized
        users[_channel].channellized = true;

        channels[_channel].poolContribution = _amountDeposited;
        channels[_channel].channelType = _channelType;
        channels[_channel].channelStartBlock = block.number;
        channels[_channel].channelWeight = _channelWeight;

        // Add to map of addresses and increment channel count
        mapAddressChannels[channelsCount] = _channel;
        channelsCount = channelsCount.add(1);

        // Readjust fair share if interest bearing
        if (_channelType == ChannelType.InterestBearingChannel) {
            (groupFairShareCount, groupNormalizedWeight, groupHistoricalZ, groupLastUpdate) = _readjustFairShareOfChannels(
                ChannelAction.ChannelAdded,
                _channelWeight,
                groupFairShareCount,
                groupNormalizedWeight,
                groupHistoricalZ,
                groupLastUpdate
            );
        }

        // If this is a new user than subscribe them to EPNS Channel
        if (userAlreadyAdded == false && _channel != 0x0000000000000000000000000000000000000000) {
            // Call actual subscribe, owner channel
            _subscribe(governance, _channel);
        }

        // All Channels are subscribed to EPNS Alerter as well, unless it's the EPNS Alerter channel iteself
        if (_channel != 0x0000000000000000000000000000000000000000) {
            _subscribe(0x0000000000000000000000000000000000000000, _channel);
        }

        // Subscribe them to their own channel as well
        if (_channel != governance) {
            _subscribe(_channel, _channel);
        }
    }

    /// @dev private function that eventually handles the subscribing onlyValidChannel(_channel)
    function _subscribe(address _channel, address _user) private onlyNonSubscribed(_channel, _user) {
        // Add the user, will do nothing if added already, but is needed for all outpoints
        _addUser(_user);

        User storage user = users[_user];
        Channel storage channel = channels[_channel];

        // treat the count as index and update user struct
        user.subscribed[_channel] = user.subscribedCount;
        user.mapAddressSubscribed[user.subscribedCount] = _channel;
        user.subscribedCount = user.subscribedCount.add(1); // Finally increment the subscribed count

        // Do the same for the channel to maintain sync, treat member count as index
        channel.members[_user] = channel.memberCount;
        channel.mapAddressMember[channel.memberCount] = _user;
        channel.memberCount = channel.memberCount.add(1); // Finally increment the member count

        // Set Additional flag for some conditions and set last update of member
        channel.memberLastUpdate[_user] = block.number;
        channel.memberExists[_user] = true;

        // Next readjust fair share and that's it
        (
            channels[_channel].channelFairShareCount,
            channels[_channel].channelHistoricalZ,
            channels[_channel].channelLastUpdate
        ) = _readjustFairShareOfSubscribers(
            SubscriberAction.SubscriberAdded,
            channels[_channel].channelFairShareCount,
            channels[_channel].channelHistoricalZ,
            channels[_channel].channelLastUpdate
        );

        // Emit it
        emit Subscribe(_channel, _user);
    }

    /// @dev charge delegation fee, small enough for serious players but thwarts bad actors
    function _takeDelegationFees() private {
        // Check and transfer funds
        // require( IERC20(daiAddress).safeTransferFrom(msg.sender, address(this), DELEGATED_CONTRACT_FEES), "Insufficient Funds");
        IERC20(daiAddress).safeTransferFrom(msg.sender, address(this), DELEGATED_CONTRACT_FEES);

        // Add it to owner kitty
        ownerDaiFunds.add(DELEGATED_CONTRACT_FEES);
    }

    /// @dev deposit funds to pool
    function _depositFundsToPool(uint amount) private {
        // Got the funds, add it to the channels dai pool
        poolFunds = poolFunds.add(amount);

        // Next swap it via AAVE for aDAI
        // mainnet address, for other addresses: https://docs.aave.com/developers/developing-on-aave/deployed-contract-instances
        ILendingPoolAddressesProvider provider = ILendingPoolAddressesProvider(lendingPoolProviderAddress);
        ILendingPool lendingPool = ILendingPool(provider.getLendingPool());
        IERC20(daiAddress).approve(provider.getLendingPoolCore(), amount);

        // Deposit to AAVE
        lendingPool.deposit(daiAddress, amount, uint16(REFERRAL_CODE)); // set to 0 in constructor presently
    }

        /// @dev withdraw funds from pool
    function _withdrawFundsFromPool(uint ratio) private nonReentrant {
        uint totalBalanceWithProfit = IERC20(aDaiAddress).balanceOf(address(this));

        // // Random for testing
        // uint totalBalanceWithProfit = ((uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % 24950) + 50) * 10 ** 19; // 10 times
        // // End Testing

        uint totalProfit = totalBalanceWithProfit.sub(poolFunds);
        uint userAmount = totalProfit.mul(ratio);

        // adjust poolFunds first
        uint userAmountAdjusted = userAmount.div(ADJUST_FOR_FLOAT);
        poolFunds = poolFunds.sub(userAmountAdjusted);

        // Add to interest claimed
        usersInterestClaimed[msg.sender] = usersInterestClaimed[msg.sender].add(userAmountAdjusted);

        // Finally transfer
        IERC20(aDaiAddress).transfer(msg.sender, userAmountAdjusted);

        // Emit Event
        emit InterestClaimed(msg.sender, userAmountAdjusted);
    }

    /// @dev readjust fair share runs on channel addition, removal or update of channel
    function _readjustFairShareOfChannels(
        ChannelAction _action,
        uint _channelWeight,
        uint _groupFairShareCount,
        uint _groupNormalizedWeight,
        uint _groupHistoricalZ,
        uint _groupLastUpdate
    )
    private
    view
    returns (
        uint groupNewCount,
        uint groupNewNormalizedWeight,
        uint groupNewHistoricalZ,
        uint groupNewLastUpdate
    )
    {
        // readjusts the group count and do deconstruction of weight
        uint groupModCount = _groupFairShareCount;
        uint prevGroupCount = groupModCount;

        uint totalWeight;
        uint adjustedNormalizedWeight = _groupNormalizedWeight; //_groupNormalizedWeight;

        // Increment or decrement count based on flag
        if (_action == ChannelAction.ChannelAdded) {
            groupModCount = groupModCount.add(1);

            totalWeight = adjustedNormalizedWeight.mul(prevGroupCount);
            totalWeight = totalWeight.add(_channelWeight);
        }
        else if (_action == ChannelAction.ChannelRemoved) {
            groupModCount = groupModCount.sub(1);

            totalWeight = adjustedNormalizedWeight.mul(prevGroupCount);
            totalWeight = totalWeight.sub(_channelWeight);
        }
        else if (_action == ChannelAction.ChannelUpdated) {
            totalWeight = adjustedNormalizedWeight.mul(prevGroupCount.sub(1));
            totalWeight = totalWeight.add(_channelWeight);
        }
        else {
            revert("Invalid Channel Action");
        }

        // now calculate the historical constant
        // z = z + nxw
        // z is the historical constant
        // n is the previous count of group fair share
        // x is the differential between the latest block and the last update block of the group
        // w is the normalized average of the group (ie, groupA weight is 1 and groupB is 2 then w is (1+2)/2 = 1.5)
        uint n = groupModCount;
        uint x = block.number.sub(_groupLastUpdate);
        uint w = totalWeight.div(groupModCount);
        uint z = _groupHistoricalZ;

        uint nx = n.mul(x);
        uint nxw = nx.mul(w);

        // Save Historical Constant and Update Last Change Block
        z = z.add(nxw);

        if (n == 1) {
            // z should start from here as this is first channel
            z = 0;
        }

        // Update return variables
        groupNewCount = groupModCount;
        groupNewNormalizedWeight = w;
        groupNewHistoricalZ = z;
        groupNewLastUpdate = block.number;
    }

    /// @dev readjust fair share runs on user addition or removal
    function _readjustFairShareOfSubscribers(
        SubscriberAction action,
        uint _channelFairShareCount,
        uint _channelHistoricalZ,
        uint _channelLastUpdate
    )
    private
    view
    returns (
        uint channelNewFairShareCount,
        uint channelNewHistoricalZ,
        uint channelNewLastUpdate
    )
    {
        uint channelModCount = _channelFairShareCount;
        uint prevChannelCount = channelModCount;

        // Increment or decrement count based on flag
        if (action == SubscriberAction.SubscriberAdded) {
            channelModCount = channelModCount.add(1);
        }
        else if (action == SubscriberAction.SubscriberRemoved) {
            channelModCount = channelModCount.sub(1);
        }
        else if (action == SubscriberAction.SubscriberUpdated) {
        // do nothing, it's happening after a reset of subscriber last update count

        }
        else {
            revert("Invalid Channel Action");
        }

        // to calculate the historical constant
        // z = z + nx
        // z is the historical constant
        // n is the total prevoius subscriber count
        // x is the difference bewtween the last changed block and the current block
        uint x = block.number.sub(_channelLastUpdate);
        uint nx = prevChannelCount.mul(x);
        uint z = _channelHistoricalZ.add(nx);

        // Define Values
        channelNewFairShareCount = channelModCount;
        channelNewHistoricalZ = z;
        channelNewLastUpdate = block.number;
    }
}


// File contracts/EPNSCoreV2.sol

pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;







interface ILendingPoolAddressesProvider {
    function getLendingPoolCore() external view returns (address payable);

    function getLendingPool() external view returns (address);
}

interface ILendingPool {
    function addressesProvider() external view returns (address);

    function deposit(address _reserve, uint256 _amount, uint16 _referralCode) external payable;

    function redeemUnderlying(address _reserve, address _user, uint256 _amount) external;

    function borrow(address _reserve, uint256 _amount, uint256 _interestRateMode, uint16 _referralCode) external;

    function repay(address _reserve, uint256 _amount, address _onBehalfOf) external payable;

    function swapBorrowRateMode(address _reserve) external;

    function rebalanceFixedBorrowRate(address _reserve, address _user) external;

    function setUserUseReserveAsCollateral(address _reserve, bool _useAsCollateral) external;

    function liquidationCall(address _collateral, address _reserve, address _user, uint256 _purchaseAmount, bool _receiveAToken) external payable;

    function flashLoan(address _receiver, address _reserve, uint256 _amount, bytes calldata _params) external;

    function getReserveConfigurationData(address _reserve) external view returns (uint256 ltv, uint256 liquidationThreshold, uint256 liquidationDiscount, address interestRateStrategyAddress, bool usageAsCollateralEnabled, bool borrowingEnabled, bool fixedBorrowRateEnabled, bool isActive);

    function getReserveData(address _reserve) external view returns (uint256 totalLiquidity, uint256 availableLiquidity, uint256 totalBorrowsFixed, uint256 totalBorrowsVariable, uint256 liquidityRate, uint256 variableBorrowRate, uint256 fixedBorrowRate, uint256 averageFixedBorrowRate, uint256 utilizationRate, uint256 liquidityIndex, uint256 variableBorrowIndex, address aTokenAddress, uint40 lastUpdateTimestamp);

    function getUserAccountData(address _user) external view returns (uint256 totalLiquidityETH, uint256 totalCollateralETH, uint256 totalBorrowsETH, uint256 availableBorrowsETH, uint256 currentLiquidationThreshold, uint256 ltv, uint256 healthFactor);

    function getUserReserveData(address _reserve, address _user) external view returns (uint256 currentATokenBalance, uint256 currentUnderlyingBalance, uint256 currentBorrowBalance, uint256 principalBorrowBalance, uint256 borrowRateMode, uint256 borrowRate, uint256 liquidityRate, uint256 originationFee, uint256 variableBorrowIndex, uint256 lastUpdateTimestamp, bool usageAsCollateralEnabled);

    function getReserves() external view;
}


interface IEPNSCore {}

contract EPNSCoreV2 is Initializable, ReentrancyGuard  {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    /* ***************
    * DEFINE ENUMS AND CONSTANTS
    *************** */
    // For Message Type
    enum ChannelType {InterestBearingChannel, NonInterestBearing}
    enum ChannelAction {ChannelRemoved, ChannelAdded, ChannelUpdated}
    enum SubscriberAction {SubscriberRemoved, SubscriberAdded, SubscriberUpdated}



    /* ***************
    // DEFINE STRUCTURES AND VARIABLES
    *************** */


    /* Users are everyone in the EPNS Ecosystem
     * the struct creates a registry for public key signing and maintains the users subscribed channels
    */
    struct User {
        bool userActivated; // Whether a user is activated or not
        bool publicKeyRegistered; // Will be false until public key is emitted
        bool channellized; // Marks if a user has opened a channel

        uint userStartBlock; // Events should not be polled before this block as user doesn't exist
        uint subscribedCount; // Keep track of subscribers

        uint timeWeightedBalance;

        // keep track of all subscribed channels
        mapping(address => uint) subscribed;
        mapping(uint => address) mapAddressSubscribed;

        // keep track of greylist, useful for unsubscribe so the channel can't subscribe you back
        mapping(address => bool) graylistedChannels;
    }


    /* Channels are addresses who have wants their broadcasting network,
    * the channel can never go back to being a plain user but can be marked inactive
    */
    struct Channel {
        // Channel Type
        ChannelType channelType;

        // Flag to deactive channel
        bool deactivated;

        // Channel Pool Contribution
        uint poolContribution;
        uint memberCount;

        uint channelHistoricalZ;
        uint channelFairShareCount;
        uint channelLastUpdate; // The last update block number, used to calculate fair share

        // To calculate fair share of profit from the pool of channels generating interest
        uint channelStartBlock; // Helps in defining when channel started for pool and profit calculation
        uint channelWeight; // The individual weight to be applied as per pool contribution

        // To keep track of subscribers info
        mapping(address => bool) memberExists;

        // For iterable mapping
        mapping(address => uint) members;
        mapping(uint => address) mapAddressMember; // This maps to the user

        // To calculate fair share of profit for a subscriber
        // The historical constant that is applied with (wnx0 + wnx1 + .... + wnxZ)
        // Read more in the repo: https://github.com/ethereum-push-notification-system
        mapping(address => uint) memberLastUpdate;
    }

    // To keep track of channels
    mapping(address => Channel) public channels;
    mapping(uint => address) public mapAddressChannels;

    // To keep a track of all users
    mapping(address => User) public users;
    mapping(uint => address) public mapAddressUsers;

    // To keep track of interest claimed and interest in wallet
    mapping(address => uint) public usersInterestClaimed;
    mapping(address => uint) public usersInterestInWallet;


    bytes EPNS_FIRST_MESSAGE_HASH;


    /**
        Address Lists
    */
    address public lendingPoolProviderAddress;
    address public daiAddress;
    address public aDaiAddress;
    address public governance;

    // Track assetCounts
    uint public channelsCount;
    uint public usersCount;

    // Helper for calculating fair share of pool, group are all channels, renamed to avoid confusion
    uint public groupNormalizedWeight;
    uint public groupHistoricalZ;
    uint public groupLastUpdate;
    uint public groupFairShareCount;

    /*
        For maintaining the #DeFi finances
    */
    uint public poolFunds;
    uint public ownerDaiFunds;

    uint public REFERRAL_CODE;

    uint ADD_CHANNEL_MAX_POOL_CONTRIBUTION;

    uint UPDATE_CHANNEL_POOL_CONTRIBUTION;
    uint DELEGATED_CONTRACT_FEES;

    uint ADJUST_FOR_FLOAT;
    uint ADD_CHANNEL_MIN_POOL_CONTRIBUTION;



    /* ***************
    * Events
    *************** */
    // For Public Key Registration Emit
    event PublicKeyRegistered(address indexed owner, bytes publickey);

    // Channel Related | // This Event is listened by on All Infra Services
    event AddChannel(address indexed channel, bytes identity);
    event UpdateChannel(address indexed channel, bytes identity);
    event DeactivateChannel(address indexed channel);

    // Subscribe / Unsubscribe | This Event is listened by on All Infra Services
    event Subscribe(address indexed channel, address indexed user);
    event Unsubscribe(address indexed channel, address indexed user);

    // Send Notification | This Event is listened by on All Infra Services
    event SendNotification(address indexed channel, address indexed recipient, bytes identity);

    // Emit Claimed Interest
    event InterestClaimed(address indexed user, uint indexed amount);

    // Withdrawl Related
    event Donation(address indexed donator, uint amt);
    event Withdrawal(address indexed to, address token, uint amount);

    receive() external payable {}

    fallback() external {
        console.logString('in fallback of core');
    }

    // Modifiers

    modifier onlyGov() {
        require (msg.sender == governance, "EPNSCore::onlyGov, user is not governance");
        _;
    }

    modifier onlyValidUser(address _addr) {
        require(users[_addr].userActivated == true, "User not activated yet");
        _;
    }

    modifier onlyUserWithNoChannel() {
        require(users[msg.sender].channellized == false, "User already a Channel Owner");
        _;
    }

    modifier onlyValidChannel(address _channel) {
        require(users[_channel].channellized == true, "Channel doesn't Exists");
        _;
    }

    modifier onlyActivatedChannels(address _channel) {
        require(users[_channel].channellized == true && channels[_channel].deactivated == false, "Channel deactivated or doesn't exists");
        _;
    }

    modifier onlyChannelOwner(address _channel) {
        require(
        ((users[_channel].channellized == true && msg.sender == _channel) || (msg.sender == governance && _channel == 0x0000000000000000000000000000000000000000)),
        "Channel doesn't Exists"
        );
        _;
    }

    modifier onlySubscribed(address _channel, address _subscriber) {
        require(channels[_channel].memberExists[_subscriber] == true, "Subscriber doesn't Exists");
        _;
    }

    modifier onlyNonOwnerSubscribed(address _channel, address _subscriber) {
        require(_channel != _subscriber && channels[_channel].memberExists[_subscriber] == true, "Either Channel Owner or Not Subscribed");
        _;
    }

    modifier onlyNonSubscribed(address _channel, address _subscriber) {
        require(channels[_channel].memberExists[_subscriber] == false, "Subscriber already Exists");
        _;
    }

    modifier onlyNonGraylistedChannel(address _channel, address _user) {
        require(users[_user].graylistedChannels[_channel] == false, "Channel is graylisted");
        _;
    }
    
    function transferGovernance(address _newGovernance) onlyGov public {
        require (_newGovernance != address(0), "EPNSCore::transferGovernance, new governance can't be none");
        require (_newGovernance != governance, "EPNSCore::transferGovernance, new governance can't be current governance");
        governance = _newGovernance;
    }

    /// @dev Performs action by the user themself to broadcast their public key
    function broadcastUserPublicKey(bytes calldata _publicKey) external {
        // Will save gas
        if (users[msg.sender].publicKeyRegistered == true) {
        // Nothing to do, user already registered
        return;
        }

        // broadcast it
        _broadcastPublicKey(msg.sender, _publicKey);
    }

    /// @dev Create channel with fees and public key
    function createChannelWithFeesAndPublicKey(bytes calldata _identity, bytes calldata _publickey)
        external onlyUserWithNoChannel {
        // Save gas, Emit the event out
        emit AddChannel(msg.sender, _identity);

        // Broadcast public key
        // @TODO Find a way to save cost

        // Will save gas
        if (users[msg.sender].publicKeyRegistered == false) {
            _broadcastPublicKey(msg.sender, _publickey);
        }

        // Bubble down to create channel
        _createChannelWithFees();
    }

    /// @dev Create channel with fees
    function createChannelWithFees(bytes calldata _identity) external onlyUserWithNoChannel {
        // Save gas, Emit the event out
        emit AddChannel(msg.sender, _identity);

        // Bubble down to create channel
        _createChannelWithFees();
    }

    /// @dev Deactivate channel
    function deactivateChannel() onlyActivatedChannels(msg.sender) external {
        channels[msg.sender].deactivated = true;
    }

    /// @dev delegate subscription to channel
    function subscribeWithPublicKeyDelegated(
        address _channel,
        address _user,
    bytes calldata _publicKey
    ) external onlyActivatedChannels(_channel) onlyNonGraylistedChannel(_channel, _user) {
        // Take delegation fees
        _takeDelegationFees();

        // Will save gas as it prevents calldata to be copied unless need be
        if (users[_user].publicKeyRegistered == false) {
        // broadcast it
        _broadcastPublicKey(msg.sender, _publicKey);
        }

        // Call actual subscribe
        _subscribe(_channel, _user);
    }

    /// @dev subscribe to channel delegated
    function subscribeDelegated(address _channel, address _user) external onlyActivatedChannels(_channel) onlyNonGraylistedChannel(_channel, _user) {
        // Take delegation fees
        _takeDelegationFees();

        // Call actual subscribe
        _subscribe(_channel, _user);
    }

    /// @dev subscribe to channel with public key
    function subscribeWithPublicKey(address _channel, bytes calldata _publicKey) onlyActivatedChannels(_channel) external {
        // Will save gas as it prevents calldata to be copied unless need be
        if (users[msg.sender].publicKeyRegistered == false) {

        // broadcast it
        _broadcastPublicKey(msg.sender, _publicKey);
        }

        // Call actual subscribe
        _subscribe(_channel, msg.sender);
    }

    /// @dev subscribe to channel
    function subscribe(address _channel) onlyActivatedChannels(_channel) external {
        // Call actual subscribe
        _subscribe(_channel, msg.sender);
    }

    /// @dev to unsubscribe from channel
    function unsubscribe(address _channel) external onlyValidChannel(_channel) onlyNonOwnerSubscribed(_channel, msg.sender) returns (uint ratio) {
        // Add the channel to gray list so that it can't subscriber the user again as delegated
        User storage user = users[msg.sender];

        // Treat it as graylisting
        user.graylistedChannels[_channel] = true;

        // first get ratio of earning
        ratio = 0;
        ratio = calcSingleChannelEarnRatio(_channel, msg.sender, block.number);

        // Take the fair share out

        // Remove the mappings and cleanup
        // a bit tricky, swap and delete to maintain mapping
        // Remove From Users mapping
        // Find the id of the channel and swap it with the last id, use channel.memberCount as index
        // Slack too deep fix
        // address usrSubToSwapAdrr = user.mapAddressSubscribed[user.subscribedCount];
        // uint usrSubSwapID = user.subscribed[_channel];

        // // swap to last one and then
        // user.subscribed[usrSubToSwapAdrr] = usrSubSwapID;
        // user.mapAddressSubscribed[usrSubSwapID] = usrSubToSwapAdrr;

        user.subscribed[user.mapAddressSubscribed[user.subscribedCount]] = user.subscribed[_channel];
        user.mapAddressSubscribed[user.subscribed[_channel]] = user.mapAddressSubscribed[user.subscribedCount];

        // delete the last one and substract
        delete(user.subscribed[_channel]);
        delete(user.mapAddressSubscribed[user.subscribedCount]);
        user.subscribedCount = user.subscribedCount.sub(1);

        // Remove from Channels mapping
        Channel storage channel = channels[_channel];

        // Set additional flag to false
        channel.memberExists[msg.sender] = false;

        // Find the id of the channel and swap it with the last id, use channel.memberCount as index
        // Slack too deep fix
        // address chnMemToSwapAdrr = channel.mapAddressMember[channel.memberCount];
        // uint chnMemSwapID = channel.members[msg.sender];

        // swap to last one and then
        channel.members[channel.mapAddressMember[channel.memberCount]] = channel.members[msg.sender];
        channel.mapAddressMember[channel.members[msg.sender]] = channel.mapAddressMember[channel.memberCount];

        // delete the last one and substract
        delete(channel.members[msg.sender]);
        delete(channel.mapAddressMember[channel.memberCount]);
        channel.memberCount = channel.memberCount.sub(1);

        // Next readjust fair share
        (
            channels[_channel].channelFairShareCount,
            channels[_channel].channelHistoricalZ,
            channels[_channel].channelLastUpdate
        ) = _readjustFairShareOfSubscribers(
            SubscriberAction.SubscriberRemoved,
            channels[_channel].channelFairShareCount,
            channels[_channel].channelHistoricalZ,
            channels[_channel].channelLastUpdate
        );

        // Next calculate and send the fair share earning of the user from this channel
        if (channel.channelType == ChannelType.InterestBearingChannel) {
            _withdrawFundsFromPool(ratio);
        }

        // Emit it
        emit Unsubscribe(_channel, msg.sender);
    }

    /// @dev to claim fair share of all earnings
    function claimFairShare() onlyValidUser(msg.sender) external returns (uint ratio){
        // Calculate entire FS Share, since we are looping for reset... let's calculate over there
        ratio = 0;

        // Reset member last update for every channel that are interest bearing
        // WARN: This unbounded for loop is an anti-pattern
        for (uint i = 0; i < users[msg.sender].subscribedCount; i++) {
            address channel = users[msg.sender].mapAddressSubscribed[i];

            if (channels[channel].channelType == ChannelType.InterestBearingChannel) {
                // Reset last updated block
                channels[channel].memberLastUpdate[msg.sender] = block.number;

                // Next readjust fair share and that's it
                (
                channels[channel].channelFairShareCount,
                channels[channel].channelHistoricalZ,
                channels[channel].channelLastUpdate
                ) = _readjustFairShareOfSubscribers(
                SubscriberAction.SubscriberUpdated,
                channels[channel].channelFairShareCount,
                channels[channel].channelHistoricalZ,
                channels[channel].channelLastUpdate
                );

                // Calculate share
                uint individualChannelShare = calcSingleChannelEarnRatio(channel, msg.sender, block.number);
                ratio = ratio.add(individualChannelShare);
            }

        }
        // Finally, withdraw for user
        _withdrawFundsFromPool(ratio);
    }

    /* @dev to send message to reciepient of a group, the first digit of msg type contains rhe push server flag
    ** So msg type 1 with using push is 11, without push is 10, in the future this can also be 12 (silent push)
    */
    function sendNotification(
        address _recipient,
        bytes calldata _identity
    ) external onlyChannelOwner(msg.sender) {
        // Just check if the msg is a secret, if so the user public key should be in the system
        // On second thought, leave it upon the channel, they might have used an alternate way to
        // encrypt the message using the public key

        // Emit the message out
        emit SendNotification(msg.sender, _recipient, _identity);
    }

    /// @dev to send message to reciepient of a group
    function sendNotificationOverrideChannel(
        address _channel,
        address _recipient,
        bytes calldata _identity
    ) external onlyChannelOwner(msg.sender) onlyGov {
        // Emit the message out
        emit SendNotification(_channel, _recipient, _identity);
    }

    /// @dev to withraw funds coming from delegate fees
    function withdrawDaiFunds() external onlyGov {
        // Get and transfer funds
        uint funds = ownerDaiFunds;
        IERC20(daiAddress).safeTransferFrom(address(this), msg.sender, funds);

        // Rest funds to 0
        ownerDaiFunds = 0;

        // Emit Evenet
        emit Withdrawal(msg.sender, daiAddress, funds);
    }

    /// @dev to withraw funds coming from donate
    function withdrawEthFunds() external onlyGov {
        uint bal = address(this).balance;

        payable(governance).transfer(bal);

        // Emit Event
        emit Withdrawal(msg.sender, daiAddress, bal);
    }

    /// @dev To check if member exists
    function memberExists(address _user, address _channel) external view returns (bool subscribed) {
        subscribed = channels[_channel].memberExists[_user];
    }

    /// @dev To fetch subscriber address for a channel
    function getChannelSubscriberAddress(address _channel, uint _subscriberId) external view returns (address subscriber) {
        subscriber = channels[_channel].mapAddressMember[_subscriberId];
    }

    /// @dev To fetch user id for a subscriber of a channel
    function getChannelSubscriberUserID(address _channel, uint _subscriberId) external view returns (uint userId) {
        userId = channels[_channel].members[channels[_channel].mapAddressMember[_subscriberId]];
    }

    /// @dev donate functionality for the smart contract
    function donate() public payable {
        require(msg.value >= 0.001 ether, "Minimum Donation amount is 0.001 ether");

        // Emit Event
        emit Donation(msg.sender, msg.value);
    }

    /// @dev to get channel fair share ratio for a given block
    function getChannelFSRatio(address _channel, uint _block) public view returns (uint ratio) {
        // formula is ratio = da / z + (nxw)
        // d is the difference of blocks from given block and the last update block of the entire group
        // a is the actual weight of that specific group
        // z is the historical constant
        // n is the number of channels
        // x is the difference of blocks from given block and the last changed start block of group
        // w is the normalized weight of the groups
        uint d = _block.sub(channels[_channel].channelStartBlock); // _block.sub(groupLastUpdate);
        uint a = channels[_channel].channelWeight;
        uint z = groupHistoricalZ;
        uint n = groupFairShareCount;
        uint x = _block.sub(groupLastUpdate);
        uint w = groupNormalizedWeight;

        uint nxw = n.mul(x.mul(w));
        uint z_nxw = z.add(nxw);
        uint da = d.mul(a);

        ratio = (da.mul(ADJUST_FOR_FLOAT)).div(z_nxw);
    }

    /// @dev to get subscriber fair share ratio for a given channel at a block
    function getSubscriberFSRatio(
        address _channel,
        address _user,
        uint _block
    ) public view onlySubscribed(_channel, _user) returns (uint ratio) {
        // formula is ratio = d / z + (nx)
        // d is the difference of blocks from given block and the start block of subscriber
        // z is the historical constant
        // n is the number of subscribers of channel
        // x is the difference of blocks from given block and the last changed start block of channel

        uint d = _block.sub(channels[_channel].memberLastUpdate[_user]);
        uint z = channels[_channel].channelHistoricalZ;
        uint x = _block.sub(channels[_channel].channelLastUpdate);

        uint nx = channels[_channel].channelFairShareCount.mul(x);

        ratio = (d.mul(ADJUST_FOR_FLOAT)).div(z.add(nx)); // == d / z + n * x
    }

    /* @dev to get the fair share of user for a single channel, different from subscriber fair share
     * as it's multiplication of channel fair share with subscriber fair share
     */
    function calcSingleChannelEarnRatio(
        address _channel,
        address _user,
        uint _block
    ) public view onlySubscribed(_channel, _user) returns (uint ratio) {
        // First get the channel fair share
        if (channels[_channel].channelType == ChannelType.InterestBearingChannel) {
            uint channelFS = getChannelFSRatio(_channel, _block);
            uint subscriberFS = getSubscriberFSRatio(_channel, _user, _block);

            ratio = channelFS.mul(subscriberFS).div(ADJUST_FOR_FLOAT);
        }
    }

    /// @dev to get the fair share of user overall
    function calcAllChannelsRatio(address _user, uint _block) onlyValidUser(_user) public view returns (uint ratio) {
        // loop all channels for the user
        uint subscribedCount = users[_user].subscribedCount;

        // WARN: This unbounded for loop is an anti-pattern
        for (uint i = 0; i < subscribedCount; i++) {
            if (channels[users[_user].mapAddressSubscribed[i]].channelType == ChannelType.InterestBearingChannel) {
                uint individualChannelShare = calcSingleChannelEarnRatio(users[_user].mapAddressSubscribed[i], _user, _block);
                ratio = ratio.add(individualChannelShare);
            }
        }
    }

    /// @dev Add the user to the ecosystem if they don't exists, the returned response is used to deliver a message to the user if they are recently added
    function _addUser(address _addr) private returns (bool userAlreadyAdded) {
        if (users[_addr].userActivated) {
            userAlreadyAdded = true;
        }
        else {
            // Activates the user
            users[_addr].userStartBlock = block.number;
            users[_addr].userActivated = true;
            mapAddressUsers[usersCount] = _addr;

            usersCount = usersCount.add(1);

            // Send Welcome Message
            emit SendNotification(governance, _addr, EPNS_FIRST_MESSAGE_HASH);
        }
    }

    /* @dev Internal system to handle broadcasting of public key,
    * is a entry point for subscribe, or create channel but is option
    */
    function _broadcastPublicKey(address _userAddr, bytes memory _publicKey) private {
        // Add the user, will do nothing if added already, but is needed before broadcast
        _addUser(_userAddr);

        // get address from public key
        address userAddr = getWalletFromPublicKey(_publicKey);

        if (_userAddr == userAddr) {
            // Only change it when verification suceeds, else assume the channel just wants to send group message
            users[userAddr].publicKeyRegistered = true;

            // Emit the event out
            emit PublicKeyRegistered(userAddr, _publicKey);
        }
        else {
            revert("Public Key Validation Failed");
        }
    }

    /// @dev Don't forget to add 0x into it
    function getWalletFromPublicKey (bytes memory _publicKey) public pure returns (address wallet) {
        if (_publicKey.length == 64) {
            wallet = address (uint160 (uint256 (keccak256 (_publicKey))));
        }
        else {
            wallet = 0x0000000000000000000000000000000000000000;
        }
    }

    /// @dev add channel with fees
    function _createChannelWithFees() private {
        // This module should be completely independent from the private _createChannel() so constructor can do it's magic
        // Get the approved allowance
        uint allowedAllowance = IERC20(daiAddress).allowance(msg.sender, address(this));

        // Check if it's equal or above Channel Pool Contribution
        require(
            allowedAllowance >= ADD_CHANNEL_MIN_POOL_CONTRIBUTION && allowedAllowance <= ADD_CHANNEL_MAX_POOL_CONTRIBUTION,
            "Insufficient Funds or max ceiling reached"
        );

        // Check and transfer funds
        IERC20(daiAddress).safeTransferFrom(msg.sender, address(this), allowedAllowance);

        // Deposit funds to pool
        _depositFundsToPool(allowedAllowance);

        // // Generate a random allowed allowance, for testing Generates 50 to 25000 range
        // uint allowedAllowance = ((uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % 24950) + 50) * 10 ** 18;
        // poolFunds = poolFunds.add(allowedAllowance);
        // Testing Endss

        // Call Create Channel
        _createChannel(msg.sender, ChannelType.InterestBearingChannel, allowedAllowance);
    }

    /// @dev Create channel internal method that runs
    function _createChannel(address _channel, ChannelType _channelType, uint _amountDeposited) private {
        // Add the user, will do nothing if added already, but is needed for all outpoints
        bool userAlreadyAdded = _addUser(_channel);

        // Calculate channel weight
        uint _channelWeight = _amountDeposited.mul(ADJUST_FOR_FLOAT).div(ADD_CHANNEL_MIN_POOL_CONTRIBUTION);

        // Next create the channel and mark user as channellized
        users[_channel].channellized = true;

        channels[_channel].poolContribution = _amountDeposited;
        channels[_channel].channelType = _channelType;
        channels[_channel].channelStartBlock = block.number;
        channels[_channel].channelWeight = _channelWeight;

        // Add to map of addresses and increment channel count
        mapAddressChannels[channelsCount] = _channel;
        channelsCount = channelsCount.add(1);

        // Readjust fair share if interest bearing
        if (_channelType == ChannelType.InterestBearingChannel) {
            (groupFairShareCount, groupNormalizedWeight, groupHistoricalZ, groupLastUpdate) = _readjustFairShareOfChannels(
                ChannelAction.ChannelAdded,
                _channelWeight,
                groupFairShareCount,
                groupNormalizedWeight,
                groupHistoricalZ,
                groupLastUpdate
            );
        }

        // If this is a new user than subscribe them to EPNS Channel
        if (userAlreadyAdded == false && _channel != 0x0000000000000000000000000000000000000000) {
            // Call actual subscribe, owner channel
            _subscribe(governance, _channel);
        }

        // All Channels are subscribed to EPNS Alerter as well, unless it's the EPNS Alerter channel iteself
        if (_channel != 0x0000000000000000000000000000000000000000) {
            _subscribe(0x0000000000000000000000000000000000000000, _channel);
        }

        // Subscribe them to their own channel as well
        if (_channel != governance) {
            _subscribe(_channel, _channel);
        }
    }

    /// @dev private function that eventually handles the subscribing onlyValidChannel(_channel)
    function _subscribe(address _channel, address _user) private onlyNonSubscribed(_channel, _user) {
        // Add the user, will do nothing if added already, but is needed for all outpoints
        _addUser(_user);

        User storage user = users[_user];
        Channel storage channel = channels[_channel];

        // treat the count as index and update user struct
        user.subscribed[_channel] = user.subscribedCount;
        user.mapAddressSubscribed[user.subscribedCount] = _channel;
        user.subscribedCount = user.subscribedCount.add(1); // Finally increment the subscribed count

        // Do the same for the channel to maintain sync, treat member count as index
        channel.members[_user] = channel.memberCount;
        channel.mapAddressMember[channel.memberCount] = _user;
        channel.memberCount = channel.memberCount.add(1); // Finally increment the member count

        // Set Additional flag for some conditions and set last update of member
        channel.memberLastUpdate[_user] = block.number;
        channel.memberExists[_user] = true;

        // Next readjust fair share and that's it
        (
            channels[_channel].channelFairShareCount,
            channels[_channel].channelHistoricalZ,
            channels[_channel].channelLastUpdate
        ) = _readjustFairShareOfSubscribers(
            SubscriberAction.SubscriberAdded,
            channels[_channel].channelFairShareCount,
            channels[_channel].channelHistoricalZ,
            channels[_channel].channelLastUpdate
        );

        // Emit it
        emit Subscribe(_channel, _user);
    }

    /// @dev charge delegation fee, small enough for serious players but thwarts bad actors
    function _takeDelegationFees() private {
        // Check and transfer funds
        // require( IERC20(daiAddress).safeTransferFrom(msg.sender, address(this), DELEGATED_CONTRACT_FEES), "Insufficient Funds");
        IERC20(daiAddress).safeTransferFrom(msg.sender, address(this), DELEGATED_CONTRACT_FEES);

        // Add it to owner kitty
        ownerDaiFunds.add(DELEGATED_CONTRACT_FEES);
    }

    /// @dev deposit funds to pool
    function _depositFundsToPool(uint amount) private {
        // Got the funds, add it to the channels dai pool
        poolFunds = poolFunds.add(amount);

        // Next swap it via AAVE for aDAI
        // mainnet address, for other addresses: https://docs.aave.com/developers/developing-on-aave/deployed-contract-instances
        ILendingPoolAddressesProvider provider = ILendingPoolAddressesProvider(lendingPoolProviderAddress);
        ILendingPool lendingPool = ILendingPool(provider.getLendingPool());
        IERC20(daiAddress).approve(provider.getLendingPoolCore(), amount);

        // Deposit to AAVE
        lendingPool.deposit(daiAddress, amount, uint16(REFERRAL_CODE)); // set to 0 in constructor presently
    }

        /// @dev withdraw funds from pool
    function _withdrawFundsFromPool(uint ratio) private nonReentrant {
        uint totalBalanceWithProfit = IERC20(aDaiAddress).balanceOf(address(this));

        // // Random for testing
        // uint totalBalanceWithProfit = ((uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % 24950) + 50) * 10 ** 19; // 10 times
        // // End Testing

        uint totalProfit = totalBalanceWithProfit.sub(poolFunds);
        uint userAmount = totalProfit.mul(ratio);

        // adjust poolFunds first
        uint userAmountAdjusted = userAmount.div(ADJUST_FOR_FLOAT);
        poolFunds = poolFunds.sub(userAmountAdjusted);

        // Add to interest claimed
        usersInterestClaimed[msg.sender] = usersInterestClaimed[msg.sender].add(userAmountAdjusted);

        // Finally transfer
        IERC20(aDaiAddress).transfer(msg.sender, userAmountAdjusted);

        // Emit Event
        emit InterestClaimed(msg.sender, userAmountAdjusted);
    }

    /// @dev readjust fair share runs on channel addition, removal or update of channel
    function _readjustFairShareOfChannels(
        ChannelAction _action,
        uint _channelWeight,
        uint _groupFairShareCount,
        uint _groupNormalizedWeight,
        uint _groupHistoricalZ,
        uint _groupLastUpdate
    )
    private
    view
    returns (
        uint groupNewCount,
        uint groupNewNormalizedWeight,
        uint groupNewHistoricalZ,
        uint groupNewLastUpdate
    )
    {
        // readjusts the group count and do deconstruction of weight
        uint groupModCount = _groupFairShareCount;
        uint prevGroupCount = groupModCount;

        uint totalWeight;
        uint adjustedNormalizedWeight = _groupNormalizedWeight; //_groupNormalizedWeight;

        // Increment or decrement count based on flag
        if (_action == ChannelAction.ChannelAdded) {
            groupModCount = groupModCount.add(1);

            totalWeight = adjustedNormalizedWeight.mul(prevGroupCount);
            totalWeight = totalWeight.add(_channelWeight);
        }
        else if (_action == ChannelAction.ChannelRemoved) {
            groupModCount = groupModCount.sub(1);

            totalWeight = adjustedNormalizedWeight.mul(prevGroupCount);
            totalWeight = totalWeight.sub(_channelWeight);
        }
        else if (_action == ChannelAction.ChannelUpdated) {
            totalWeight = adjustedNormalizedWeight.mul(prevGroupCount.sub(1));
            totalWeight = totalWeight.add(_channelWeight);
        }
        else {
            revert("Invalid Channel Action");
        }

        // now calculate the historical constant
        // z = z + nxw
        // z is the historical constant
        // n is the previous count of group fair share
        // x is the differential between the latest block and the last update block of the group
        // w is the normalized average of the group (ie, groupA weight is 1 and groupB is 2 then w is (1+2)/2 = 1.5)
        uint n = groupModCount;
        uint x = block.number.sub(_groupLastUpdate);
        uint w = totalWeight.div(groupModCount);
        uint z = _groupHistoricalZ;

        uint nx = n.mul(x);
        uint nxw = nx.mul(w);

        // Save Historical Constant and Update Last Change Block
        z = z.add(nxw);

        if (n == 1) {
            // z should start from here as this is first channel
            z = 0;
        }

        // Update return variables
        groupNewCount = groupModCount;
        groupNewNormalizedWeight = w;
        groupNewHistoricalZ = z;
        groupNewLastUpdate = block.number;
    }

    /// @dev readjust fair share runs on user addition or removal
    function _readjustFairShareOfSubscribers(
        SubscriberAction action,
        uint _channelFairShareCount,
        uint _channelHistoricalZ,
        uint _channelLastUpdate
    )
    private
    view
    returns (
        uint channelNewFairShareCount,
        uint channelNewHistoricalZ,
        uint channelNewLastUpdate
    )
    {
        uint channelModCount = _channelFairShareCount;
        uint prevChannelCount = channelModCount;

        // Increment or decrement count based on flag
        if (action == SubscriberAction.SubscriberAdded) {
            channelModCount = channelModCount.add(1);
        }
        else if (action == SubscriberAction.SubscriberRemoved) {
            channelModCount = channelModCount.sub(1);
        }
        else if (action == SubscriberAction.SubscriberUpdated) {
        // do nothing, it's happening after a reset of subscriber last update count

        }
        else {
            revert("Invalid Channel Action");
        }

        // to calculate the historical constant
        // z = z + nx
        // z is the historical constant
        // n is the total prevoius subscriber count
        // x is the difference bewtween the last changed block and the current block
        uint x = block.number.sub(_channelLastUpdate);
        uint nx = prevChannelCount.mul(x);
        uint z = _channelHistoricalZ.add(nx);

        // Define Values
        channelNewFairShareCount = channelModCount;
        channelNewHistoricalZ = z;
        channelNewLastUpdate = block.number;
    }
}


// File @openzeppelin/contracts/proxy/Proxy.sol@v3.2.0

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

/**
 * @dev This abstract contract provides a fallback function that delegates all calls to another contract using the EVM
 * instruction `delegatecall`. We refer to the second contract as the _implementation_ behind the proxy, and it has to
 * be specified by overriding the virtual {_implementation} function.
 * 
 * Additionally, delegation to the implementation can be triggered manually through the {_fallback} function, or to a
 * different contract through the {_delegate} function.
 * 
 * The success and return data of the delegated call will be returned back to the caller of the proxy.
 */
abstract contract Proxy {
    /**
     * @dev Delegates the current call to `implementation`.
     * 
     * This function does not return to its internall call site, it will return directly to the external caller.
     */
    function _delegate(address implementation) internal {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    /**
     * @dev This is a virtual function that should be overriden so it returns the address to which the fallback function
     * and {_fallback} should delegate.
     */
    function _implementation() internal virtual view returns (address);

    /**
     * @dev Delegates the current call to the address returned by `_implementation()`.
     * 
     * This function does not return to its internall call site, it will return directly to the external caller.
     */
    function _fallback() internal {
        _beforeFallback();
        _delegate(_implementation());
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
     * function in the contract matches the call data.
     */
    fallback () payable external {
        _fallback();
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if call data
     * is empty.
     */
    receive () payable external {
        _fallback();
    }

    /**
     * @dev Hook that is called before falling back to the implementation. Can happen as part of a manual `_fallback`
     * call, or as part of the Solidity `fallback` or `receive` functions.
     * 
     * If overriden should call `super._beforeFallback()`.
     */
    function _beforeFallback() internal virtual {
    }
}

library Address {
	/**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
	function isContract(address account) internal view returns (bool) {
		// This method relies in extcodesize, which returns 0 for contracts in
		// construction, since the code is only stored at the end of the
		// constructor execution.

		uint256 size;
		// solhint-disable-next-line no-inline-assembly
		assembly { size := extcodesize(account) }
		return size > 0;
	}

	/**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
	function sendValue(address payable recipient, uint256 amount) internal {
		require(address(this).balance >= amount, "Address: insufficient balance");

		// solhint-disable-next-line avoid-low-level-calls, avoid-call-value
		(bool success, ) = recipient.call{ value: amount }("");
		require(success, "Address: unable to send value, recipient may have reverted");
	}

	/**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
	function functionCall(address target, bytes memory data) internal returns (bytes memory) {
		return functionCall(target, data, "Address: low-level call failed");
	}

	/**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
	function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
		return _functionCallWithValue(target, data, 0, errorMessage);
	}

	/**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
	function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
		return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
	}

	/**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
	function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
		require(address(this).balance >= value, "Address: insufficient balance for call");
		return _functionCallWithValue(target, data, value, errorMessage);
	}

	function _functionCallWithValue(address target, bytes memory data, uint256 weiValue, string memory errorMessage) private returns (bytes memory) {
		require(isContract(target), "Address: call to non-contract");

		// solhint-disable-next-line avoid-low-level-calls
		(bool success, bytes memory returndata) = target.call{ value: weiValue }(data);
		if (success) {
			return returndata;
		} else {
			// Look for revert reason and bubble it up if present
			if (returndata.length > 0) {
				// The easiest way to bubble the revert reason is using memory via assembly

				// solhint-disable-next-line no-inline-assembly
				assembly {
					let returndata_size := mload(returndata)
					revert(add(32, returndata), returndata_size)
				}
			} else {
				revert(errorMessage);
			}
		}
	}
}

// File @openzeppelin/contracts/proxy/UpgradeableProxy.sol@v3.2.0

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;



/**
 * @dev This contract implements an upgradeable proxy. It is upgradeable because calls are delegated to an
 * implementation address that can be changed. This address is stored in storage in the location specified by
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967], so that it doesn't conflict with the storage layout of the
 * implementation behind the proxy.
 * 
 * Upgradeability is only provided internally through {_upgradeTo}. For an externally upgradeable proxy see
 * {TransparentUpgradeableProxy}.
 */
contract UpgradeableProxy is Proxy {
    /**
     * @dev Initializes the upgradeable proxy with an initial implementation specified by `_logic`.
     * 
     * If `_data` is nonempty, it's used as data in a delegate call to `_logic`. This will typically be an encoded
     * function call, and allows initializating the storage of the proxy like a Solidity constructor.
     */
    constructor(address _logic, bytes memory _data) public payable {
        assert(_IMPLEMENTATION_SLOT == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1));
        _setImplementation(_logic);
        if(_data.length > 0) {
            // solhint-disable-next-line avoid-low-level-calls
            (bool success,) = _logic.delegatecall(_data);
            require(success);
        }
    }

    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Returns the current implementation address.
     */
    function _implementation() internal override view returns (address impl) {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            impl := sload(slot)
        }
    }

    /**
     * @dev Upgrades the proxy to a new implementation.
     * 
     * Emits an {Upgraded} event.
     */
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "UpgradeableProxy: new implementation is not a contract");

        bytes32 slot = _IMPLEMENTATION_SLOT;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(slot, newImplementation)
        }
    }
}


// File @openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol@v3.2.0

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;


/**
 * @dev This contract implements a proxy that is upgradeable by an admin.
 * 
 * To avoid https://medium.com/nomic-labs-blog/malicious-backdoors-in-ethereum-proxies-62629adf3357[proxy selector
 * clashing], which can potentially be used in an attack, this contract uses the
 * https://blog.openzeppelin.com/the-transparent-proxy-pattern/[transparent proxy pattern]. This pattern implies two
 * things that go hand in hand:
 * 
 * 1. If any account other than the admin calls the proxy, the call will be forwarded to the implementation, even if
 * that call matches one of the admin functions exposed by the proxy itself.
 * 2. If the admin calls the proxy, it can access the admin functions, but its calls will never be forwarded to the
 * implementation. If the admin tries to call a function on the implementation it will fail with an error that says
 * "admin cannot fallback to proxy target".
 * 
 * These properties mean that the admin account can only be used for admin actions like upgrading the proxy or changing
 * the admin, so it's best if it's a dedicated account that is not used for anything else. This will avoid headaches due
 * to sudden errors when trying to call a function from the proxy implementation.
 * 
 * Our recommendation is for the dedicated account to be an instance of the {ProxyAdmin} contract. If set up this way,
 * you should think of the `ProxyAdmin` instance as the real administrative inerface of your proxy.
 */
contract TransparentUpgradeableProxy is UpgradeableProxy {
    /**
     * @dev Initializes an upgradeable proxy managed by `_admin`, backed by the implementation at `_logic`, and
     * optionally initialized with `_data` as explained in {UpgradeableProxy-constructor}.
     */
    constructor(address _logic, address _admin, bytes memory _data) public payable UpgradeableProxy(_logic, _data) {
        assert(_ADMIN_SLOT == bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1));
        _setAdmin(_admin);
    }

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 private constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Modifier used internally that will delegate the call to the implementation unless the sender is the admin.
     */
    modifier ifAdmin() {
        if (msg.sender == _admin()) {
            _;
        } else {
            _fallback();
        }
    }

    /**
     * @dev Returns the current admin.
     * 
     * NOTE: Only the admin can call this function. See {ProxyAdmin-getProxyAdmin}.
     * 
     * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using the
     * https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
     * `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103`
     */
    function admin() external ifAdmin returns (address) {
        return _admin();
    }

    /**
     * @dev Returns the current implementation.
     * 
     * NOTE: Only the admin can call this function. See {ProxyAdmin-getProxyImplementation}.
     * 
     * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using the
     * https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
     * `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc`
     */
    function implementation() external ifAdmin returns (address) {
        return _implementation();
    }

    /**
     * @dev Changes the admin of the proxy.
     * 
     * Emits an {AdminChanged} event.
     * 
     * NOTE: Only the admin can call this function. See {ProxyAdmin-changeProxyAdmin}.
     */
    function changeAdmin(address newAdmin) external ifAdmin {
        require(newAdmin != address(0), "TransparentUpgradeableProxy: new admin is the zero address");
        emit AdminChanged(_admin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev Upgrade the implementation of the proxy.
     * 
     * NOTE: Only the admin can call this function. See {ProxyAdmin-upgrade}.
     */
    function upgradeTo(address newImplementation) external ifAdmin {
        _upgradeTo(newImplementation);
    }

    /**
     * @dev Upgrade the implementation of the proxy, and then call a function from the new implementation as specified
     * by `data`, which should be an encoded function call. This is useful to initialize new storage variables in the
     * proxied contract.
     * 
     * NOTE: Only the admin can call this function. See {ProxyAdmin-upgradeAndCall}.
     */
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable ifAdmin {
        _upgradeTo(newImplementation);
        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = newImplementation.delegatecall(data);
        require(success);
    }

    /**
     * @dev Returns the current admin.
     */
    function _admin() internal view returns (address adm) {
        bytes32 slot = _ADMIN_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            adm := sload(slot)
        }
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        bytes32 slot = _ADMIN_SLOT;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(slot, newAdmin)
        }
    }

    /**
     * @dev Makes sure the admin cannot access the fallback function. See {Proxy-_beforeFallback}.
     */
    function _beforeFallback() internal override virtual {
        require(msg.sender != _admin(), "TransparentUpgradeableProxy: admin cannot fallback to proxy target");
        super._beforeFallback();
    }
}


// File contracts/EPNSProxy.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;


contract EPNSProxy is TransparentUpgradeableProxy {


    constructor(
        address _logic,
        address _governance,
        address _lendingPoolProviderAddress,
        address _daiAddress,
        address _aDaiAddress,
        uint _referralCode
    ) public payable TransparentUpgradeableProxy(_logic, _governance, abi.encodeWithSignature('initialize(address,address,address,address,uint256)', _governance, _lendingPoolProviderAddress, _daiAddress, _aDaiAddress, _referralCode)) {}

}


// File contracts/EPNS.sol

pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;

contract EPNS {
    /// @notice EIP-20 token name for this token
    string public name = "Ethereum Push Notifications";

    /// @notice EIP-20 token symbol for this token
    string public symbol = "EPNS";

    /// @notice EIP-20 token decimals for this token
    uint8 public decimals = 18;

    /// @notice Total number of tokens in circulation
    uint public totalSupply = 100000000e18; // 100 million EPNS

    /// @notice Allowance amounts on behalf of others
    mapping (address => mapping (address => uint96)) internal allowances;

    /// @notice Official record of token balances for each account
    mapping (address => uint96) internal balances;

    /// @notice A record of each accounts delegate
    mapping (address => address) public delegates;

    /// @notice A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint32 fromBlock;
        uint96 votes;
    }

    /// @notice A record of votes checkpoints for each account, by index
    mapping (address => mapping (uint32 => Checkpoint)) public checkpoints;

    /// @notice The number of checkpoints for each account
    mapping (address => uint32) public numCheckpoints;

    /// @notice A FairShare Checkpoint for marking number of tokens
    struct FairShareCheckpoint {
        uint32 fromBlock;
        uint96 balance;
    }

    /// @notice A record of votes checkpoints for each account, by index
    mapping (address => mapping (uint32 => FairShareCheckpoint)) public FSCheckpoints;

    /// @notice The number of checkpoints for each account
    mapping (address => uint32) public numFSCheckpoints;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    /// @notice A record of states for signing / validating signatures
    mapping (address => uint) public nonces;

    /// @notice An event thats emitted when an account changes its delegate
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    /// @notice An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);

    /// @notice An event thats emitted when a delegate account's vote balance changes
    event FairShareRatioChanged(address indexed holder, uint previousRatio, uint newRatio);

    /// @notice The standard EIP-20 transfer event
    event Transfer(address indexed from, address indexed to, uint256 amount);

    /// @notice The standard EIP-20 approval event
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /**
     * @notice Construct a new EPNS token
     */
    constructor() public {
        address account = msg.sender;
        balances[account] = uint96(totalSupply);
        emit Transfer(address(0), account, totalSupply);
    }

    /**
     * @notice Get the number of tokens `spender` is approved to spend on behalf of `account`
     * @param account The address of the account holding the funds
     * @param spender The address of the account spending the funds
     * @return The number of tokens approved
     */
    function allowance(address account, address spender) external view returns (uint) {
        return allowances[account][spender];
    }

    /**
     * @notice Approve `spender` to transfer up to `amount` from `src`
     * @dev This will overwrite the approval amount for `spender`
     *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
     * @param spender The address of the account which may transfer tokens
     * @param rawAmount The number of tokens that are approved (2^256-1 means infinite)
     * @return Whether or not the approval succeeded
     */
    function approve(address spender, uint rawAmount) external returns (bool) {
        uint96 amount;
        if (rawAmount == uint(-1)) {
            amount = uint96(-1);
        } else {
            amount = safe96(rawAmount, "EPNS::approve: amount exceeds 96 bits");
        }

        allowances[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /**
     * @notice Get the number of tokens held by the `account`
     * @param account The address of the account to get the balance of
     * @return The number of tokens held
     */
    function balanceOf(address account) external view returns (uint) {
        return balances[account];
    }

    /**
     * @notice Transfer `amount` tokens from `msg.sender` to `dst`
     * @param dst The address of the destination account
     * @param rawAmount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
     function transfer(address dst, uint rawAmount)  external returns (bool) {
        uint96 amount = safe96(rawAmount, "EPNS::transfer: amount exceeds 96 bits");
        _updateFSRatio(msg.sender, dst, amount);
        _transferTokens(msg.sender, dst, amount);
        return true;
    }

    /**
     * @notice Transfer `amount` tokens from `src` to `dst`
     * @param src The address of the source account
     * @param dst The address of the destination account
     * @param rawAmount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transferFrom(address src, address dst, uint rawAmount) external returns (bool) {
        address spender = msg.sender;
        uint96 spenderAllowance = allowances[src][spender];
        uint96 amount = safe96(rawAmount, "EPNS::approve: amount exceeds 96 bits");

        if (spender != src && spenderAllowance != uint96(-1)) {
            uint96 newAllowance = sub96(spenderAllowance, amount, "EPNS::transferFrom: transfer amount exceeds spender allowance");
            allowances[src][spender] = newAllowance;

            emit Approval(src, spender, newAllowance);
        }

        _transferTokens(src, dst, amount);
        return true;
    }

    /**
     * @notice Delegate votes from `msg.sender` to `delegatee`
     * @param delegatee The address to delegate votes to
     */
    function delegate(address delegatee) public {
        return _delegate(msg.sender, delegatee);
    }

    /**
     * @notice Delegates votes from signatory to `delegatee`
     * @param delegatee The address to delegate votes to
     * @param nonce The contract state required to match the signature
     * @param expiry The time at which to expire the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function delegateBySig(address delegatee, uint nonce, uint expiry, uint8 v, bytes32 r, bytes32 s) public {
        bytes32 domainSeparator = keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), getChainId(), address(this)));
        bytes32 structHash = keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "EPNS::delegateBySig: invalid signature");
        require(nonce == nonces[signatory]++, "EPNS::delegateBySig: invalid nonce");
        require(now <= expiry, "EPNS::delegateBySig: signature expired");
        return _delegate(signatory, delegatee);
    }

    /**
     * @notice Gets the current votes balance for `account`
     * @param account The address to get votes balance
     * @return The number of current votes for `account`
     */
    function getCurrentVotes(address account) external view returns (uint96) {
        uint32 nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorVotes(address account, uint blockNumber) public view returns (uint96) {
        require(blockNumber < block.number, "EPNS::getPriorVotes: not yet determined");

        uint32 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }

        // Next check implicit zero balance
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        uint32 lower = 0;
        uint32 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[account][lower].votes;
    }

    function _delegate(address delegator, address delegatee) internal {
        address currentDelegate = delegates[delegator];
        uint96 delegatorBalance = balances[delegator];
        delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }

    function _transferTokens(address src, address dst, uint96 amount) internal {
        require(src != address(0), "EPNS::_transferTokens: cannot transfer from the zero address");
        require(dst != address(0), "EPNS::_transferTokens: cannot transfer to the zero address");

        balances[src] = sub96(balances[src], amount, "EPNS::_transferTokens: transfer amount exceeds balance");
        balances[dst] = add96(balances[dst], amount, "EPNS::_transferTokens: transfer amount overflows");
        emit Transfer(src, dst, amount);

        _moveDelegates(delegates[src], delegates[dst], amount);
    }

    function _moveDelegates(address srcRep, address dstRep, uint96 amount) internal {
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                uint32 srcRepNum = numCheckpoints[srcRep];
                uint96 srcRepOld = srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
                uint96 srcRepNew = sub96(srcRepOld, amount, "EPNS::_moveVotes: vote amount underflows");
                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }

            if (dstRep != address(0)) {
                uint32 dstRepNum = numCheckpoints[dstRep];
                uint96 dstRepOld = dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
                uint96 dstRepNew = add96(dstRepOld, amount, "EPNS::_moveVotes: vote amount overflows");
                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }

    function _updateFSRatio(address sender, address receiver, uint96 amount) internal {
        if (sender != receiver && amount > 0) {
            if (sender != address(0)) {
                uint32 srcRepNum = numFSCheckpoints[sender];
                uint96 srcRepOld = srcRepNum > 0 ? FSCheckpoints[sender][srcRepNum - 1].balance : 0;
                uint96 srcRepNew = sub96(srcRepOld, amount, "EPNS::_updateFSRatio: balance amount underflows");
                _writeFSCheckpoint(sender, srcRepNum, srcRepOld, srcRepNew);
            }

            if (receiver != address(0)) {
                uint32 dstRepNum = numFSCheckpoints[receiver];
                uint96 dstRepOld = dstRepNum > 0 ? FSCheckpoints[receiver][dstRepNum - 1].balance : 0;
                uint96 dstRepNew = add96(dstRepOld, amount, "EPNS::_updateFSRatio: balance amount overflows");
                _writeFSCheckpoint(receiver, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }

    function _writeCheckpoint(address delegatee, uint32 nCheckpoints, uint96 oldVotes, uint96 newVotes) internal {
        uint32 blockNumber = safe32(block.number, "EPNS::_writeCheckpoint: block number exceeds 32 bits");

        if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    function _writeFSCheckpoint(address holder, uint32 nCheckpoints, uint96 oldBalance, uint96 newBalance) internal {
        uint32 blockNumber = safe32(block.number, "EPNS::_writeFSCheckpoint: block number exceeds 32 bits");

        if (nCheckpoints > 0 && FSCheckpoints[holder][nCheckpoints - 1].fromBlock == blockNumber) {
            //are we putting an algorithim
            FSCheckpoints[holder][nCheckpoints - 1].balance = newBalance;
        } else {
            FSCheckpoints[holder][nCheckpoints] = FairShareCheckpoint(blockNumber, newBalance);
            numFSCheckpoints[holder] = nCheckpoints + 1;
        }

        emit FairShareRatioChanged(holder, oldBalance, newBalance);
    }

    function safe32(uint n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }

    function safe96(uint n, string memory errorMessage) internal pure returns (uint96) {
        require(n < 2**96, errorMessage);
        return uint96(n);
    }

    function add96(uint96 a, uint96 b, string memory errorMessage) internal pure returns (uint96) {
        uint96 c = a + b;
        require(c >= a, errorMessage);
        return c;
    }

    function sub96(uint96 a, uint96 b, string memory errorMessage) internal pure returns (uint96) {
        require(b <= a, errorMessage);
        return a - b;
    }

    function getChainId() internal pure returns (uint) {
        uint256 chainId;
        assembly { chainId := chainid() }
        return chainId;
    }
}


// File contracts/GovernorAlpha.sol

pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;

contract GovernorAlpha {
    /// @notice The name of this contract
    string public constant name = "EPNS Governor Alpha";

    /// @notice The number of votes in support of a proposal required in order for a quorum to be reached and for a vote to succeed
    function quorumVotes() public pure returns (uint) { return 40000000e18; } // 40,000,000 = 4% of EPNS

    /// @notice The number of votes required in order for a voter to become a proposer
    function proposalThreshold() public pure returns (uint) { return 500000e18; } // 500,000 = 0.5% of EPNS

    /// @notice The maximum number of actions that can be included in a proposal
    function proposalMaxOperations() public pure returns (uint) { return 10; } // 10 actions

    /// @notice The delay before voting on a proposal may take place, once proposed
    function votingDelay() public pure returns (uint) { return 1; } // 1 block

    /// @notice The duration of voting on a proposal, in blocks
    function votingPeriod() public pure returns (uint) { return 1; } // ~3 days in blocks (assuming 15s blocks)

    /// @notice The address of the EPNS Protocol Timelock
    TimelockInterface public timelock;

    /// @notice The address of the EPNS governance token
    EPNSInterface public EPNS;

    /// @notice The address of the Governor Guardian
    address public guardian;

    /// @notice The total number of proposals
    uint public proposalCount;

    struct Proposal {
        /// @notice Unique id for looking up a proposal
        uint id;

        /// @notice Creator of the proposal
        address proposer;

        /// @notice The timestamp that the proposal will be available for execution, set once the vote succeeds
        uint eta;

        /// @notice the ordered list of target addresses for calls to be made
        address[] targets;

        /// @notice The ordered list of values (i.e. msg.value) to be passed to the calls to be made
        uint[] values;

        /// @notice The ordered list of function signatures to be called
        string[] signatures;

        /// @notice The ordered list of calldata to be passed to each call
        bytes[] calldatas;

        /// @notice The block at which voting begins: holders must delegate their votes prior to this block
        uint startBlock;

        /// @notice The block at which voting ends: votes must be cast prior to this block
        uint endBlock;

        /// @notice Current number of votes in favor of this proposal
        uint forVotes;

        /// @notice Current number of votes in opposition to this proposal
        uint againstVotes;

        /// @notice Flag marking whether the proposal has been canceled
        bool canceled;

        /// @notice Flag marking whether the proposal has been executed
        bool executed;

        /// @notice Receipts of ballots for the entire set of voters
        mapping (address => Receipt) receipts;
    }

    /// @notice Ballot receipt record for a voter
    struct Receipt {
        /// @notice Whether or not a vote has been cast
        bool hasVoted;

        /// @notice Whether or not the voter supports the proposal
        bool support;

        /// @notice The number of votes the voter had, which were cast
        uint96 votes;
    }

    /// @notice Possible states that a proposal may be in
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    /// @notice The official record of all proposals ever proposed
    mapping (uint => Proposal) public proposals;

    /// @notice The latest proposal for each proposer
    mapping (address => uint) public latestProposalIds;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the ballot struct used by the contract
    bytes32 public constant BALLOT_TYPEHASH = keccak256("Ballot(uint256 proposalId,bool support)");

    /// @notice An event emitted when a new proposal is created
    event ProposalCreated(uint id, address proposer, address[] targets, uint[] values, string[] signatures, bytes[] calldatas, uint startBlock, uint endBlock, string description);

    /// @notice An event emitted when a vote has been cast on a proposal
    event VoteCast(address voter, uint proposalId, bool support, uint votes);

    /// @notice An event emitted when a proposal has been canceled
    event ProposalCanceled(uint id);

    /// @notice An event emitted when a proposal has been queued in the Timelock
    event ProposalQueued(uint id, uint eta);

    /// @notice An event emitted when a proposal has been executed in the Timelock
    event ProposalExecuted(uint id);

    constructor(address timelock_, address EPNS_, address guardian_) public {
        timelock = TimelockInterface(timelock_);
        EPNS = EPNSInterface(EPNS_);
        guardian = guardian_;
    }

    function propose(address[] memory targets, uint[] memory values, string[] memory signatures, bytes[] memory calldatas, string memory description) public returns (uint) {
        require(EPNS.getPriorVotes(msg.sender, sub256(block.number, 1)) > proposalThreshold(), "GovernorAlpha::propose: proposer votes below proposal threshold");
        require(targets.length == values.length && targets.length == signatures.length && targets.length == calldatas.length, "GovernorAlpha::propose: proposal function information arity mismatch");
        require(targets.length != 0, "GovernorAlpha::propose: must provide actions");
        require(targets.length <= proposalMaxOperations(), "GovernorAlpha::propose: too EPNS actions");

        uint latestProposalId = latestProposalIds[msg.sender];
        if (latestProposalId != 0) {
            ProposalState proposersLatestProposalState = state(latestProposalId);
            require(proposersLatestProposalState != ProposalState.Active, "GovernorAlpha::propose: one live proposal per proposer, found an already active proposal");
            require(proposersLatestProposalState != ProposalState.Pending, "GovernorAlpha::propose: one live proposal per proposer, found an already pending proposal");
        }

        uint startBlock = add256(block.number, votingDelay());
        uint endBlock = add256(startBlock, votingPeriod());

        proposalCount++;
        Proposal memory newProposal = Proposal({
        id: proposalCount,
        proposer: msg.sender,
        eta: 0,
        targets: targets,
        values: values,
        signatures: signatures,
        calldatas: calldatas,
        startBlock: startBlock,
        endBlock: endBlock,
        forVotes: 0,
        againstVotes: 0,
        canceled: false,
        executed: false
        });

        proposals[newProposal.id] = newProposal;
        latestProposalIds[newProposal.proposer] = newProposal.id;

        emit ProposalCreated(newProposal.id, msg.sender, targets, values, signatures, calldatas, startBlock, endBlock, description);
        return newProposal.id;
    }

    function queue(uint proposalId) public {
        require(state(proposalId) == ProposalState.Succeeded, "GovernorAlpha::queue: proposal can only be queued if it is succeeded");
        Proposal storage proposal = proposals[proposalId];
        uint eta = add256(block.timestamp, timelock.delay());
        for (uint i = 0; i < proposal.targets.length; i++) {
            _queueOrRevert(proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], eta);
        }
        proposal.eta = eta;
        emit ProposalQueued(proposalId, eta);
    }

    function _queueOrRevert(address target, uint value, string memory signature, bytes memory data, uint eta) internal {
        require(!timelock.queuedTransactions(keccak256(abi.encode(target, value, signature, data, eta))), "GovernorAlpha::_queueOrRevert: proposal action already queued at eta");
        timelock.queueTransaction(target, value, signature, data, eta);
    }

    function execute(uint proposalId) public payable {
        require(state(proposalId) == ProposalState.Queued, "GovernorAlpha::execute: proposal can only be executed if it is queued");
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;
        for (uint i = 0; i < proposal.targets.length; i++) {
            timelock.executeTransaction.value(proposal.values[i])(proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], proposal.eta);
        }
        emit ProposalExecuted(proposalId);
    }

    function cancel(uint proposalId) public {
        ProposalState state = state(proposalId);
        require(state != ProposalState.Executed, "GovernorAlpha::cancel: cannot cancel executed proposal");

        Proposal storage proposal = proposals[proposalId];
        require(msg.sender == guardian || EPNS.getPriorVotes(proposal.proposer, sub256(block.number, 1)) < proposalThreshold(), "GovernorAlpha::cancel: proposer above threshold");

        proposal.canceled = true;
        for (uint i = 0; i < proposal.targets.length; i++) {
            timelock.cancelTransaction(proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], proposal.eta);
        }

        emit ProposalCanceled(proposalId);
    }

    function getActions(uint proposalId) public view returns (address[] memory targets, uint[] memory values, string[] memory signatures, bytes[] memory calldatas) {
        Proposal storage p = proposals[proposalId];
        return (p.targets, p.values, p.signatures, p.calldatas);
    }

    function getReceipt(uint proposalId, address voter) public view returns (Receipt memory) {
        return proposals[proposalId].receipts[voter];
    }

    function state(uint proposalId) public view returns (ProposalState) {
        require(proposalCount >= proposalId && proposalId > 0, "GovernorAlpha::state: invalid proposal id");
        Proposal storage proposal = proposals[proposalId];
        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < quorumVotes()) {
            return ProposalState.Defeated;
        } else if (proposal.eta == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp >= add256(proposal.eta, timelock.GRACE_PERIOD())) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    function castVote(uint proposalId, bool support) public {
        return _castVote(msg.sender, proposalId, support);
    }

    function castVoteBySig(uint proposalId, bool support, uint8 v, bytes32 r, bytes32 s) public {
        bytes32 domainSeparator = keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), getChainId(), address(this)));
        bytes32 structHash = keccak256(abi.encode(BALLOT_TYPEHASH, proposalId, support));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "GovernorAlpha::castVoteBySig: invalid signature");
        return _castVote(signatory, proposalId, support);
    }

    function _castVote(address voter, uint proposalId, bool support) internal {
        require(state(proposalId) == ProposalState.Active, "GovernorAlpha::_castVote: voting is closed");
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        require(receipt.hasVoted == false, "GovernorAlpha::_castVote: voter already voted");
        uint96 votes = EPNS.getPriorVotes(voter, proposal.startBlock);

        if (support) {
            proposal.forVotes = add256(proposal.forVotes, votes);
        } else {
            proposal.againstVotes = add256(proposal.againstVotes, votes);
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        emit VoteCast(voter, proposalId, support, votes);
    }

    function __acceptAdmin() public {
        require(msg.sender == guardian, "GovernorAlpha::__acceptAdmin: sender must be gov guardian");
        timelock.acceptAdmin();
    }

    function __abdicate() public {
        require(msg.sender == guardian, "GovernorAlpha::__abdicate: sender must be gov guardian");
        guardian = address(0);
    }

    function __queueSetTimelockPendingAdmin(address newPendingAdmin, uint eta) public {
        require(msg.sender == guardian, "GovernorAlpha::__queueSetTimelockPendingAdmin: sender must be gov guardian");
        timelock.queueTransaction(address(timelock), 0, "setPendingAdmin(address)", abi.encode(newPendingAdmin), eta);
    }

    function __executeSetTimelockPendingAdmin(address newPendingAdmin, uint eta) public {
        require(msg.sender == guardian, "GovernorAlpha::__executeSetTimelockPendingAdmin: sender must be gov guardian");
        timelock.executeTransaction(address(timelock), 0, "setPendingAdmin(address)", abi.encode(newPendingAdmin), eta);
    }

    function add256(uint256 a, uint256 b) internal pure returns (uint) {
        uint c = a + b;
        require(c >= a, "addition overflow");
        return c;
    }

    function sub256(uint256 a, uint256 b) internal pure returns (uint) {
        require(b <= a, "subtraction underflow");
        return a - b;
    }

    function getChainId() internal pure returns (uint) {
        uint chainId;
        assembly { chainId := chainid() }
        return chainId;
    }
}

interface TimelockInterface {
    function delay() external view returns (uint);
    function GRACE_PERIOD() external view returns (uint);
    function acceptAdmin() external;
    function queuedTransactions(bytes32 hash) external view returns (bool);
    function queueTransaction(address target, uint value, string calldata signature, bytes calldata data, uint eta) external returns (bytes32);
    function cancelTransaction(address target, uint value, string calldata signature, bytes calldata data, uint eta) external;
    function executeTransaction(address target, uint value, string calldata signature, bytes calldata data, uint eta) external payable returns (bytes memory);
}

interface EPNSInterface {
    function getPriorVotes(address account, uint blockNumber) external view returns (uint96);
}


// File contracts/Timelock.sol

/**
 *Submitted for verification at Etherscan.io on 2020-09-16
*/

/**
 *Submitted for verification at Etherscan.io on 2020-09-14
*/

pragma solidity >=0.6.0 <0.7.0;
// From https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/Math.sol
// Subject to the MIT license.

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting with custom message on overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, errorMessage);

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on underflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot underflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction underflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on underflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot underflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, errorMessage);

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers.
     * Reverts on division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers.
     * Reverts with custom message on division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

contract Timelock {
    using SafeMath for uint;

    event NewAdmin(address indexed newAdmin);
    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewDelay(uint indexed newDelay);
    event CancelTransaction(bytes32 indexed txHash, address indexed target, uint value, string signature,  bytes data, uint eta);
    event ExecuteTransaction(bytes32 indexed txHash, address indexed target, uint value, string signature,  bytes data, uint eta);
    event QueueTransaction(bytes32 indexed txHash, address indexed target, uint value, string signature, bytes data, uint eta);

    uint public constant GRACE_PERIOD = 14 days;
    uint public constant MINIMUM_DELAY = 0 days;
    uint public constant MAXIMUM_DELAY = 30 days;

    address public admin;
    address public pendingAdmin;
    uint public delay;

    mapping (bytes32 => bool) public queuedTransactions;


    constructor(address admin_, uint delay_) public {
        require(delay_ >= MINIMUM_DELAY, "Timelock::constructor: Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Timelock::setDelay: Delay must not exceed maximum delay.");

        admin = admin_;
        delay = delay_;
    }

    fallback() external payable  { }

    function setDelay(uint delay_) public {
        require(msg.sender == address(this), "Timelock::setDelay: Call must come from Timelock.");
        require(delay_ >= MINIMUM_DELAY, "Timelock::setDelay: Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Timelock::setDelay: Delay must not exceed maximum delay.");
        delay = delay_;

        emit NewDelay(delay);
    }

    function acceptAdmin() public {
        require(msg.sender == pendingAdmin, "Timelock::acceptAdmin: Call must come from pendingAdmin.");
        admin = msg.sender;
        pendingAdmin = address(0);

        emit NewAdmin(admin);
    }

    function setPendingAdmin(address pendingAdmin_) public {
        require(msg.sender == address(this), "Timelock::setPendingAdmin: Call must come from Timelock.");
        pendingAdmin = pendingAdmin_;

        emit NewPendingAdmin(pendingAdmin);
    }

    function queueTransaction(address target, uint value, string memory signature, bytes memory data, uint eta) public returns (bytes32) {
        require(msg.sender == admin, "Timelock::queueTransaction: Call must come from admin.");
        require(eta >= getBlockTimestamp().add(delay), "Timelock::queueTransaction: Estimated execution block must satisfy delay.");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    function cancelTransaction(address target, uint value, string memory signature, bytes memory data, uint eta) public {
        require(msg.sender == admin, "Timelock::cancelTransaction: Call must come from admin.");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    function executeTransaction(address target, uint value, string memory signature, bytes memory data, uint eta) public payable returns (bytes memory) {
        require(msg.sender == admin, "Timelock::executeTransaction: Call must come from admin.");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(queuedTransactions[txHash], "Timelock::executeTransaction: Transaction hasn't been queued.");
        require(getBlockTimestamp() >= eta, "Timelock::executeTransaction: Transaction hasn't surpassed time lock.");
        require(getBlockTimestamp() <= eta.add(GRACE_PERIOD), "Timelock::executeTransaction: Transaction is stale.");

        queuedTransactions[txHash] = false;

        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }
        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = target.call.value(value)(callData);
        require(success, "Timelock::executeTransaction: Transaction execution reverted.");

        emit ExecuteTransaction(txHash, target, value, signature, data, eta);

        return returnData;
    }

    function getBlockTimestamp() internal view returns (uint) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }
}
