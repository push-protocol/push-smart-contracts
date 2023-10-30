pragma solidity ^0.8.20;

interface IADai {
    function redeem(uint256 _amount) external;
    function balanceOf(address _user) external view returns (uint256);
    function principalBalanceOf(address _user) external view returns (uint256);
    function getInterestRedirectionAddress(address _user) external view returns (address);
}
