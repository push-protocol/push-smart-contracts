pragma solidity ^0.8.20;

interface IPUSH {
    function born() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function resetHolderWeight(address holder) external;
    function holderWeight(address) external view returns (uint256);
    function returnHolderUnits(address account, uint256 atBlock) external view returns (uint256);
 function setHolderDelegation(address delegate, bool value) external;
}
