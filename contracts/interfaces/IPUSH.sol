pragma solidity ^0.8.20;

interface IPUSH {
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function symbol() external view returns (string memory);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address dst, uint256 rawAmount) external returns (bool);
    function approve(address spender, uint256 rawAmount) external returns (bool);
    function allowance(address account, address spender) external view returns (uint256);
    function transferFrom(address src, address dst, uint256 rawAmount) external returns (bool);
    
    // Push-Token Specific Functions
    function born() external view returns (uint256);
    function resetHolderWeight(address holder) external;
    function holderWeight(address) external view returns (uint256);
    function returnHolderUnits(address account, uint256 atBlock) external view returns (uint256);

    //Voting and Governance Related Function Signatures
    function delegate(address delegatee) external;
}
