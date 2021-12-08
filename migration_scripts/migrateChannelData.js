const ethers = require("ethers")
const fs = require("fs")
const path = require("path")
require('dotenv').config();

const params = require('./3_migrationParams.config.js');
const infura_url = `https://ropsten.infura.io/v3/${params.INFURA_PROJECT_ID}`
const privateKey = params.KEY
// console.log(infura_url);
// console.log(privateKey);
//

const provider = new ethers.providers.JsonRpcProvider(infura_url);
const wallet = new ethers.Wallet(privateKey, provider)

const newContractAddress = params.EPNS_CORE_ADDRESS
// console.log(newContractAddress);
const newContractABI = require("./newEPNSCoreABI.json")
const newContract = new ethers.Contract(newContractAddress, newContractABI, provider)
const signingContract = newContract.connect(wallet)

  const channelData = fs.readFileSync('./channelData.json');
  console.log(fs);
// const migrateChannels = async () => {
//     return new Promise(async (resolve, reject) => {
//         let oldChanneldata;
//
//         const channelData = fs.readFileSync('./channelData.json');
//         if (channelData.length == 0) {
//             console.log("Channel Data has not been Fetched yet.");
//         } else {
//             oldChanneldata = JSON.parse(channelData);
//         }
//         console.log(oldChanneldata.channelArray.length)
//         for (let i = 0; i < oldChanneldata.channelArray.length; i += 2) {
//
//             let channelArrayList = []
//             let channelTypeArrayList = []
//             let channelIdentityArrayList = []
//             let daiArray = []
//             // In batches of 5 channel to avoid gas error
//             for (let j = i; j < i + 2; j++) {
//                 if (oldChanneldata.channelArray[j] != undefined) {
//                     channelArrayList.push(oldChanneldata.channelArray[j]);
//                     channelTypeArrayList.push(oldChanneldata.channelTypeArray[j]);
//                     channelIdentityArrayList.push(oldChanneldata.channelIdentityArray[j]);
//                     daiArray.push(oldChanneldata.daiArray[j]);
//                 }
//
//             }
//             console.log(i)
//             console.log(channelArrayList)
//             console.log(channelTypeArrayList)
//             console.log(channelIdentityArrayList)
//             const gasOptions = {  gasPrice: params.GAS_SETTINGS.gasPrice, gasLimit: params.GAS_SETTINGS.gasLimit };
//             const txPromise = signingContract.migrateChannelData(0, channelArrayList.length, channelArrayList, channelTypeArrayList, channelIdentityArrayList, daiArray, gasOptions);
//             await txPromise
//                 .then(async function (tx) {
//                     console.info('Transaction sent: %o', tx);
//                     await tx.wait(3);
//                     resolve(tx);
//                 })
//                 .catch((err) => {
//                     console.error('Unable to complete transaction, error: %o', err);
//
//                     reject(`Unable to complete transaction, error: ${err}`);
//                 });
//
//
//         }
//     })
// }
//
// migrateChannels()
