pragma solidity 0.6.11;

import "./EPNSProxy.sol";
import "./EPNSCoreV1.sol";
import "hardhat/console.sol";

contract EPNSProxyMock {

    constructor() public payable {
        address dai = address(0x7c2C195CD6D34B8F845992d380aADB2730bB9C6F);
        address aave = address(0x8858eeB3DfffA017D4BCE9801D340D36Cf895CCf);
        address adai = address(0xd9e1E804B2a52f147018E2bC2AF5e3E8614F0cC3);
        address governance = address(0x6b8954059AE4d170D1a98D9D13198F72A8d88162);

        EPNSCoreV1 logic = new EPNSCoreV1();

//        bytes memory init = abi.encodeWithSignature('initialize(address,address,address,address,uint256)', governance, aave, dai, adai, 0);
        EPNSProxy proxy = new EPNSProxy(address(logic), governance, aave, adai, dai, 0);

        EPNSCoreV1 proxied = EPNSCoreV1(address(proxy));
        console.log(proxied.daiAddress());
        console.log(proxied.aDaiAddress());
        console.log(proxied.governance());
        console.log(proxied.lendingPoolProviderAddress());

    }
}
