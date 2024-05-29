// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;


import { BasePushCoreTest } from "../BasePushCoreTest.t.sol";
import { CoreTypes } from "../../../../contracts/libraries/DataTypes.sol";
import {console2} from "forge-std/console2.sol";

contract WalletShareTest is BasePushCoreTest{


    /// @dev A function invoked before each test case is run.
    function setUp() public virtual override {
        BasePushCoreTest.setUp();

    }


    function test_FoundationGetsInitialShares() public {
        uint256 initialSharesAmount = 100_000 * 1e18;
        uint256 foundationWalletShares = coreProxy.WalletToShares(actor.admin);
        uint256 actualTotalShares = coreProxy.WALLET_TOTAL_SHARES();
        assertEq(initialSharesAmount, foundationWalletShares);
        assertEq(foundationWalletShares, actualTotalShares);
    }

    function test_WalletGets_20PercentAllocation() public {
        uint256 bobWalletSharesBefore = coreProxy.WalletToShares(actor.bob_channel_owner);
        CoreTypes.Percentage memory percentAllocation = CoreTypes.Percentage({ percentageNumber: 20, decimalPlaces: 0 });

        vm.prank(actor.admin);
        coreProxy.addWalletShare(actor.bob_channel_owner, percentAllocation);
        uint256 expectedAllocationShares = 25_000 * 1e18;
        uint256 bobWalletSharesAfter = coreProxy.WalletToShares(actor.bob_channel_owner);
        uint256 actualTotalShares = coreProxy.WALLET_TOTAL_SHARES();

        assertEq(bobWalletSharesBefore, 0);
        assertEq(bobWalletSharesAfter, expectedAllocationShares);
        assertEq(actualTotalShares, 125_000 * 1e18);

        uint percentage = (bobWalletSharesAfter * 100)/actualTotalShares;
        assertEq(percentage, percentAllocation.percentageNumber);
    }

    function test_WalletGets_50PercentAllocation() public {
        // bob wallet gets allocated 20% shares i.e. 25k
        test_WalletGets_20PercentAllocation();

        uint256 aliceWalletSharesBefore = coreProxy.WalletToShares(actor.alice_channel_owner);
        CoreTypes.Percentage memory percentAllocation = CoreTypes.Percentage({ percentageNumber: 50, decimalPlaces: 0 });

        vm.prank(actor.admin);
        coreProxy.addWalletShare(actor.alice_channel_owner, percentAllocation);
        uint256 expectedAllocationShares = 125_000 * 1e18;
        uint256 bobWalletSharesAfter = coreProxy.WalletToShares(actor.bob_channel_owner);
        uint256 aliceWalletSharesAfter = coreProxy.WalletToShares(actor.alice_channel_owner);
        uint256 foundationWalletSharesAfter = coreProxy.WalletToShares(actor.admin);
        uint256 actualTotalShares = coreProxy.WALLET_TOTAL_SHARES();

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

        uint256 totalSharesBefore = coreProxy.WALLET_TOTAL_SHARES();
        uint256 bobWalletSharesBefore = coreProxy.WalletToShares(actor.bob_channel_owner);
        uint256 aliceWalletSharesBefore = coreProxy.WalletToShares(actor.alice_channel_owner);
        uint256 foundationWalletSharesBefore = coreProxy.WalletToShares(actor.admin);

        vm.prank(actor.admin);
        coreProxy.removeWalletShare(actor.bob_channel_owner);

        uint256 totalSharesAfter = coreProxy.WALLET_TOTAL_SHARES();
        uint256 bobWalletSharesAfter = coreProxy.WalletToShares(actor.bob_channel_owner);
        uint256 aliceWalletSharesAfter = coreProxy.WalletToShares(actor.alice_channel_owner);
        uint256 foundationWalletSharesAfter = coreProxy.WalletToShares(actor.admin);

        assertEq(bobWalletSharesAfter, 0);
        assertEq(aliceWalletSharesAfter, aliceWalletSharesBefore);
        assertEq(foundationWalletSharesAfter, foundationWalletSharesBefore + bobWalletSharesBefore);
        assertEq(totalSharesAfter, totalSharesBefore);
    }
    // testing add wallet after removal with method m2 (assign shares to foundation)
    function test_AddWallet_AfterRemoval_M2() public {
        test_RemovalWalletM2();
        uint256 rabbyWalletSharesBefore = coreProxy.WalletToShares(actor.charlie_channel_owner);

        CoreTypes.Percentage memory percentAllocation = CoreTypes.Percentage({ percentageNumber: 50, decimalPlaces: 0 });

        vm.prank(actor.admin);
        coreProxy.addWalletShare(actor.charlie_channel_owner, percentAllocation);
        uint256 expectedAllocationShares = 250_000 * 1e18;
        uint256 rabbyWalletSharesAfter = coreProxy.WalletToShares(actor.charlie_channel_owner);
        uint256 totalSharesAfter = coreProxy.WALLET_TOTAL_SHARES();

        assertEq(rabbyWalletSharesBefore, 0);
        assertEq(rabbyWalletSharesAfter, expectedAllocationShares);
        assertEq(totalSharesAfter, 500_000 * 1e18);
    }

    // assign wallet 0.001% shares
    function test_WalletGets_NegligiblePercentAllocation() public {
        uint256 bobWalletSharesBefore = coreProxy.WalletToShares(actor.bob_channel_owner);
        CoreTypes.Percentage memory percentAllocation = CoreTypes.Percentage({ percentageNumber: 1, decimalPlaces: 3 });

        uint256 expectedAllocationShares = coreProxy.getSharesAmount(coreProxy.WALLET_TOTAL_SHARES(),percentAllocation);
        vm.prank(actor.admin);
        coreProxy.addWalletShare(actor.bob_channel_owner, percentAllocation);
        uint256 bobWalletSharesAfter = coreProxy.WalletToShares(actor.bob_channel_owner);
        uint256 actualTotalShares = coreProxy.WALLET_TOTAL_SHARES();

        assertEq(bobWalletSharesBefore, 0);
        assertEq(bobWalletSharesAfter, expectedAllocationShares);
        assertEq(actualTotalShares, 100_000 * 1e18 + expectedAllocationShares);
    }

    // assign wallet 0.0001% shares
    function test_WalletGets_NegligiblePercentAllocation2() public {
        uint256 bobWalletSharesBefore = coreProxy.WalletToShares(actor.bob_channel_owner);
        CoreTypes.Percentage memory percentAllocation = CoreTypes.Percentage({ percentageNumber: 1, decimalPlaces: 4 });

        uint256 expectedAllocationShares = coreProxy.getSharesAmount(coreProxy.WALLET_TOTAL_SHARES(),percentAllocation);
        vm.prank(actor.admin);
        coreProxy.addWalletShare(actor.bob_channel_owner, percentAllocation);
        uint256 bobWalletSharesAfter = coreProxy.WalletToShares(actor.bob_channel_owner);
        uint256 actualTotalShares = coreProxy.WALLET_TOTAL_SHARES();
         console2.log(expectedAllocationShares,bobWalletSharesAfter,actualTotalShares);
        assertEq(bobWalletSharesBefore, 0);
        assertEq(bobWalletSharesAfter, expectedAllocationShares);
        assertEq(actualTotalShares, 100_000 * 1e18 + expectedAllocationShares);
    }

    function test_IncreaseWalletShare() public {
        // assigns actor.bob_channel_owner 20% allocation
        test_WalletGets_20PercentAllocation();

        // let's increase actor.bob_channel_owner allocation to 50%
        uint256 totalSharesBefore = coreProxy.WALLET_TOTAL_SHARES();
        uint256 bobWalletSharesBefore = coreProxy.WalletToShares(actor.bob_channel_owner);
        uint256 foundationWalletSharesBefore = coreProxy.WalletToShares(actor.admin);

        CoreTypes.Percentage memory percentAllocation = CoreTypes.Percentage({ percentageNumber: 50, decimalPlaces: 0 });

        vm.prank(actor.admin);
        coreProxy.addWalletShare(actor.bob_channel_owner, percentAllocation);
        uint256 expectedAllocationShares = 100_000* 1e18;
        uint256 totalSharesAfter = coreProxy.WALLET_TOTAL_SHARES();
        uint256 bobWalletSharesAfter = coreProxy.WalletToShares(actor.bob_channel_owner);
        uint256 foundationWalletSharesAfter = coreProxy.WalletToShares(actor.admin);

        assertEq(bobWalletSharesBefore, 25_000* 1e18);
        assertEq(totalSharesBefore, 125_000* 1e18);
        assertEq(foundationWalletSharesBefore, 100_000* 1e18);
        assertEq(bobWalletSharesAfter, expectedAllocationShares);
        assertEq(totalSharesAfter, 200_000* 1e18);
        assertEq(foundationWalletSharesAfter, 100_000* 1e18);
    }

    function test_RevertWhen_DecreaseWalletShare_UsingAdd() public {
        // assigns actor.bob_channel_owner 20% allocation
        test_WalletGets_20PercentAllocation();

        // let's increase actor.bob_channel_owner allocation to 50%
        uint256 totalSharesBefore = coreProxy.WALLET_TOTAL_SHARES();
        uint256 bobWalletSharesBefore = coreProxy.WalletToShares(actor.bob_channel_owner);

        CoreTypes.Percentage memory percentAllocation = CoreTypes.Percentage({ percentageNumber: 10, decimalPlaces: 0 });

        vm.prank(actor.admin);
        vm.expectRevert();
        coreProxy.addWalletShare(actor.bob_channel_owner, percentAllocation);
        uint256 bobWalletSharesAfter = coreProxy.WalletToShares(actor.bob_channel_owner);
        uint256 actualTotalShares = coreProxy.WALLET_TOTAL_SHARES();

        assertEq(bobWalletSharesBefore, bobWalletSharesAfter);
        assertEq(actualTotalShares, totalSharesBefore);

        uint percentage = (bobWalletSharesAfter * 100)/actualTotalShares;
        assertEq(percentage, 20);
    }

    function test_DecreaseWalletShare() public {
        // assigns actor.bob_channel_owner 20% allocation
        test_WalletGets_20PercentAllocation();

        // let's decrease actor.bob_channel_owner allocation to 10%
        uint256 totalSharesBefore = coreProxy.WALLET_TOTAL_SHARES();
        uint256 bobWalletSharesBefore = coreProxy.WalletToShares(actor.bob_channel_owner);
        uint256 foundationWalletSharesBefore = coreProxy.WalletToShares(actor.admin);

        CoreTypes.Percentage memory percentAllocation = CoreTypes.Percentage({ percentageNumber: 10, decimalPlaces: 0 });

        uint256 expectedAllocationShares = coreProxy.getSharesAmount(coreProxy.WALLET_TOTAL_SHARES(),percentAllocation);
        vm.prank(actor.admin);
        coreProxy.decreaseWalletShare(actor.bob_channel_owner, percentAllocation);
        uint256 totalSharesAfter = coreProxy.WALLET_TOTAL_SHARES();
        uint256 bobWalletSharesAfter = coreProxy.WalletToShares(actor.bob_channel_owner);
        uint256 foundationWalletSharesAfter = coreProxy.WalletToShares(actor.admin);

        assertEq(bobWalletSharesBefore, 25_000 * 1e18);
        assertEq(totalSharesBefore, 125_000 * 1e18);
        assertEq(foundationWalletSharesBefore, 100_000 * 1e18);
        assertEq(bobWalletSharesAfter, expectedAllocationShares);
        assertEq(totalSharesAfter, 125_000 * 1e18 + expectedAllocationShares);
        assertEq(foundationWalletSharesAfter, 125_000 * 1e18 );
    }

    // FUZZ TESTS
    function testFuzz_AddShares(address _walletAddress, CoreTypes.Percentage memory _percentage) public {
        _percentage.percentageNumber = bound(_percentage.percentageNumber,0,100);
        _percentage.decimalPlaces = bound(_percentage.decimalPlaces,0,10);
        // percentage must be less than 100
        vm.assume(_percentage.percentageNumber / 10 ** _percentage.decimalPlaces < 100);
        vm.prank(actor.admin);
        coreProxy.addWalletShare(_walletAddress, _percentage);
    }

    function testFuzz_RemoveShares(address _walletAddress, CoreTypes.Percentage memory _percentage) public {
         _percentage.percentageNumber = bound(_percentage.percentageNumber,0,100);
        vm.assume(_percentage.decimalPlaces < 10);
        // percentage must be less than 100
        vm.assume(_percentage.percentageNumber / 10 ** _percentage.decimalPlaces < 100);
        testFuzz_AddShares(_walletAddress, _percentage);

        vm.prank(actor.admin);
        coreProxy.removeWalletShare(_walletAddress);

        assertEq(coreProxy.WALLET_TOTAL_SHARES(), coreProxy.WalletToShares(actor.admin));
    }

    // function testFuzz_IncreaseShares(address _walletAddress, CoreTypes.Percentage calldata _percentage) public {
    //     vm.assume(_percentage.percentageNumber > 0);
    //     vm.assume(_percentage.decimalPlaces < 10);
    //     // percentage must be less than 100
    //     vm.assume(_percentage.percentageNumber / 10 ** _percentage.decimalPlaces < 100);
    //     vm.assume((_percentage.percentageNumber + 1) / 10 ** (_percentage.decimalPlaces) < 100);

    //     CoreTypes.Percentage memory _oldPercentage = CoreTypes.Percentage({
    //         percentageNumber: _percentage.percentageNumber - 1,
    //         decimalPlaces: _percentage.decimalPlaces
    //     });
    //     testFuzz_AddShares(_walletAddress, _oldPercentage);

    //     CoreTypes.Percentage memory _newPercentage = CoreTypes.Percentage({
    //         percentageNumber: _percentage.percentageNumber + 1,
    //         decimalPlaces: _percentage.decimalPlaces
    //     });

    //     vm.prank(actor.admin);
    //     coreProxy.increaseWalletShares(_walletAddress, _newPercentage);
    // }

    // function testFuzz_DecreaseShares(address _walletAddress, CoreTypes.Percentage calldata _percentage) public {
    //     vm.assume(_percentage.percentageNumber > 0);
    //     vm.assume(_percentage.decimalPlaces < 10);
    //     // percentage must be less than 100
    //     vm.assume(_percentage.percentageNumber / 10 ** _percentage.decimalPlaces < 100);
    //     vm.assume((_percentage.percentageNumber - 1) / 10 ** (_percentage.decimalPlaces) < 100);
    //     testFuzz_AddShares(_walletAddress, _percentage);

    //     CoreTypes.Percentage memory _newPercentage = CoreTypes.Percentage({
    //         percentageNumber: _percentage.percentageNumber - 1,
    //         decimalPlaces: _percentage.decimalPlaces
    //     });

    //     vm.prank(actor.admin);
    //     coreProxy.decreaseWalletSharesM2(_walletAddress, _newPercentage);
    // }

    function test_MaxDecimalAmount () public view {
        // fixed at most 10 decimal places
        // percentage = 10.1111111111
        CoreTypes.Percentage memory _percentage = CoreTypes.Percentage({
            percentageNumber: 101111111111,
            decimalPlaces: 10
        });

        for (uint256 i=1; i<50; i++) {
            uint256 shares = coreProxy.getSharesAmount({
                _totalShares: 10 ** i,
                _percentage: _percentage
            });
            console2.log("totalShares = ", i);
            console2.log(shares/1e18);
            console2.log("");
        }
    }
}
