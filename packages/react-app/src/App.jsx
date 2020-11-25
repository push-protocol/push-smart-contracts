import React, { useCallback, useEffect, useState } from "react";
import "antd/dist/antd.css";
import { getDefaultProvider, InfuraProvider, JsonRpcProvider, Web3Provider } from "@ethersproject/providers";
import "./App.css";
import { Row, Col, Button } from "antd";
import Web3Modal from "web3modal";
import WalletConnectProvider from "@walletconnect/web3-provider";
import { useUserAddress } from "eth-hooks";
import { useExchangePrice, useGasPrice, useUserProvider, useContractLoader, useContractReader, useBalance, useEventListener } from "./hooks";
import { Header, Account, Faucet, Ramp, Contract, GasGauge } from "./components";

import { INFURA_ID, ETHERSCAN_KEY } from "./constants";
import List from "antd/es/list";
import TokenBalance from "./components/TokenBalance";
import ProxyContract from "./hooks/ProxyContract";

// 🛰 providers
console.log("📡 Connecting to Mainnet Ethereum");
// const mainnetProvider = getDefaultProvider("mainnet", { infura: INFURA_ID, etherscan: ETHERSCAN_KEY, quorum: 1 });
// const mainnetProvider = new InfuraProvider("mainnet",INFURA_ID);
// const mainnetProvider = new JsonRpcProvider("https://mainnet.infura.io/v3/5ce0898319eb4f5c9d4c982c8f78392a")
// ( ⚠️ Getting "failed to meet quorum" errors? Check your INFURA_ID)

// 🏠 Your local provider is usually pointed at your local blockchain
// as you deploy to other networks you can set REACT_APP_PROVIDER=https://dai.poa.network in packages/react-app/.env
const localProviderUrl = process.env.REACT_APP_PROVIDER ? process.env.REACT_APP_PROVIDER : "http://localhost:8545"; // https://dai.poa.network
console.log("🏠 Connecting to provider:", localProviderUrl);
const localProvider = new JsonRpcProvider(localProviderUrl);
/*
  Web3 modal helps us "connect" external wallets:
*/
const web3Modal = new Web3Modal({
  // network: "mainnet", // optional
  cacheProvider: true, // optional
  providerOptions: {
    walletconnect: {
      package: WalletConnectProvider, // required
      options: {
        infuraId: INFURA_ID,
      },
    },
  },
});

const logoutOfWeb3Modal = async () => {
  await web3Modal.clearCachedProvider();
  setTimeout(() => {
    window.location.reload();
  }, 1);
};

function App() {
  const [injectedProvider, setInjectedProvider] = useState();
  /* 💵 this hook will get the price of ETH from 🦄 Uniswap: */
  // const price = useExchangePrice(mainnetProvider); //1 for xdai

  /* 🔥 this hook will get the price of Gas from ⛽️ EtherGasStation */
  const gasPrice = useGasPrice("fast"); //1000000000 for xdai

  // For more hooks, check out 🔗eth-hooks at: https://www.npmjs.com/package/eth-hooks

  // Use your injected provider from 🦊 Metamask or if you don't have it then instantly generate a 🔥 burner wallet.
  const userProvider = useUserProvider(injectedProvider, localProvider);
  const address = useUserAddress(userProvider);

  // 🏗 scaffold-eth is full of handy hooks like this one to get your balance:
  const yourLocalBalance = useBalance(localProvider, address);
  console.log("💵 yourLocalBalance", yourLocalBalance);

  // just plug in different 🛰 providers to get your balance on different chains:
  // const yourMainnetBalance = useBalance(mainnetProvider, address);
  // console.log("💵 yourMainnetBalance",yourMainnetBalance)
  // Load in your local 📝 contract and read a value from it:
  const readContracts = useContractLoader(localProvider, { EPNSProxy: "EPNSCore" });
  console.log("📝 readContracts", readContracts)
  const proxy = ProxyContract('EPNSCore', localProvider, 'EPNSProxy');

  console.log(proxy.aDaiAddress());


  // keep track of a variable from the contract in the local React state:
  const purpose = useContractReader(readContracts, "EPNSProxy", "aDaiAddress");
  console.log("🤗 implementation:", purpose)

  // If you want to make 🔐 write transactions to your contracts, use the userProvider:
  // const writeContracts = useContractLoader(userProvider)
  // console.log("🔐 writeContracts",writeContracts)

  //📟 Listen for broadcast events
  // const transferEvents = useEventListener(readContracts, "EPNS", "Transfer", localProvider, 1);
  //console.log("📟 SetPurpose events:",setPurposeEvents)

  const loadWeb3Modal = useCallback(async () => {
    const provider = await web3Modal.connect();
    setInjectedProvider(new Web3Provider(provider));
  }, [setInjectedProvider]);

  useEffect(() => {
    if (web3Modal.cachedProvider) {
      loadWeb3Modal();
    }
  }, [loadWeb3Modal]);

  return (
    <div className="App">
      <Header />

      <div style={{ position: "fixed", textAlign: "right", right: 0, top: 0, padding: 10 }}>
        <Account
          address={address}
          localProvider={localProvider}
          userProvider={userProvider}
          // mainnetProvider={mainnetProvider}
          // price={price}
          web3Modal={web3Modal}
          loadWeb3Modal={loadWeb3Modal}
          logoutOfWeb3Modal={logoutOfWeb3Modal}
        />
      </div>

      <Contract
        name="EPNSCore"
        signer={userProvider.getSigner()}
        provider={localProvider}
        contractOverride={{ EPNSCore: "EPNSProxy" }}
      />

      <Contract
          name="EPNS"
          signer={userProvider.getSigner()}
          provider={localProvider}
      />

      <Contract
          name="Timelock"
          signer={userProvider.getSigner()}
          provider={localProvider}
      />

      <Contract
          name="GovernorAlpha"
          signer={userProvider.getSigner()}
          provider={localProvider}
      />

      {/* 🗺 Extra UI like gas price, eth price, faucet, and support: */}
       <div style={{ position: "fixed", textAlign: "left", left: 0, bottom: 20, padding: 10 }}>
         <Row align="middle" gutter={[4, 4]}>
           <Col span={8}>
             {/*<Ramp price={price} address={address} />*/}
           </Col>

           <Col span={8} style={{ textAlign: "center", opacity: 0.8 }}>
             <GasGauge gasPrice={gasPrice} />
           </Col>
           <Col span={8} style={{ textAlign: "center", opacity: 1 }}>
             <Button
               onClick={() => {
                 window.open("https://t.me/joinchat/KByvmRe5wkR-8F_zz6AjpA");
               }}
               size="large"
               shape="round"
             >
               <span style={{ marginRight: 8 }} role="img" aria-label="support">
                 💬
               </span>
               Support
             </Button>
           </Col>
         </Row>

         <Row align="middle" gutter={[4, 4]}>
           <Col span={24}>
             {
               /*  if the local provider has a signer, let's show the faucet:  */
             }
           </Col>
         </Row>
       </div>




    </div>
  );
}

export default App;
