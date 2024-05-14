pragma solidity ^0.8.0;

import { BasePushCommTest } from "../BasePushCommTest.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { MockERC721 } from "contracts/mocks/MockERC721.sol";

contract walletPGP_Test is BasePushCommTest {
    string pgp1 = "PGP1";
    string pgp2 = "PGP2";
    string pgp3 = "PGP3";
    string pgp4 = "PGP4";
    MockERC721 erc721;

    function setUp() public override {
        BasePushCommTest.setUp();
        changePrank(actor.admin);
        commProxy.setFeeAmount(10e18);
        erc721 = new MockERC721(actor.bob_channel_owner);
        approveTokens(actor.admin, address(commProxy), 50_000 ether);
        approveTokens(actor.governance, address(commProxy), 50_000 ether);
        approveTokens(
            actor.bob_channel_owner,
            address(commProxy),
            50_000 ether
        );
        approveTokens(
            actor.alice_channel_owner,
            address(commProxy),
            50_000 ether
        );
        approveTokens(
            actor.charlie_channel_owner,
            address(commProxy),
            50_000 ether
        );
        approveTokens(actor.dan_push_holder, address(commProxy), 50_000 ether);
        approveTokens(actor.tim_push_holder, address(commProxy), 50_000 ether);
    }

    modifier whenAUserTriesToAddAnEOAToPGP() {
        _;
    }

    function test_When_TheEOA_IsNotOwned_ByCaller() external whenAUserTriesToAddAnEOAToPGP {
        // it REVERTS
        bytes memory _data = getEncodedData(actor.bob_channel_owner);

        vm.expectRevert(abi.encodeWithSelector(Errors.Comm_InvalidArguments.selector));
        changePrank(actor.alice_channel_owner);
        commProxy.registerUserPGP(_data, pgp1, false);
    }

    function test_WhenEOAIsOwnedAndDoesntHaveAPGP() external whenAUserTriesToAddAnEOAToPGP {
        // it should execute and set update the mappings
        bytes memory _data = getEncodedData(actor.bob_channel_owner);

        changePrank(actor.bob_channel_owner);
        commProxy.registerUserPGP(_data, pgp1, false);
        bytes memory _storedData = getPGPToWallet(pgp1, 0);
        string memory _storedPgp = getWalletToPgp(_data);
        assertEq(_storedData, _data);
        assertEq(_storedPgp, pgp1);
        assertEq(commProxy.counter(_data), 1);

        assertEq(pushToken.balanceOf(address(commProxy)), 10e18);
    }

    function test_WhenTheEOAIsOwnedButAlreadyHasAPGP() external whenAUserTriesToAddAnEOAToPGP {
        // it REVERTS
        bytes memory _data = getEncodedData(actor.bob_channel_owner);

        changePrank(actor.bob_channel_owner);
        commProxy.registerUserPGP(_data, pgp1, false);
        bytes memory _storedData = getPGPToWallet(pgp1, 0);
        string memory _storedPgp = getWalletToPgp(_data);
        assertEq(_storedData, _data);
        assertEq(_storedPgp, pgp1);
        assertEq(commProxy.counter(_data), 1);

        vm.expectRevert(abi.encodeWithSelector(Errors.Comm_InvalidArguments.selector));
        changePrank(actor.bob_channel_owner);
        commProxy.registerUserPGP(_data, pgp2, false);

        bytes memory _storedData1 = getPGPToWallet(pgp1, 0);
        string memory _storedPgp1 = getWalletToPgp(_data);
        assertEq(_storedData1, _data);
        assertEq(_storedPgp1, pgp1);
        assertEq(commProxy.counter(_data), 1);

        assertEq(pushToken.balanceOf(address(commProxy)), 10e18);

    }

    modifier whenAUserTriesToAddAnNFTToPGP() {
        _;
    }

    function test_WhenCallerDoesntOwnTheNFT() external whenAUserTriesToAddAnNFTToPGP {
        // it REVERTS

        bytes memory _data = getEncodedData(address(erc721), 0);

        vm.expectRevert("NFT not owned");
        changePrank(actor.alice_channel_owner);
        commProxy.registerUserPGP(_data, pgp1, true);
        vm.expectRevert();
        bytes memory _storedData = getPGPToWallet(pgp1, 0);
        string memory _storedPgp = getWalletToPgp(_data);
        assertEq(_storedPgp, "");
        assertEq(commProxy.counter(_data), 0);
    }

    function test_WhenCallerOwnsAnNFTThatsNotAlreadyAttached() external whenAUserTriesToAddAnNFTToPGP {
        // it should execute and update mappings

          bytes memory _data = getEncodedData(address(erc721), 0);

        changePrank(actor.bob_channel_owner);
        commProxy.registerUserPGP(_data, pgp1, true);
        bytes memory _storedData = getPGPToWallet(pgp1, 0);
        string memory _storedPgp = getWalletToPgp(_data);
        assertEq(_storedData, _data);
        assertEq(_storedPgp, pgp1);
        assertEq(commProxy.counter(_data), 1);
        assertEq(pushToken.balanceOf(address(commProxy)), 10e18);
    }

    function test_WhenCaller_OwnsAnNFT_ThatsAlreadyAttached() external whenAUserTriesToAddAnNFTToPGP {
        // it should delete old PGP and update new

        bytes memory _data = getEncodedData(address(erc721), 0);

        changePrank(actor.bob_channel_owner);
        commProxy.registerUserPGP(_data, pgp1, true);
        bytes memory _storedData = getPGPToWallet(pgp1, 0);
        string memory _storedPgp = getWalletToPgp(_data);
        assertEq(_storedData, _data);
        assertEq(_storedPgp, pgp1);
        assertEq(commProxy.counter(_data), 1);

        erc721.transferFrom(actor.bob_channel_owner,actor.alice_channel_owner,0);
        changePrank(actor.alice_channel_owner);
        commProxy.registerUserPGP(_data, pgp2, true);
        bytes memory _storedDataAlice = getPGPToWallet(pgp2, 0);
        string memory _storedPgpAlice = getWalletToPgp(_data);
        assertEq(_storedDataAlice, _data);
        assertEq(_storedPgpAlice, pgp2);
        assertEq(commProxy.counter(_data), 1);

        bytes memory _storedDataBob = getPGPToWallet(pgp1, 0);
        assertEq(_storedDataBob, "");
        assertEq(commProxy.counter(_data), 1);

        assertEq(pushToken.balanceOf(address(commProxy)), 20e18);

    }

        modifier whenAUserTriesToRemoveAnEOAFromPGP() {
        _;
    }

    function test_WhenTheCallerIsNotOwner() external whenAUserTriesToRemoveAnEOAFromPGP {
        // it REVERTS
        bytes memory _data = getEncodedData(actor.bob_channel_owner);
        changePrank(actor.bob_channel_owner);
        commProxy.registerUserPGP(_data, pgp1, false);

        vm.expectRevert(abi.encodeWithSelector(Errors.Comm_InvalidArguments.selector));
        changePrank(actor.alice_channel_owner);
        commProxy.removeWalletFromUser(_data, false);
    }

    function test_WhenTheEOAIsOwnedAndAlreadyHasAPGP() external whenAUserTriesToRemoveAnEOAFromPGP {
        // it Removes the stored data
        bytes memory _data = getEncodedData(actor.bob_channel_owner);

        changePrank(actor.bob_channel_owner);
        commProxy.registerUserPGP(_data, pgp1, false);
        bytes memory _storedData = getPGPToWallet(pgp1, 0);
        string memory _storedPgp = getWalletToPgp(_data);
        assertEq(_storedData, _data);
        assertEq(_storedPgp, pgp1);
        assertEq(commProxy.counter(_data), 1);

        commProxy.removeWalletFromUser(_data, false);
        // vm.expectRevert();
        bytes memory _storedDataAfter = getPGPToWallet(pgp1, 0);
        string memory _storedPgpAfter = getWalletToPgp(_data);
        assertEq(_storedDataAfter, "");
        assertEq(_storedPgpAfter, "");
        assertEq(commProxy.counter(_data), 0);

        assertEq(pushToken.balanceOf(address(commProxy)), 20e18);
    }

    function test_WhenEOAIsOwnedButDoesntHaveAPGP() external whenAUserTriesToRemoveAnEOAFromPGP {
        // it should REVERT
        bytes memory _data = getEncodedData(actor.bob_channel_owner);

        vm.expectRevert("Nothing to delete");
        changePrank(actor.bob_channel_owner);
        commProxy.removeWalletFromUser(_data, false);
    }

    modifier whenAUserTriesToRemoveAnNFTFromPGP() {
        _;
    }

    function test_WhenTheNFTIsNotOwnedByTheCaller() external whenAUserTriesToRemoveAnNFTFromPGP {
        // it REVERTS
        bytes memory _data = getEncodedData(address(erc721), 0);
        changePrank(actor.bob_channel_owner);
        commProxy.registerUserPGP(_data, pgp1, true);

        vm.expectRevert("NFT not owned");
        changePrank(actor.alice_channel_owner);
        commProxy.removeWalletFromUser(_data, true);
    }

    function test_WhenTheNFTIsOwnedAndAlreadyHasAPGP() external whenAUserTriesToRemoveAnNFTFromPGP {
        // it renoves the stored data

        bytes memory _data = getEncodedData(address(erc721), 0);

        changePrank(actor.bob_channel_owner);
        commProxy.registerUserPGP(_data, pgp1, true);
        bytes memory _storedData = getPGPToWallet(pgp1, 0);
        string memory _storedPgp = getWalletToPgp(_data);
        assertEq(_storedData, _data);
        assertEq(_storedPgp, pgp1);
        assertEq(commProxy.counter(_data), 1);

        commProxy.removeWalletFromUser(_data, true);
        // vm.expectRevert();
        bytes memory _storedDataAfter = getPGPToWallet(pgp1, 0);
        string memory _storedPgpAfter = getWalletToPgp(_data);
        assertEq(_storedDataAfter, "");
        assertEq(_storedPgpAfter, "");
        assertEq(commProxy.counter(_data), 0);

        assertEq(pushToken.balanceOf(address(commProxy)), 20e18);
    }

    function test_WhenNFTIsOwnedButDoesntHaveAPGP() external whenAUserTriesToRemoveAnNFTFromPGP {
        // it should REVERT
        bytes memory _data = getEncodedData(address(erc721), 0);

        vm.expectRevert("Nothing to delete");
        changePrank(actor.bob_channel_owner);
        commProxy.removeWalletFromUser(_data, true);
    }

    //Helper Functions

    function getWalletToPgp(bytes memory _data) internal view returns (string memory) {
        return commProxy.walletToPGP(_data);
    }

    function getPGPToWallet(string memory _pgp, uint256 _count) internal view returns (bytes memory) {
        return commProxy.PGPToWallet(_pgp, _count);
    }

    function getEncodedData(address _wallet) internal pure returns (bytes memory _data) {
        _data = abi.encode("eip155", _wallet);
    }

    function getEncodedData(address _nft, uint256 _id) internal view returns (bytes memory _data) {
        _data = abi.encode("nft", "eip155", block.chainid, _nft, _id, block.timestamp);
    }
}
