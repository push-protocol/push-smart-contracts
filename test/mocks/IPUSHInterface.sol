// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

/// @notice A subset of the ERC20Votes-style governance token to which UNI conforms.
/// Methods related to standard ERC20 functionality and to delegation are included.
/// These methods are needed in the context of this system. Methods related to check pointing,
/// past voting weights, and other functionality are omitted.
interface IPUSH {
  // ERC20 related methods
  function allowance(address account, address spender) external view returns (uint256);
  function approve(address spender, uint256 rawAmount) external returns (bool);
  function balanceOf(address account) external view returns (uint256);
  function decimals() external view returns (uint8);
  function symbol() external view returns (string memory);
  function totalSupply() external view returns (uint256);
  function transfer(address dst, uint256 rawAmount) external returns (bool);
  function transferFrom(address src, address dst, uint256 rawAmount) external returns (bool);

  // ERC20Votes delegation methods
  function delegate(address delegatee) external;
  function delegates(address) external view returns (address);
}
