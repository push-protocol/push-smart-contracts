import "@openzeppelin/contracts/cryptography/ECDSA.sol";

import "hardhat/console.sol";
pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;


// SPDX-License-Identifier: MIT
contract SignatureVerifier{
    using ECDSA for bytes32;

    address public owner;
    constructor () public {
        owner = msg.sender;
    }

    bytes4 private constant ERC1271_IS_VALID_SIGNATURE = bytes4(
        keccak256("isValidSignature(bytes32,bytes)")
    );

    function supportsStaticCall(bytes4 _methodId) external pure  returns (bool _isSupported) {
        return _methodId == ERC1271_IS_VALID_SIGNATURE;
    }
    
    function isValidSignature(bytes32 hash, bytes memory signature) public view returns (bytes4) {
        // bytes32 signedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
        address recovered_address = hash.recover(signature);

        require(
            recovered_address == owner,
            "Contract verifier: Invalid signer"
        );
        return ERC1271_IS_VALID_SIGNATURE;
    }
    
   

}