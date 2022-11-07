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

describe("EPNS Comm V1_5 Protocol", function () {
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

  describe("EPNS COMM: EIP 1271 & 712 Support", function(){
    const CHANNEL_TYPE = 2;
    const testChannel = ethers.utils.toUtf8Bytes("test-channel-hello-world");
  
    const getDomainParameters = (chainId, verifyingContract)=>{
      const EPNS_DOMAIN = {
        name: "EPNS COMM V1",
        chainId: chainId,
        verifyingContract: verifyingContract,
      };
      return [EPNS_DOMAIN]
    }

    describe("Channel Subscription Tests", function(){
      
      const type = {
        "Subscribe": [
         { name: "channel", type: "address" },
         { name: "subscriber", type: "address" },
         { name: "nonce", type: "uint256" },
         { name: "expiry", type: "uint256" },
       ]
      };
      
      beforeEach(async function(){
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
          ADD_CHANNEL_MIN_POOL_CONTRIBUTION,
          0
        );
      });
        
      it("Allows to optin with 721 sig",async function(){
        const chainId = await EPNSCommV1Proxy.chainID().then(e => e.toNumber())
        const [EPNS_DOMAIN ] = getDomainParameters(chainId, EPNSCommV1Proxy.address)
        
        const [channel, subscriber, expiry] = [
          CHANNEL_CREATORSIGNER.address,
          BOBSIGNER.address, 
          Date.now()+3600
        ]

        const nonce = await EPNSCommV1Proxy.nonces(subscriber)  
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
        
      it("Allow to contract to optin using 1271 support", async function(){
        // mock verifier contract
        const VerifierContract = await ethers.getContractFactory(
          "SignatureVerifier"
        ).then((c) => c.deploy());

        const chainId = await EPNSCommV1Proxy.chainID().then(e => e.toNumber())
        const [EPNS_DOMAIN ] = getDomainParameters(chainId, EPNSCommV1Proxy.address)
        
        // use verifier contract as subscriber
        const [channel, subscriber, expiry] = [
          CHANNEL_CREATORSIGNER.address,
          VerifierContract.address, 
          Date.now()+3600
        ] 
        
        const nonce = await EPNSCommV1Proxy.nonces(subscriber)  
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

      it("Reverts on signature replay", async function(){
        const chainId = await EPNSCommV1Proxy.chainID().then(e => e.toNumber())
        const [EPNS_DOMAIN ] = getDomainParameters(chainId, EPNSCommV1Proxy.address)
        
        // use verifier contract as subscriber
        const [channel, subscriber, expiry] = [
          CHANNEL_CREATORSIGNER.address,
          BOBSIGNER.address,
          Date.now()+3600
        ] 
        
        const nonce = await EPNSCommV1Proxy.nonces(subscriber)  
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
        await expect(tx).to.emit(EPNSCommV1Proxy, 'Subscribe')


        const tx2 = EPNSCommV1Proxy.subscribeBySig(
          channel, subscriber,nonce, expiry,
          v,r,s
        )         
        await expect(tx2).to.be.revertedWith("EPNSCommV1_5::subscribeBySig: Invalid nonce")

      }); 

      it("Reverts on signature expiry", async function(){
        const chainId = await EPNSCommV1Proxy.chainID().then(e => e.toNumber())
        const [EPNS_DOMAIN ] = getDomainParameters(chainId, EPNSCommV1Proxy.address)
        
        // use verifier contract as subscriber
        const [channel, subscriber, expiry] = [
          CHANNEL_CREATORSIGNER.address,
          BOBSIGNER.address,
          36000
        ] 
        
        const nonce = await EPNSCommV1Proxy.nonces(subscriber)  
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
        await expect(tx).to.be.revertedWith("EPNSCommV1_5::subscribeBySig: Signature expired")

      }); 
    });

    describe("Channel UnSubscription Tests", function(){
      
      const type = {
        "Unsubscribe": [
          { name: "channel", type: "address" },
          { name: "subscriber", type: "address" },
          { name: "nonce", type: "uint256" },
          { name: "expiry", type: "uint256" },
        ]
      };

      beforeEach(async function(){
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
          ADD_CHANNEL_MIN_POOL_CONTRIBUTION,
          0
        );

        // initally subscribe to the channel before unsubscribe test
        await (async ()=>{
          const chainId = await EPNSCommV1Proxy.chainID().then(e => e.toNumber())
          const type = {
            "Subscribe": [
              { name: "channel", type: "address" },
              { name: "subscriber", type: "address" },
              { name: "nonce", type: "uint256" },
              { name: "expiry", type: "uint256" },
            ] 
          }
          const [EPNS_DOMAIN ] = getDomainParameters(chainId, EPNSCommV1Proxy.address)
          const [channel, subscriber, expiry] = [
            CHANNEL_CREATORSIGNER.address,
            BOBSIGNER.address, 
            Date.now()+3600
          ]
          const nonce = await EPNSCommV1Proxy.nonces(subscriber)  
          const message = {
            channel: channel,
            subscriber: subscriber,
            nonce:nonce,
            expiry:expiry,
          };
          const signature = await BOBSIGNER._signTypedData(EPNS_DOMAIN, type, message);
          const {v,r,s} = ethers.utils.splitSignature(signature);
          await EPNSCommV1Proxy.subscribeBySig(
            channel, subscriber,nonce, expiry,
            v,r,s
          )
        })()

      });
        
      it("Allows to optout with 721 sig",async function(){
        const chainId = await EPNSCommV1Proxy.chainID().then(e => e.toNumber())
        const [EPNS_DOMAIN ] = getDomainParameters(chainId, EPNSCommV1Proxy.address)
        
        const [channel, subscriber, expiry] = [
          CHANNEL_CREATORSIGNER.address,
          BOBSIGNER.address, 
          Date.now()+3600
        ]

        const nonce = await EPNSCommV1Proxy.nonces(subscriber)  
        const message = {
          channel: channel,
          subscriber: subscriber,
          nonce:nonce,
          expiry:expiry,
        };
        
        const signature = await BOBSIGNER._signTypedData(EPNS_DOMAIN, type, message);
        const {v,r,s} = ethers.utils.splitSignature(signature);
        const tx = EPNSCommV1Proxy.unsubscribeBySig(
          channel, subscriber,nonce, expiry,
          v,r,s
        )

        await expect(tx).to.emit(EPNSCommV1Proxy,"Unsubscribe")
      });
        
      it("Allow contract to optout using 1271 support", async function(){

        const subscribeType = {
          "Subscribe": [
            { name: "channel", type: "address" },
            { name: "subscriber", type: "address" },
            { name: "nonce", type: "uint256" },
            { name: "expiry", type: "uint256" },
          ]
        };

        const unSubscribeType = {
          "Unsubscribe": [
            { name: "channel", type: "address" },
            { name: "subscriber", type: "address" },
            { name: "nonce", type: "uint256" },
            { name: "expiry", type: "uint256" },
          ]
        };

        // mock verifier contract
        const VerifierContract = await ethers.getContractFactory(
          "SignatureVerifier"
        ).then((c) => c.deploy());

        const chainId = await EPNSCommV1Proxy.chainID().then(e => e.toNumber())
        const [EPNS_DOMAIN ] = getDomainParameters(chainId, EPNSCommV1Proxy.address)
        
        // use verifier contract as subscriber
        const [channel, subscriber, expiry] = [
          CHANNEL_CREATORSIGNER.address,
          VerifierContract.address, 
          Date.now()+3600
        ] 
        
        // initally subscribe as contract:
        let nonce = await EPNSCommV1Proxy.nonces(subscriber)  
        let message = {
          channel: channel,
          subscriber: subscriber,
          nonce:nonce,
          expiry:expiry,
        };
        let signature = await ADMINSIGNER._signTypedData(EPNS_DOMAIN, subscribeType, message);
        let {v,r,s} = ethers.utils.splitSignature(signature);
        await EPNSCommV1Proxy.subscribeBySig(
          channel, subscriber,nonce, expiry,
          v,r,s
        ) 

        // unsubscribe as contract
        nonce = await EPNSCommV1Proxy.nonces(subscriber)  
        message = {
          channel: channel,
          subscriber: subscriber,
          nonce:nonce,
          expiry:expiry,
        };
        signature = await ADMINSIGNER._signTypedData(EPNS_DOMAIN, unSubscribeType, message);
        ({v,r,s} = ethers.utils.splitSignature(signature));
        const tx = EPNSCommV1Proxy.unsubscribeBySig(
          channel, subscriber,nonce, expiry,
          v,r,s
        ) 
        
        await expect(tx).to.emit(EPNSCommV1Proxy, 'Unsubscribe')

      });    

      it("Reverts on signature replay", async function(){
        const chainId = await EPNSCommV1Proxy.chainID().then(e => e.toNumber())
        const [EPNS_DOMAIN ] = getDomainParameters(chainId, EPNSCommV1Proxy.address)
        
        // use verifier contract as subscriber
        const [channel, subscriber, expiry] = [
          CHANNEL_CREATORSIGNER.address,
          BOBSIGNER.address,
          Date.now()+3600
        ] 
        
        const nonce = await EPNSCommV1Proxy.nonces(subscriber)  
        const message = {
          channel: channel,
          subscriber: subscriber,
          nonce:nonce,
          expiry:expiry,
        };
        
        const signature = await BOBSIGNER._signTypedData(EPNS_DOMAIN, type, message);
        const {v,r,s} = ethers.utils.splitSignature(signature);
        const tx = EPNSCommV1Proxy.unsubscribeBySig(
          channel, subscriber,nonce, expiry,
          v,r,s
        )         
        await expect(tx).to.emit(EPNSCommV1Proxy, 'Unsubscribe')


        const tx2 = EPNSCommV1Proxy.unsubscribeBySig(
          channel, subscriber,nonce, expiry,
          v,r,s
        )         
        await expect(tx2).to.be.revertedWith("EPNSCommV1_5::unsubscribeBySig: Invalid nonce")

      }); 

      it("Reverts on signature expiry", async function(){
        const chainId = await EPNSCommV1Proxy.chainID().then(e => e.toNumber())
        const [EPNS_DOMAIN ] = getDomainParameters(chainId, EPNSCommV1Proxy.address)
        
        // use verifier contract as subscriber
        const [channel, subscriber, expiry] = [
          CHANNEL_CREATORSIGNER.address,
          BOBSIGNER.address,
          36000
        ] 
        
        const nonce = await EPNSCommV1Proxy.nonces(subscriber)  
        const message = {
          channel: channel,
          subscriber: subscriber,
          nonce:nonce,
          expiry:expiry,
        };
        
        const signature = await BOBSIGNER._signTypedData(EPNS_DOMAIN, type, message);
        const {v,r,s} = ethers.utils.splitSignature(signature);
       
        const tx = EPNSCommV1Proxy.unsubscribeBySig(
          channel, subscriber,nonce, expiry,
          v,r,s
        )         
        await expect(tx).to.be.revertedWith("EPNSCommV1_5::unsubscribeBySig: Signature expired")

      }); 
    });

   
  });
});