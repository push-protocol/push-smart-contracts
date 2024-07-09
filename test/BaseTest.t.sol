pragma solidity ^0.8.20;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";

import "contracts/token/EPNS.sol";
import "contracts/token/Push.sol";
import "contracts/interfaces/uniswap/IUniswapV2Router.sol";
import { PushCoreV3 } from "contracts/PushCore/PushCoreV3.sol";
import { PushCoreMock } from "contracts/mocks/PushCoreMock.sol";
import { EPNSCoreProxy, ITransparentUpgradeableProxy } from "contracts/PushCore/EPNSCoreProxy.sol";
import { EPNSCoreAdmin } from "contracts/PushCore/EPNSCoreAdmin.sol";
import { PushCommETHV3 } from "contracts/PushComm/PushCommEthV3.sol";
import { PushCommV3 } from "contracts/PushComm/PushCommV3.sol";
import { EPNSCommProxy } from "contracts/PushComm/EPNSCommProxy.sol";
import { EPNSCommAdmin } from "contracts/PushComm/EPNSCommAdmin.sol";
import { PushMigrationHelper } from "contracts/token/PushMigration.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import { Actors, ChannelCreators } from "./utils/Actors.sol";
import { Events } from "./utils/Events.sol";
import { Constants } from "./utils/Constants.sol";
import { BaseHelper } from "../../../../contracts/libraries/BaseHelper.sol";

