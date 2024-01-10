const { use, expect } = require("chai");
const { solidity } = require("ethereum-waffle");

use(solidity);

module.exports = {
    expect
}