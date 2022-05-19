const { ethers,waffle } = require("hardhat");

const {
  bn,
  tokensBN,
  ChannelAction,
  readjustFairShareOfChannels,
} = require("../../helpers/utils");


const {epnsContractFixture,tokenFixture} = require("../common/fixtures")
const {expect} = require("../common/expect")
const createFixtureLoader = waffle.createFixtureLoader;

describe("EPNS CoreV2 Protocol", function () {
  const ADD_CHANNEL_MIN_POOL_CONTRIBUTION = tokensBN(50)
  const ADD_CHANNEL_MAX_POOL_CONTRIBUTION = tokensBN(250000 * 50)
  const ADJUST_FOR_FLOAT = bn(10 ** 7)

  let PushToken;
  let EPNSCoreV1Proxy;
  let EPNSCommV1Proxy;
  let ADMIN;
  let ALICE;
  let BOB;
  let CHARLIE;
  let CHANNEL_CREATOR;
  let ADMINSIGNER;
  let ALICESIGNER;
  let BOBSIGNER;
  let CHARLIESIGNER;
  let CHANNEL_CREATORSIGNER;


  let loadFixture;
  before(async() => {
    [wallet, other] = await ethers.getSigners()
    loadFixture = createFixtureLoader([wallet, other])
  });

  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    const [
      adminSigner,
      aliceSigner,
      bobSigner,
      charlieSigner,
      channelCreatorSigner,
    ] = await ethers.getSigners();

    ADMINSIGNER = adminSigner;
    ALICESIGNER = aliceSigner;
    BOBSIGNER = bobSigner;
    CHARLIESIGNER = charlieSigner;
    CHANNEL_CREATORSIGNER = channelCreatorSigner;

    ADMIN = await adminSigner.getAddress();
    ALICE = await aliceSigner.getAddress();
    BOB = await bobSigner.getAddress();
    CHARLIE = await charlieSigner.getAddress();
    CHANNEL_CREATOR = await channelCreatorSigner.getAddress();

    
    ({
      PROXYADMIN,
      EPNSCoreV1Proxy,
      EPNSCommV1Proxy, 
      ROUTER,
      PushToken,
      EPNS_TOKEN_ADDRS,
    } = await loadFixture(epnsContractFixture)); 

    ({MOCKDAI, ADAI} = await loadFixture(tokenFixture));

  });

  const getDomainParameters = (chainId, verifyingContract)=>{
    const EPNS_DOMAIN = {
      name: "EPNS COMM V1",
      chainId: chainId,
      verifyingContract: verifyingContract,
    };

    const type = {
      Subscribe: [
        { name: "channel", type: "address" },
        { name: "subscriber", type: "address" },
        { name: "nonce", type: "uint256" },
        { name: "expiry", type: "uint256" },
      ]
    };

    return [EPNS_DOMAIN, type]
  }

  describe("EPNS COMM: EIP 1271 Support", function(){
    describe("Testing the EIP 1271 Support", function(){
      const CHANNEL_TYPE = 2;
      const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");

        beforeEach(async function(){
        
        // 
        // ({EPNSCommV1Proxy} = await loadFixture(epnsContractFixture)); 
        
        await EPNSCoreV1Proxy.connect(ADMINSIGNER).setEpnsCommunicatorAddress(EPNSCommV1Proxy.address)
        await EPNSCommV1Proxy.connect(ADMINSIGNER).setEPNSCoreAddress(EPNSCoreV1Proxy.address);
        await PushToken.transfer(BOB, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await PushToken.transfer(ALICE, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await PushToken.transfer(CHANNEL_CREATOR, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await PushToken.connect(BOBSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await PushToken.connect(ALICESIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);
        await PushToken.connect(CHANNEL_CREATORSIGNER).approve(EPNSCoreV1Proxy.address, ADD_CHANNEL_MIN_POOL_CONTRIBUTION);


        // create a channel
        await EPNSCoreV1Proxy.connect(CHANNEL_CREATORSIGNER).createChannelWithPUSH(
          CHANNEL_TYPE,
          testChannel,
          ADD_CHANNEL_MIN_POOL_CONTRIBUTION
        );

      });
        
      it("Allow 721 sig support",async function(){
        const chainId = await EPNSCommV1Proxy.chainID().then(e => e.toNumber())
        const [EPNS_DOMAIN, type ] = getDomainParameters(chainId, EPNSCommV1Proxy.address)
        
        const [channel, subscriber, nonce, expiry] = [
          CHANNEL_CREATORSIGNER.address,
          BOBSIGNER.address, 
          1, 
          Date.now()+3600
        ]
          
        const message = {
          channel: channel,
          subscriber: subscriber,
          nonce:nonce,
          expiry:expiry,
        };
        
        const signature = await BOBSIGNER._signTypedData(EPNS_DOMAIN, type, message);
        const {v,r,s} = ethers.utils.splitSignature(signature);

        const tx = EPNSCommV1Proxy.subscribeBySig(
          channel, subscriber,nonce, expiry,
          v,r,s
        )

        await expect(tx).to.emit(EPNSCommV1Proxy,"Subscribe")

      });
        
      it("Should allow to contract subscribe to the notification using 1271 support", async function(){
        // mock verifier contract
        const VerifierContract = await ethers.getContractFactory(
          "SignatureVerifier"
        ).then((c) => c.deploy());

        const chainId = await EPNSCommV1Proxy.chainID().then(e => e.toNumber())
        const [EPNS_DOMAIN, type ] = getDomainParameters(chainId, EPNSCommV1Proxy.address)
        
        // use verifier contract as subscriber
        const [channel, subscriber, nonce, expiry] = [
          CHANNEL_CREATORSIGNER.address,
          VerifierContract.address, 
          1, 
          Date.now()+3600
        ] 

        const message = {
          channel: channel,
          subscriber: subscriber,
          nonce:nonce,
          expiry:expiry,
        };
        
        const signature = await ADMINSIGNER._signTypedData(EPNS_DOMAIN, type, message);
        const {v,r,s} = ethers.utils.splitSignature(signature);
        const tx = EPNSCommV1Proxy.subscribeBySig(
          channel, subscriber,nonce, expiry,
          v,r,s
        ) 

        await expect(tx).to.emit(EPNSCommV1Proxy, 'Subscribe')

      });    
    });
  });
});
