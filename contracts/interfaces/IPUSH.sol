pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPUSH is IERC20 {
  function born() external view returns(uint);
  function resetHolderWeight(address holder) external;
  function holderWeight(address) external view returns (uint);
  function returnHolderUnits(address account, uint atBlock) external view returns (uint);
  function setHolderDelegation(address delegate, bool value) external;
}
