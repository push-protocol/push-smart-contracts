// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { BaseTest } from "../../../BaseTest.t.sol";

contract Approve_Test is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
    function getTypedDataHash(
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline
    )
        public
        view
        returns (bytes32)
    {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                pushNttToken.DOMAIN_TYPEHASH(),
                keccak256(bytes(pushNttToken.name())),
                block.chainid,
                address(pushNttToken)
            )
        );
        bytes32 structHash = keccak256(abi.encode(pushNttToken.PERMIT_TYPEHASH(), owner, spender, amount, 0, deadline));
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    function test_PermitFuzz(address spender, uint256 rawAmount, uint256 deadline) public {
        vm.assume(deadline > block.timestamp);

        uint256 amount = rawAmount;
        if (rawAmount == type(uint256).max) {
            amount = type(uint96).max;
        } else {
            if (rawAmount >= type(uint96).max) {
                rawAmount = type(uint96).max; // permit fn reverts in this case (when, 2^96 <= rawAmount < (2^256 - 1))
                amount = rawAmount;
            } else {
                amount = uint96(rawAmount);
            }
        }

        uint256 ownerPrivateKey = 0xA11CE;
        address owner = vm.addr(ownerPrivateKey);
        uint256 allowanceBefore = pushNttToken.allowance(owner, spender);

        bytes32 digest = getTypedDataHash(owner, spender, rawAmount, deadline);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        pushNttToken.permit(owner, spender, rawAmount, deadline, v, r, s);

        uint256 allowanceAfter = pushNttToken.allowance(owner, spender);
        assertEq(allowanceAfter, allowanceBefore + amount);
    }
}
