pragma solidity >=0.6.0 <0.7.0;

interface IPUSH {
    function born() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function resetHolderWeight(address holder) external;
    function holderWeight(address) external view returns (uint256);
    function returnHolderUnits(address account, uint256 atBlock) external view returns (uint256);
}
