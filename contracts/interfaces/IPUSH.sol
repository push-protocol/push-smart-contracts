pragma solidity ^0.8.20;

interface IPUSH {
    function born() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function resetHolderWeight(address holder) external;
    function holderWeight(address) external view returns (uint256);
    function approve(address spender, uint256 rawAmount) external returns (bool);
    function returnHolderUnits(address account, uint256 atBlock) external view returns (uint256);

    //Voting and Governance Related Function Signatures
    function delegate(address delegatee) external;

}
