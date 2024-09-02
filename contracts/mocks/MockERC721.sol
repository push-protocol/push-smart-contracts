// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    uint256 _id;

    constructor(address _initial) ERC721("MockERC721", "MCK") {
        _safeMint(_initial, _id);
        _id++;
    }

    function mint() external {
        _mint(msg.sender, _id);
        _id++;
    }
}
