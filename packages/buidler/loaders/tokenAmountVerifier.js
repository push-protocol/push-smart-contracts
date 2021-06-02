const chalk = require('chalk');
const { bn } = require('../helpers/utils');
const { DISTRIBUTION_INFO } = require('../scripts/constants/constants')

let totalAmount = bn(0);

function getTokens(obj){
  if(typeof(obj) == 'string') {
    const objBn = bn(obj)
    totalAmount = totalAmount.add(objBn)
    return obj;
  }
  for (const [key, value] of Object.entries(obj)) {
    if(key == 'total'){
      continue;
    }
    getTokens(value);
  }
}

function verifyTokensAmount(upgradeVersion, paramatersToVerify) {
  if(Object.entries(DISTRIBUTION_INFO).length > 0){
    let expectedTotalAmount = DISTRIBUTION_INFO.total;

    getTokens(DISTRIBUTION_INFO)

    if(totalAmount != expectedTotalAmount) {
      console.log('🔥 ', chalk.underline.red(`Total Amount and breakdown doesn't match`), chalk.bgWhite.black(`  ${expectedTotalAmount} != ${totalAmount}  `),  chalk(` Please fix to continue! \n`))
      process.exit(1)
    }

    console.log(chalk.grey(` Total amount is equal to breakdown sum`),  chalk.green.bold(`${expectedTotalAmount}`), chalk(`==`), chalk.green.bold(`${totalAmount}\n`))
  }
}

module.exports = {
  verifyTokensAmount: verifyTokensAmount
}
