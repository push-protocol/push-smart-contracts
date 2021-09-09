pragma solidity >=0.6.0 <0.7.0;

interface IPUSH {
  function returnHolderUnits(address account, uint atBlock) external view returns (uint);
  function resetHolderWeight(address holder) external;
}
