/* eslint-disable import/no-dynamic-require */
/* eslint-disable global-require */
import { Contract } from "@ethersproject/contracts";
import { useState, useEffect } from "react";

const ProxyContract = (contractName, signer, contractAddressOverride) => {
    const newContract = new Contract(
        require(`../contracts/${contractAddressOverride || contractName}.address`),
        require(`../contracts/${contractName}.abi`),
        signer,
    );
    try {
        newContract.bytecode = require(`../contracts/EPNSCore.bytecode.js`);
    } catch (e) {
        console.log(e);
    }
    return newContract;
};

export default ProxyContract;