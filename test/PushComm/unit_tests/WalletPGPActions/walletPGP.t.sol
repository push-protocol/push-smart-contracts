pragma solidity ^0.8.0;

import { BasePushCommTest } from "../BasePushCommTest.t.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { MockERC721 } from "contracts/mocks/MockERC721.sol";

import "forge-std/console.sol";

contract walletPGP_Test is BasePushCommTest {
    string pgp1 = "PGP1";
    string pgp2 = "PGP2";
    string pgp3 = "PGP3";
    string pgp4 = "PGP4";
    MockERC721 firstERC721;
    MockERC721 secondERC721;
    MockERC721 thirdERC721;

    function setUp() public override {
        BasePushCommTest.setUp();

        changePrank(actor.admin);
        // commProxy.setFeeAmount(10e18);
        // minting 3 NFTs
        firstERC721 = new MockERC721(actor.bob_channel_owner);
        secondERC721 = new MockERC721(actor.bob_channel_owner);
        thirdERC721 = new MockERC721(actor.bob_channel_owner);
        // minting 10 push tokens to the commProxy
        approveTokens(actor.admin, address(commProxy), 50_000 ether);
        approveTokens(actor.governance, address(commProxy), 50_000 ether);
        approveTokens(actor.bob_channel_owner, address(commProxy), 50_000 ether);
        approveTokens(actor.alice_channel_owner, address(commProxy), 50_000 ether);
        approveTokens(actor.charlie_channel_owner, address(commProxy), 50_000 ether);
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

    function test_When_EOAIsOwned_AndDoesntHavePGP() external whenAUserTriesToAddAnEOAToPGP {
        // it should execute and set update the mappings
        bytes memory _data = getEncodedData(actor.bob_channel_owner);

        changePrank(actor.bob_channel_owner);

        vm.expectEmit(true, true, false, true);
        emit UserPGPRegistered(pgp1, actor.bob_channel_owner, commProxy.chainName(), block.chainid);

        commProxy.registerUserPGP(_data, pgp1, false);
        string memory _storedPgp = getWalletToPgp(_data);
        assertEq(_storedPgp, pgp1);

        assertEq(pushToken.balanceOf(address(commProxy)), 10e18);
    }

    function test_When_TheEOAIsOwned_ButAlreadyHasAPGP() external whenAUserTriesToAddAnEOAToPGP {
        // it REVERTS
        bytes memory _data = getEncodedData(actor.bob_channel_owner);

        changePrank(actor.bob_channel_owner);
        vm.expectEmit(true, true, false, true);
        emit UserPGPRegistered(pgp1, actor.bob_channel_owner, commProxy.chainName(), block.chainid);

        commProxy.registerUserPGP(_data, pgp1, false);
        string memory _storedPgp = getWalletToPgp(_data);
        assertEq(_storedPgp, pgp1);

        vm.expectRevert(abi.encodeWithSelector(Errors.Comm_InvalidArguments.selector));
        changePrank(actor.bob_channel_owner);
        commProxy.registerUserPGP(_data, pgp2, false);

        string memory _storedPgp1 = getWalletToPgp(_data);
        assertEq(_storedPgp1, pgp1);

        assertEq(pushToken.balanceOf(address(commProxy)), 10e18);
    }

    modifier whenAUserTriesToAddAnNFTToPGP() {
        _;
    }

    function test_WhenCaller_DoesntOwnTheNFT() external whenAUserTriesToAddAnNFTToPGP {
        // it REVERTS

        bytes memory _data = getEncodedData(address(firstERC721), 0);

        vm.expectRevert("NFT not owned");
        changePrank(actor.alice_channel_owner);
        commProxy.registerUserPGP(_data, pgp1, true);
        string memory _storedPgp = getWalletToPgp(_data);
    }

    function test_WhenCaller_OwnsAnNFT_ThatsNotRegistered() external whenAUserTriesToAddAnNFTToPGP {
        // it should execute and update mappings

        bytes memory _data = getEncodedData(address(firstERC721), 0);

        changePrank(actor.bob_channel_owner);
        vm.expectEmit(true, true, false, true);
        emit UserPGPRegistered(pgp1, address(firstERC721), 0, commProxy.chainName(), block.chainid);

        commProxy.registerUserPGP(_data, pgp1, true);
        string memory _storedPgp = getWalletToPgp(_data);
        assertEq(_storedPgp, pgp1);
        assertEq(pushToken.balanceOf(address(commProxy)), 10e18);
    }

    function test_WhenCaller_OwnsAnNFT_ThatsRegistered() external whenAUserTriesToAddAnNFTToPGP {
        // it should delete old PGP and update new

        bytes memory _data = getEncodedData(address(firstERC721), 0);

        changePrank(actor.bob_channel_owner);

        vm.expectEmit(true, true, false, true);
        emit UserPGPRegistered(pgp1, address(firstERC721), 0, commProxy.chainName(), block.chainid);

        commProxy.registerUserPGP(_data, pgp1, true);
        string memory _storedPgp = getWalletToPgp(_data);
        assertEq(_storedPgp, pgp1);

        firstERC721.transferFrom(actor.bob_channel_owner, actor.alice_channel_owner, 0);

        changePrank(actor.alice_channel_owner);

        for (uint256 i = 0; i < 1; i++) {
            vm.expectEmit(true, true, false, true);
            if (i == 0) {
                emit UserPGPRemoved(pgp1, address(firstERC721), 0, commProxy.chainName(), block.chainid);
            } else {
                emit UserPGPRegistered(pgp2, address(firstERC721), 0, commProxy.chainName(), block.chainid);
            }
        }
        commProxy.registerUserPGP(_data, pgp2, true);
        string memory _storedPgpAlice = getWalletToPgp(_data);
        assertEq(_storedPgpAlice, pgp2);

        assertEq(pushToken.balanceOf(address(commProxy)), 20e18);
    }

    modifier whenAUserTriesToRemoveAnEOAFromPGP() {
        _;
    }

    function test_WhenTheCaller_IsNotOwner() external whenAUserTriesToRemoveAnEOAFromPGP {
        // it REVERTS
        bytes memory _data = getEncodedData(actor.bob_channel_owner);
        changePrank(actor.bob_channel_owner);
        commProxy.registerUserPGP(_data, pgp1, false);

        vm.expectRevert(abi.encodeWithSelector(Errors.Comm_InvalidArguments.selector));
        changePrank(actor.alice_channel_owner);
        commProxy.removeWalletFromUser(_data, false);
    }

    function test_WhenTheEOA_IsOwnedAnd_AlreadyHasAPGP() external whenAUserTriesToRemoveAnEOAFromPGP {
        // it Removes the stored data
        bytes memory _data = getEncodedData(actor.bob_channel_owner);

        changePrank(actor.bob_channel_owner);
        commProxy.registerUserPGP(_data, pgp1, false);
        string memory _storedPgp = getWalletToPgp(_data);
        assertEq(_storedPgp, pgp1);

        vm.expectEmit(true, true, false, true);
        emit UserPGPRemoved(pgp1, actor.bob_channel_owner, commProxy.chainName(), block.chainid);

        commProxy.removeWalletFromUser(_data, false);
        string memory _storedPgpAfter = getWalletToPgp(_data);
        assertEq(_storedPgpAfter, "");

        assertEq(pushToken.balanceOf(address(commProxy)), 20e18);
    }

    function test_WhenEOA_IsOwned_ButDoesntHaveAPGP() external whenAUserTriesToRemoveAnEOAFromPGP {
        // it should REVERT
        bytes memory _data = getEncodedData(actor.bob_channel_owner);

        vm.expectRevert("Invalid Call");
        changePrank(actor.bob_channel_owner);
        commProxy.removeWalletFromUser(_data, false);
    }

    modifier whenAUserTriesToRemoveAnNFTFromPGP() {
        _;
    }

    function test_WhenTheNFT_IsNotOwned_ByTheCaller() external whenAUserTriesToRemoveAnNFTFromPGP {
        // it REVERTS
        bytes memory _data = getEncodedData(address(firstERC721), 0);
        changePrank(actor.bob_channel_owner);
        commProxy.registerUserPGP(_data, pgp1, true);

        vm.expectRevert("NFT not owned");
        changePrank(actor.alice_channel_owner);
        commProxy.removeWalletFromUser(_data, true);
    }

    function test_WhenTheNFT_IsOwned_AndAlreadyHasAPGP() external whenAUserTriesToRemoveAnNFTFromPGP {
        // it renoves the stored data

        bytes memory _data = getEncodedData(address(firstERC721), 0);

        changePrank(actor.bob_channel_owner);
        commProxy.registerUserPGP(_data, pgp1, true);
        string memory _storedPgp = getWalletToPgp(_data);
        assertEq(_storedPgp, pgp1);

        vm.expectEmit(true, true, false, true);
        emit UserPGPRemoved(pgp1, address(firstERC721), 0, commProxy.chainName(), block.chainid);

        commProxy.removeWalletFromUser(_data, true);
        string memory _storedPgpAfter = getWalletToPgp(_data);
        assertEq(_storedPgpAfter, "");

        assertEq(pushToken.balanceOf(address(commProxy)), 20e18);
    }

    function test_WhenNFTIsOwnedButDoesntHaveAPGP() external whenAUserTriesToRemoveAnNFTFromPGP {
        // it should REVERT
        bytes memory _data = getEncodedData(address(firstERC721), 0);

        vm.expectRevert("Invalid Call");
        changePrank(actor.bob_channel_owner);
        commProxy.removeWalletFromUser(_data, true);
    }

    function test_multipleAddresses_andFullRun(address _addr1, address _addr2) external {
        vm.assume(_addr1 != _addr2 && _addr1 != actor.admin);
        vm.assume(_addr2 != address(0) && _addr1 != address(0));
        bytes memory _dataNft1 = getEncodedData(address(firstERC721), 1);
        bytes memory _dataNft2 = getEncodedData(address(secondERC721), 1);
        bytes memory _dataEoa1 = getEncodedData(_addr1);
        bytes memory _dataEoa2 = getEncodedData(_addr2);

        changePrank(tokenDistributor);
        pushToken.transfer(_addr1, 50_000 ether);
        pushToken.transfer(_addr2, 50_000 ether);

        approveTokens(_addr1, address(commProxy), 50_000 ether);
        approveTokens(_addr2, address(commProxy), 50_000 ether);

        mintNft(_addr1, firstERC721);
        mintNft(_addr2, secondERC721);

        // addr1 registers Wallet and NFT with PGP
        changePrank(_addr1);
        vm.expectEmit(true, true, false, true);
        emit UserPGPRegistered(pgp1, _addr1, commProxy.chainName(), block.chainid);
        commProxy.registerUserPGP(_dataEoa1, pgp1, false);
        string memory _storedPgpEoa = getWalletToPgp(_dataEoa1);
        assertEq(_storedPgpEoa, pgp1);

        vm.expectEmit(true, true, false, true);
        emit UserPGPRegistered(pgp1, address(firstERC721), 1, commProxy.chainName(), block.chainid);
        commProxy.registerUserPGP(_dataNft1, pgp1, true);
        string memory _storedPgp = getWalletToPgp(_dataNft1);
        assertEq(_storedPgp, pgp1);

        // addr2 registers Wallet and NFT with PGP
        changePrank(_addr2);
        vm.expectEmit(true, true, false, true);
        emit UserPGPRegistered(pgp2, _addr2, commProxy.chainName(), block.chainid);
        commProxy.registerUserPGP(_dataEoa2, pgp2, false);
        string memory _storedPgpEoa2 = getWalletToPgp(_dataEoa2);
        assertEq(_storedPgpEoa2, pgp2);

        vm.expectEmit(true, true, false, true);
        emit UserPGPRegistered(pgp2, address(secondERC721), 1, commProxy.chainName(), block.chainid);
        commProxy.registerUserPGP(_dataNft2, pgp2, true);
        string memory _storedPgp2 = getWalletToPgp(_dataNft2);
        assertEq(_storedPgp2, pgp2);

        // addr1 transfers NFT to addr2 and addr2 registers it with PGP
        changePrank(_addr1);
        firstERC721.transferFrom(_addr1, _addr2, 1);

        string memory _storedPgpTransfer = getWalletToPgp(_dataNft1);
        assertEq(_storedPgpTransfer, pgp1);

        changePrank(_addr2);
        vm.expectEmit(true, true, false, true);
        emit UserPGPRemoved(pgp1, address(firstERC721), 1, commProxy.chainName(), block.chainid);
        commProxy.registerUserPGP(_dataNft1, pgp2, true);
        string memory _storedPgpTransferAndRegister = getWalletToPgp(_dataNft1);
        assertEq(_storedPgpTransferAndRegister, pgp2);

        assertEq(pushToken.balanceOf(address(commProxy)), 50e18);
    }

    //Helper Functions

    function getWalletToPgp(bytes memory _data) internal view returns (string memory) {
        return commProxy.walletToPGP(keccak256(_data));
    }

    function getEncodedData(address _wallet) internal view returns (bytes memory _data) {
        _data = abi.encode("eip155", block.chainid, _wallet);
    }

    function getEncodedData(address _nft, uint256 _id) internal view returns (bytes memory _data) {
        _data = abi.encode("nft", "eip155", block.chainid, _nft, _id, block.timestamp);
    }

    function mintNft(address _addr, MockERC721 _nft) internal {
        changePrank(_addr);
        _nft.mint();
    }
}