abstract contract BaseTest is Test, Constants, Events {
    Push public pushNtt;
    Push public pushNttToken;
    EPNS public pushToken;
    PushCoreMock public coreMock;
    PushCoreV3 public coreProxy;
    PushCommV3 public comm;
    PushCommV3 public commProxy;
    PushCommETHV3 public commEth;
    PushCommETHV3 public commEthProxy;
    IUniswapV2Router public uniV2Router;
    EPNSCoreProxy public epnsCoreProxy;
    EPNSCoreAdmin public epnsCoreProxyAdmin;
    EPNSCommProxy public epnsCommProxy;
    EPNSCommAdmin public epnsCommProxyAdmin;
    EPNSCommProxy public epnsCommEthProxy;
    EPNSCommAdmin public epnsCommEthProxyAdmin;
    PushMigrationHelper public pushMigrationHelper;
    PushMigrationHelper public pushMigrationHelperProxy;
    TransparentUpgradeableProxy public pushMigrationProxy;
    TransparentUpgradeableProxy public pushNttProxy;
    ProxyAdmin public nttMigrationProxyAdmin;
    ProxyAdmin public nttProxyAdmin;

    /* ***************
        Main Actors in Test
     *************** */
    Actors internal actor;
    ChannelCreators internal channelCreators;
    address tokenDistributor;

    /* ***************
        State Variables
     *************** */
    uint256 ADD_CHANNEL_MIN_FEES = 50 ether;
    uint256 ADD_CHANNEL_MAX_POOL_CONTRIBUTION = 250 ether;
    uint256 FEE_AMOUNT = 10 ether;
    uint256 MIN_POOL_CONTRIBUTION = 50 ether;
    uint256 ADJUST_FOR_FLOAT = 10 ** 7;
    mapping(address => uint256) privateKeys;

    /* ***************
       Initializing Set-Up for Push Contracts
     *************** */

    function setUp() public virtual {
        tokenDistributor = makeAddr("tokenDistributor");

        pushToken = new EPNS(tokenDistributor);
        coreMock = new PushCoreMock();
        coreProxy = new PushCoreV3();
        comm = new PushCommV3();
        commEth = new PushCommETHV3();
        pushMigrationHelper = new PushMigrationHelper();
        uniV2Router = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        pushNtt = new Push();

        actor = Actors({
            admin: createActor("admin"),
            governance: createActor("governance"),
            bob_channel_owner: createActor("bob_channel_owner"),
            alice_channel_owner: createActor("alice_channel_owner"),
            charlie_channel_owner: createActor("charlie_channel_owner"),
            tony_channel_owner: createActor("tony_channel_owner"),
            dan_push_holder: createActor("dan_push_holder"),
            tim_push_holder: createActor("tim_push_holder")
        });

        // Initialize channel creators with bytes32
        channelCreators = ChannelCreators({
            admin_Bytes32: createChannelCreatorsID(actor.admin),
            governance_Bytes32: createChannelCreatorsID(actor.governance),
            bob_channel_owner_Bytes32: createChannelCreatorsID(actor.bob_channel_owner),
            alice_channel_owner_Bytes32: createChannelCreatorsID(actor.alice_channel_owner),
            charlie_channel_owner_Bytes32: createChannelCreatorsID(actor.charlie_channel_owner),
            tony_channel_owner_Bytes32: createChannelCreatorsID(actor.tony_channel_owner),
            dan_push_holder_Bytes32: createChannelCreatorsID(actor.dan_push_holder),
            tim_push_holder_Bytes32: createChannelCreatorsID(actor.tim_push_holder)
        });

        changePrank(actor.admin);
        nttProxyAdmin = new ProxyAdmin();
        pushNttProxy = new TransparentUpgradeableProxy(
            address(pushNtt),
            address(nttProxyAdmin),
            abi.encodeWithSignature("initialize()")
        );
        pushNttToken = Push(address(pushNttProxy));
        nttMigrationProxyAdmin = new ProxyAdmin();
        
        // Initialize pushMigration proxy admin and proxy contract
        pushMigrationProxy = new TransparentUpgradeableProxy(
            address(pushMigrationHelper),
            address(nttMigrationProxyAdmin),
            abi.encodeWithSignature("initialize(address,address)", actor.admin, address(pushToken))
        );
        pushMigrationHelperProxy = PushMigrationHelper(address(pushMigrationProxy));
        // set governance as minter of ntt token
        // vm.prank(actor.admin);
        pushNttToken.setMinter(actor.governance);
        epnsCoreProxyAdmin = new EPNSCoreAdmin(actor.admin);

        // Initialize coreMock proxy admin and coreProxy contract
        epnsCoreProxy = new EPNSCoreProxy(
            address(coreMock),
            address(epnsCoreProxyAdmin),
            actor.admin,
            address(pushToken),
            address(0), // WETH Address
            address(uniV2Router), // Uniswap_Router
            address(0), // Lending_Pool_Aave
            address(0), // Dai_Address
            address(0), // aDai address
            0
        );

        epnsCoreProxyAdmin.upgrade(
            ITransparentUpgradeableProxy(address(epnsCoreProxy)),
            address(coreProxy)
        );

        coreProxy = PushCoreV3(address(epnsCoreProxy));
        changePrank(tokenDistributor);
        pushToken.transfer(address(coreProxy), 1 ether);

        // Initialize comm proxy admin and commProxy contract
        epnsCommProxyAdmin = new EPNSCommAdmin(actor.admin);
        epnsCommProxy =
            new EPNSCommProxy(address(comm), address(epnsCommProxyAdmin), actor.admin, "FOUNDRY_TEST_NETWORK");
        commProxy = PushCommV3(address(epnsCommProxy));

        // Set-up Core Address in Comm & Vice-Versa
        vm.startPrank(actor.admin);
        commProxy.setEPNSCoreAddress(address(coreProxy));
        commProxy.setPushTokenAddress(address(pushToken));
        coreProxy.setEpnsCommunicatorAddress(address(commProxy));
        vm.stopPrank();

        // Initialize comm proxy admin and commProxy contract
        epnsCommEthProxyAdmin = new EPNSCommAdmin(actor.admin);
        epnsCommEthProxy =
            new EPNSCommProxy(address(comm), address(epnsCommEthProxyAdmin), actor.admin, "FOUNDRY_TEST_NETWORK");
        commEthProxy = PushCommETHV3(address(epnsCommEthProxy));

        // Set-up Core Address in Comm Eth
        vm.startPrank(actor.admin);
        commEthProxy.setEPNSCoreAddress(address(coreProxy));
        commEthProxy.setPushTokenAddress(address(pushToken));
        vm.stopPrank();

        // Approve tokens of actors now to core contract proxy address
        approveTokens(actor.admin, address(coreProxy), 50_000 ether);
        approveTokens(actor.governance, address(coreProxy), 50_000 ether);
        approveTokens(actor.bob_channel_owner, address(coreProxy), 50_000 ether);
        approveTokens(actor.alice_channel_owner, address(coreProxy), 50_000 ether);
        approveTokens(actor.charlie_channel_owner, address(coreProxy), 50_000 ether);
        approveTokens(actor.dan_push_holder, address(coreProxy), 50_000 ether);
        approveTokens(actor.tim_push_holder, address(coreProxy), 50_000 ether);
        vm.warp(DEC_27_2021);
    }

    /* ***************
       Core Contract Helper Functions
    *************** */

    function roll(uint256 num) internal {
        vm.roll(num);
    }

    function approveTokens(address from, address to, uint256 amount) internal {
        vm.startPrank(from);
        pushToken.approve(to, amount);
        pushToken.setHolderDelegation(to, true);
        vm.stopPrank();
    }

    function approveNttTokens(address from, address to, uint256 amount) internal {
        vm.startPrank(from);
        pushNttToken.approve(to, amount);
        pushNttToken.setHolderDelegation(to, true);
        vm.stopPrank();
    }

    function createActor(string memory name) internal returns (address payable) {
        address actor;
        uint256 Private;
        (actor, Private) = makeAddrAndKey(name);
        address payable _actor = payable(actor);
        privateKeys[actor] = Private;
        // Transfer 50 eth to every actor
        vm.deal({ account: _actor, newBalance: 50 ether });
        // Transfer 50K PUSH Tokens for every actor
        changePrank(tokenDistributor);
        pushToken.transfer(_actor, 50_000 ether);
        return _actor;
    }

    function createChannelCreatorsID(address _actor) internal pure returns (bytes32 _channelCreatorBytes32) {
        _channelCreatorBytes32 = BaseHelper.addressToBytes32(_actor);
    }
}
