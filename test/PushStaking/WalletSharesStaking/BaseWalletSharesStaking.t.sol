pragma solidity ^0.8.20;
pragma experimental ABIEncoderV2;

import { BasePushStaking } from "../BasePushStaking.t.sol";

contract BaseWalletSharesStaking is BasePushStaking {

    function setUp() public virtual override {
        BasePushStaking.setUp();
    }

    modifier validateShareInvariants () {
        uint256 walletSharesBeforeExecution = pushStaking.WALLET_TOTAL_SHARES();
        _;
        _validateWalletSharesSum();
        _validateEpochShares();
        _verifyTotalSharesConsistency(walletSharesBeforeExecution);
    }

    function _validateWalletSharesSum() internal {
        uint256 walletTotalShares = pushStaking.WALLET_TOTAL_SHARES();
        (uint256 foundationWalletShares,,) = pushStaking.walletShareInfo(actor.admin);
        (uint256 bobWalletShares,,) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        (uint256 aliceWalletShares,,) = pushStaking.walletShareInfo(actor.alice_channel_owner);
        (uint256 charlieWalletShares,,) = pushStaking.walletShareInfo(actor.charlie_channel_owner);
        (uint256 tonyWalletShares,,) = pushStaking.walletShareInfo(actor.tony_channel_owner);

        uint256 totalSharesSum = foundationWalletShares + bobWalletShares + aliceWalletShares + charlieWalletShares + tonyWalletShares;
        assertEq(walletTotalShares, totalSharesSum);
    }

    function _validateEpochShares() internal {
        uint256 walletTotalShares = pushStaking.WALLET_TOTAL_SHARES();
        for (uint256 i=genesisEpoch; i<=getCurrentEpoch(); ) {
            assertLe(pushStaking.epochToTotalShares(i), walletTotalShares);
            unchecked {
                i++;
            }
        }
    }

    function _verifyTotalSharesConsistency(uint256 _walletSharesBeforeExecution) internal {
        uint256 walletTotalSharesAfter = pushStaking.WALLET_TOTAL_SHARES();
        assertEq(_walletSharesBeforeExecution, walletTotalSharesAfter);
    }
}
