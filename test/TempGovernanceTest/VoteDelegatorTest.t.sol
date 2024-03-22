// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {PushVoteDelegator} from "../../contracts/PushStaking/PushVoteDelegator.sol";
import {PushMockToken} from "../mocks/PushMockToken.sol";
import { IPUSH } from "../../contracts/interfaces/IPUSH.sol";
import "../BaseTest.t.sol";

contract PushVoteDelegatorTest is Test, BaseTest{
  PushMockToken govToken;

  function setUp() public virtual override {
    BaseTest.setUp(); 
    govToken = new PushMockToken(actor.admin);
    vm.label(address(govToken), "Push Governance Token");
  }

  function __deploy(address _deployer, address _delegatee) public returns (PushVoteDelegator) {
   vm.assume(_deployer != address(0));

    vm.prank(_deployer);
    PushVoteDelegator _voteDelegator = new PushVoteDelegator(IPUSH(address(govToken)), _delegatee);
    return _voteDelegator;
  }
}

contract Constructor is PushVoteDelegatorTest {
  function testFuzz_DelegatesToDeployer(address _deployer, address _delegatee) public {
    PushVoteDelegator _voteDelegator = __deploy(_deployer, _delegatee);
    assertEq(_delegatee, govToken.delegates(address(_voteDelegator)));
  }

  function testFuzz_MaxApprovesDeployerToEnableWithdrawals(
    address _deployer,
    address _delegatee,
    uint96 _amount,
    address _receiver
  ) public {
    vm.assume(_receiver != address(0));

    PushVoteDelegator _voteDelegator = __deploy(_deployer, _delegatee);
    govToken.mint(address(_voteDelegator), _amount);

    uint256 _allowance = govToken.allowance(address(_voteDelegator), _deployer);
    assertEq(_allowance, type(uint96).max);

    vm.prank(_deployer);
    //govToken.transferFrom(address(_voteDelegator), _receiver, _amount);

    //assertEq(govToken.balanceOf(_receiver), _amount);
  }

  function test_DelegationWorks_with_EOA() public {
    address _delegatee = actor.bob_channel_owner; 
    PushVoteDelegator _voteDelegator = __deploy(actor.admin, _delegatee);
    govToken.mint(address(_voteDelegator), 1000);

    uint256 balSurrogate = govToken.balanceOf(address(_voteDelegator));
    // Balance of Surrogate is right
    assertEq(balSurrogate, 1000);

    //Mint 1129 tokens for ALICE
    govToken.mint(actor.alice_channel_owner, 1129);
    uint256 balAlice = govToken.balanceOf(address(actor.alice_channel_owner));
    assertEq(balAlice, 1129);

    // Alice Delegates to Charlie
   uint96 voteCountBefore = govToken.getCurrentVotes(actor.charlie_channel_owner);

    vm.prank(actor.alice_channel_owner);

    govToken.delegate(actor.charlie_channel_owner);
    // Delegates Match 
    address delegateState = govToken.delegates(actor.alice_channel_owner);
    assertEq(delegateState, actor.charlie_channel_owner);
    // VoteCount Check
    uint96 voteCountAfter = govToken.getCurrentVotes(actor.charlie_channel_owner);
    assertGt(voteCountAfter, voteCountBefore);
    assertEq(voteCountAfter, 1129);
    vm.stopPrank();

  }

  
  function test_DelegationWorks_with_CONTRACT() public {
    // Alice Gets 2129 Tokens
    govToken.mint(actor.alice_channel_owner, 2129);
    uint256 balAlice = govToken.balanceOf(address(actor.alice_channel_owner));
    assertEq(balAlice, 2129);

    // 2. Alice deploys her VoteHolder Contract and delegates to Charlie
    vm.startPrank(actor.alice_channel_owner);
    PushVoteDelegator _voteDelegator = new PushVoteDelegator(IPUSH(address(govToken)), actor.charlie_channel_owner);
    
    uint96 voteCountCharlie_before = govToken.getCurrentVotes(actor.charlie_channel_owner);
    // 3. After that, she transfers 1129 Token into VoteHolder Contract
    govToken.transfer(address(_voteDelegator), 1129);
    uint256 balSurrogate = govToken.balanceOf(address(_voteDelegator));
    assertEq(balSurrogate, 1129);
    
    // 4. Checks:
    //  a. Delegates state should be marked correctly - VoteHolder => Charlie
    //  b. Charlie should have votes
    address delegateState = govToken.delegates(address(_voteDelegator));
    uint96 voteCountCharlie_after = govToken.getCurrentVotes(actor.charlie_channel_owner);

    assertEq(delegateState, actor.charlie_channel_owner);
    assertGt(voteCountCharlie_after, voteCountCharlie_before);
    assertEq(voteCountCharlie_after, 1129);

    // 5. Then Alice transfers 1000 More tokens to VoteHolder
    govToken.transfer(address(_voteDelegator), 1000);
    uint96 voteCountCharlie_after2nd = govToken.getCurrentVotes(actor.charlie_channel_owner);

    assertEq(voteCountCharlie_after2nd, 2129);
    assertGt(voteCountCharlie_after2nd, voteCountCharlie_after);
    assertGt(voteCountCharlie_after2nd, voteCountCharlie_before);
  }
}
