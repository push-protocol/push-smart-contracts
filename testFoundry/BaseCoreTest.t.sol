pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "contracts/token/EPNS.sol";
import "contracts/PushCore/PushCoreV2.sol";
import "contracts/PushCore/PushCoreStorageV1_5.sol";
import "contracts/PushCore/PushCoreStorageV2.sol";
//import "contracts/PushComm/PushCommV2.sol";
import "contracts/interfaces/IUniswapV2Router.sol";

// import "forge-std/Console.sol";

 // For Message Type


contract PushTest is Test {
    /* ***************
        Main Push Contracts and Tokens
     *************** */
     enum ChannelType {
        ProtocolNonInterest,
        ProtocolPromotion,
        InterestBearingOpen,
        InterestBearingMutual,
        TimeBound,
        TokenGaited
    }
    enum ChannelAction {
        ChannelRemoved,
        ChannelAdded,
        ChannelUpdated
    }
    EPNS public pushToken;
    PushCoreV2 public core;
    //PushCommV2 public comm;
    IUniswapV2Router public uniV2Router;

    /* ***************
        Main Actors in Test
     *************** */
    address admin = makeAddr("admin");
    address tony = makeAddr("tony");
    address bob = makeAddr("bob");
    address alice = makeAddr("alice");
    address charlie = makeAddr("charlie");

    address[] users = [bob, alice, charlie, tony];

    /* ***************
       Initializing Set-Up for Push Contracts
     *************** */

    function setUp() external {
        
        pushToken = new EPNS(admin);
        core = new PushCoreV2();
        //comm = new PushCommV2();
        uniV2Router = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        // Initialize Core Contract
        core.initialize(
            admin,
            address(pushToken),
            address(0), // WETH Address
            address(uniV2Router), // Uniswap_Router
            address(0), // Lending_Pool_Aave
            address(0), // Dai_Address
            address(0), // aDai address
            0
        );
        // Transfer 100K Push To all actors

        uint _amount = 100000 * 1e18;

        
        for (uint i = 0; i < users.length; i++) {
            vm.prank(admin);
            pushToken.transfer(users[i], _amount);
        }
        for (uint i; i < users.length; ++i) {
            approveTokens(users[i], address(core), _amount);
        }

        // Set Approval for Admin and Holder Delegation
        vm.startPrank(admin);
        core.setMinPoolContribution(1 ether); // as per the change in v1.5.0
        pushToken.approve(address(core), 100000000 * 1e18);
        pushToken.setHolderDelegation(address(core), true);
    
        vm.stopPrank();
    }

      /* ***************
       Basic tests in Core Contract
      *************** */

    // 1. Admin should be accurate
    function testCoreAdmin() public {
        address coreAdmin = core.pushChannelAdmin();
        assertEq(coreAdmin, admin);
    }
    // 2. Fee-Related States should be accurate
    function testFeeRelatedStates() public {
        uint256 feeAmount = core.FEE_AMOUNT();
        uint256 minChannelFees = core.ADD_CHANNEL_MIN_FEES();
        uint256 minContribution = core.MIN_POOL_CONTRIBUTION();
        
        assertEq(feeAmount, 10 ether);
        assertEq(minChannelFees, 50 ether);
        assertEq(minContribution, 1 ether);
    }
    // 3. Only Owner functions are protected
    function testFailOwnerAccess() public {
        vm.prank(bob);
        core.pauseContract();
    }

    /* ***************
       Core Contract Helper Functions
    *************** */
     
    function roll(uint num) internal {
        vm.roll(num);
    }

    function approveTokens(address from, address to, uint amount) internal {
        vm.startPrank(from);
        pushToken.approve(to, amount);
        pushToken.setHolderDelegation(to, true);
        vm.stopPrank();
    }

    // Staking-Related Functions
    function stake(address signer, uint256 amount) internal {
        vm.prank(signer);
        core.stake(amount * 1e18);
    }

    function harvest(address signer) internal {
        vm.prank(signer);
        core.harvestAll();
    }

    function harvestPaginated(address signer, uint _till) internal {
        vm.prank(signer);
        core.harvestPaginated(_till);
    }

    function addPool(uint256 amount) internal {
        vm.prank(admin);
        core.addPoolFees(amount);
    }

    function unstake(address signer) internal {
        vm.prank(signer);
        core.unstake();
    }

    function daoHarvest(uint _epoch) internal {
        vm.prank(admin);
        core.daoHarvestPaginated(_epoch);
    }

}