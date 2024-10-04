// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;


import { BaseFuzzStaking } from "../../fuzz_tests/BaseFuzzStaking.f.sol";
import { StakingTypes } from "../../../../contracts/libraries/DataTypes.sol";
import {console2} from "forge-std/console2.sol";

contract WalletShareTest is BaseFuzzStaking{


    /// @dev A function invoked before each test case is run.
    function setUp() public virtual override {
        BaseFuzzStaking.setUp();

    }

    function test_FoundationGetsInitialShares() public {
        uint256 initialSharesAmount = 100_000 * 1e18;
        (uint256 foundationWalletShares,,) = pushStaking.walletShareInfo(actor.admin);
        uint256 actualTotalShares = pushStaking.WALLET_TOTAL_SHARES();
        assertEq(initialSharesAmount, foundationWalletShares);
        assertEq(foundationWalletShares, actualTotalShares);
    }

    function test_WalletGets_20PercentAllocation() public {
        (uint256 bobWalletSharesBefore,,) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        StakingTypes.Percentage memory percentAllocation = StakingTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });

        changePrank(actor.admin);
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation);
        uint256 expectedAllocationShares = 25_000 * 1e18;
        (uint256 bobWalletSharesAfter,,) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        uint256 actualTotalShares = pushStaking.WALLET_TOTAL_SHARES();

        assertEq(bobWalletSharesBefore, 0);
        assertEq(bobWalletSharesAfter, expectedAllocationShares);
        assertEq(actualTotalShares, 125_000 * 1e18);
        console2.log(bobWalletSharesAfter * 100, actualTotalShares);

        uint percentage = (bobWalletSharesAfter * 100)/actualTotalShares;
        assertEq(percentage, percentAllocation.percentageNumber);
    }

    function test_whenWallet_TriesTo_ClaimRewards()external {
        test_WalletGets_20PercentAllocation();
        changePrank(actor.bob_channel_owner);
        pushStaking.claimShareRewards();
    }


    function test_WalletGets_50PercentAllocation() public {
        // bob wallet gets allocated 20% shares i.e. 25k
        test_WalletGets_20PercentAllocation();

        (uint256 aliceWalletSharesBefore,,) = pushStaking.walletShareInfo(actor.alice_channel_owner);
        StakingTypes.Percentage memory percentAllocation = StakingTypes.Percentage({ percentageNumber: 50, decimalPlaces: 0 });

        changePrank(actor.admin);
        pushStaking.addWalletShare(actor.alice_channel_owner, percentAllocation);
        uint256 expectedAllocationShares = 125_000 * 1e18;
        (uint256 bobWalletSharesAfter,,) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        (uint256 aliceWalletSharesAfter,,) = pushStaking.walletShareInfo(actor.alice_channel_owner);
        (uint256 foundationWalletSharesAfter,,) = pushStaking.walletShareInfo(actor.admin);
        uint256 actualTotalShares = pushStaking.WALLET_TOTAL_SHARES();

        assertEq(aliceWalletSharesBefore, 0);
        assertEq(bobWalletSharesAfter, 25_000 * 1e18);
        assertEq(aliceWalletSharesAfter, expectedAllocationShares);
        assertEq(foundationWalletSharesAfter, 100_000 * 1e18);
        assertEq(actualTotalShares, 250_000 * 1e18);
        uint percentage = (aliceWalletSharesAfter * 100)/actualTotalShares;
        assertEq(percentage, percentAllocation.percentageNumber);
    }

    // removes wallet allocation and assign shares to the foundation
    function test_RemovalWalletM2() public {
        // actor.bob_channel_owner has 20% allocation (25k shares), actor.alice_channel_owner has 50% (125k) & foundation (100k)
        test_WalletGets_50PercentAllocation();

        uint256 totalSharesBefore = pushStaking.WALLET_TOTAL_SHARES();
        (uint256 bobWalletSharesBefore,,) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        (uint256 aliceWalletSharesBefore,,) = pushStaking.walletShareInfo(actor.alice_channel_owner);
        (uint256 foundationWalletSharesBefore,,) = pushStaking.walletShareInfo(actor.admin);

        changePrank(actor.admin);
        pushStaking.removeWalletShare(actor.bob_channel_owner);

        uint256 totalSharesAfter = pushStaking.WALLET_TOTAL_SHARES();
        (uint256 bobWalletSharesAfter,,) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        (uint256 aliceWalletSharesAfter,,) = pushStaking.walletShareInfo(actor.alice_channel_owner);
        (uint256 foundationWalletSharesAfter,,) = pushStaking.walletShareInfo(actor.admin);

        assertEq(bobWalletSharesAfter, 0,"bob wallet share");
        assertEq(aliceWalletSharesAfter, aliceWalletSharesBefore,"akice wallet share");
        assertEq(foundationWalletSharesAfter, foundationWalletSharesBefore + bobWalletSharesBefore,"foundation wallet share");
        assertEq(totalSharesAfter, totalSharesBefore,"total wallet share");
    }
    // testing add wallet after removal with method m2 (assign shares to foundation)
    function test_AddWallet_AfterRemoval_M2() public {
        test_RemovalWalletM2();
        (uint256 charlieWalletSharesBefore,,) = pushStaking.walletShareInfo(actor.charlie_channel_owner);

        StakingTypes.Percentage memory percentAllocation = StakingTypes.Percentage({ percentageNumber: 50, decimalPlaces: 0 });

        changePrank(actor.admin);
        pushStaking.addWalletShare(actor.charlie_channel_owner, percentAllocation);
        uint256 expectedAllocationShares = 250_000 * 1e18;
        (uint256 charlieWalletSharesAfter,,) = pushStaking.walletShareInfo(actor.charlie_channel_owner);
        uint256 totalSharesAfter = pushStaking.WALLET_TOTAL_SHARES();

        assertEq(charlieWalletSharesBefore, 0);
        assertEq(charlieWalletSharesAfter, expectedAllocationShares);
        assertEq(totalSharesAfter, 500_000 * 1e18);
    }

    // assign wallet 0.001% shares
    function test_WalletGets_NegligiblePercentAllocation() public {
        (uint256 bobWalletSharesBefore,,) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        StakingTypes.Percentage memory percentAllocation = StakingTypes.Percentage({ percentageNumber: 1, decimalPlaces: 3 });

        uint256 expectedAllocationShares = pushStaking.getSharesAmount(pushStaking.WALLET_TOTAL_SHARES(),percentAllocation);
        changePrank(actor.admin);
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation);
        (uint256 bobWalletSharesAfter,,) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        uint256 actualTotalShares = pushStaking.WALLET_TOTAL_SHARES();

        assertEq(bobWalletSharesBefore, 0);
        assertEq(bobWalletSharesAfter, expectedAllocationShares);
        assertEq(actualTotalShares, 100_000 * 1e18 + expectedAllocationShares);
    }

    // assign wallet 0.0001% shares
    function test_WalletGets_NegligiblePercentAllocation2() public {
        (uint256 bobWalletSharesBefore,,) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        StakingTypes.Percentage memory percentAllocation = StakingTypes.Percentage({ percentageNumber: 1, decimalPlaces: 4 });

        uint256 expectedAllocationShares = pushStaking.getSharesAmount(pushStaking.WALLET_TOTAL_SHARES(),percentAllocation);
        changePrank(actor.admin);
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation);
        (uint256 bobWalletSharesAfter,,) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        uint256 actualTotalShares = pushStaking.WALLET_TOTAL_SHARES();
         console2.log(expectedAllocationShares,bobWalletSharesAfter,actualTotalShares);
        assertEq(bobWalletSharesBefore, 0);
        assertEq(bobWalletSharesAfter, expectedAllocationShares);
        console2.log(bobWalletSharesBefore,bobWalletSharesAfter);
        assertEq(actualTotalShares, 100_000 * 1e18 + expectedAllocationShares);
    }

    function test_IncreaseWalletShare() public {
        // assigns actor.bob_channel_owner 20% allocation
        test_WalletGets_20PercentAllocation();

        // let's increase actor.bob_channel_owner allocation to 50%
        uint256 totalSharesBefore = pushStaking.WALLET_TOTAL_SHARES();
        (uint256 bobWalletSharesBefore,,) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        (uint256 foundationWalletSharesBefore,,) = pushStaking.walletShareInfo(actor.admin);

        StakingTypes.Percentage memory percentAllocation = StakingTypes.Percentage({ percentageNumber: 50, decimalPlaces: 0 });

        changePrank(actor.admin);
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation);
        uint256 expectedAllocationShares = 100_000* 1e18;
        uint256 totalSharesAfter = pushStaking.WALLET_TOTAL_SHARES();
        (uint256 bobWalletSharesAfter,,) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        (uint256 foundationWalletSharesAfter,,) = pushStaking.walletShareInfo(actor.admin);

        assertEq(bobWalletSharesBefore, 25_000* 1e18,"bob wallet share");
        assertEq(totalSharesBefore, 125_000* 1e18,"total wallet share");
        assertEq(foundationWalletSharesBefore, 100_000* 1e18,"foundation wallet share");
        assertEq(bobWalletSharesAfter, expectedAllocationShares,"bob wallet share after");
        assertEq(totalSharesAfter, 200_000* 1e18,"total wallet share after");
        assertEq(foundationWalletSharesAfter, 100_000* 1e18,"foundation wallet share after");
    }

    function test_RevertWhen_DecreaseWalletShare_UsingAdd() public {
        // assigns actor.bob_channel_owner 20% allocation
        test_WalletGets_20PercentAllocation();

        // let's increase actor.bob_channel_owner allocation to 50%
        uint256 totalSharesBefore = pushStaking.WALLET_TOTAL_SHARES();
        (uint256 bobWalletSharesBefore,,) = pushStaking.walletShareInfo(actor.bob_channel_owner);

        StakingTypes.Percentage memory percentAllocation = StakingTypes.Percentage({ percentageNumber: 10, decimalPlaces: 0 });

        changePrank(actor.admin);
        vm.expectRevert();
        pushStaking.addWalletShare(actor.bob_channel_owner, percentAllocation);
        (uint256 bobWalletSharesAfter,,) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        uint256 actualTotalShares = pushStaking.WALLET_TOTAL_SHARES();

        assertEq(bobWalletSharesBefore, bobWalletSharesAfter);
        assertEq(actualTotalShares, totalSharesBefore);

        uint percentage = (bobWalletSharesAfter * 100)/actualTotalShares;
        assertEq(percentage, 20);
    }

    function test_DecreaseWalletShare() public {
        // assigns actor.bob_channel_owner 20% allocation
        test_WalletGets_20PercentAllocation();

        // let's decrease actor.bob_channel_owner allocation to 10%
        uint256 totalSharesBefore = pushStaking.WALLET_TOTAL_SHARES();
        (uint256 bobWalletSharesBefore,,) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        (uint256 foundationWalletSharesBefore,,) = pushStaking.walletShareInfo(actor.admin);

        StakingTypes.Percentage memory percentAllocation = StakingTypes.Percentage({ percentageNumber: 10, decimalPlaces: 0 });

        uint256 expectedAllocationShares = pushStaking.getSharesAmount(pushStaking.WALLET_TOTAL_SHARES(),percentAllocation);
        changePrank(actor.admin);
        pushStaking.decreaseWalletShare(actor.bob_channel_owner, percentAllocation);
        uint256 totalSharesAfter = pushStaking.WALLET_TOTAL_SHARES();
        (uint256 bobWalletSharesAfter,,) = pushStaking.walletShareInfo(actor.bob_channel_owner);
        (uint256 foundationWalletSharesAfter,,) = pushStaking.walletShareInfo(actor.admin);

        assertEq(bobWalletSharesBefore, 25_000 * 1e18);
        assertEq(totalSharesBefore, 125_000 * 1e18);
        assertEq(foundationWalletSharesBefore, 100_000 * 1e18);
        assertEq(bobWalletSharesAfter, expectedAllocationShares);
        assertEq(totalSharesAfter, 125_000 * 1e18 + expectedAllocationShares);
        assertEq(foundationWalletSharesAfter, 125_000 * 1e18 );
    }

    // FUZZ TESTS
    function testFuzz_AddShares(address _walletAddress, StakingTypes.Percentage memory _percentage) public {
        _percentage.percentageNumber = bound(_percentage.percentageNumber,0,100);
        _percentage.decimalPlaces = bound(_percentage.decimalPlaces,0,10);
        // percentage must be less than 100
        vm.assume(_percentage.percentageNumber / 10 ** _percentage.decimalPlaces < 100);
        changePrank(actor.admin);
        pushStaking.addWalletShare(_walletAddress, _percentage);
    }

    function testFuzz_RemoveShares(address _walletAddress, StakingTypes.Percentage memory _percentage) public {
         _percentage.percentageNumber = bound(_percentage.percentageNumber,0,100);
        vm.assume(_percentage.decimalPlaces < 10);
        // percentage must be less than 100
        vm.assume(_percentage.percentageNumber / 10 ** _percentage.decimalPlaces < 100);
        testFuzz_AddShares(_walletAddress, _percentage);

        changePrank(actor.admin);
        pushStaking.removeWalletShare(_walletAddress);
        (uint256 foundationWalletShares,,) = pushStaking.walletShareInfo(actor.admin);

        assertEq(pushStaking.WALLET_TOTAL_SHARES(), foundationWalletShares);
    }

    function test_MaxDecimalAmount () public  {
        // fixed at most 10 decimal places
        // percentage = 10.1111111111
        StakingTypes.Percentage memory _percentage = StakingTypes.Percentage({
            percentageNumber: 101111111111,
            decimalPlaces: 10
        });

        for (uint256 i=1; i<50; i++) {
            uint256 shares = pushStaking.getSharesAmount({
                _totalShares: 10 ** i,
                _percentage: _percentage
            });
            console2.log("totalShares = ", i);
            console2.log(shares/1e18);
            console2.log("");
        }
    }
}