const chalk = require('chalk');

module.exports = async (failOnNoVerification) => {
  if (!failOnNoVerification) console.log(chalk.green('✌️   Verifying ENV'));
  try {
    // Load FS and Other dependency
    const fs = require('fs');
    const envfile = require('envfile');
    const readline = require('readline');

    var fileModified = false;

    // Load environment files
    const envpath = `${__dirname}/../.env`;
    const envsamplepath = `${__dirname}/../.env.sample`;

    // First check and create .env if it doesn't exists
    if (!fs.existsSync(envpath)) {
      if (!failOnNoVerification) console.log(chalk.green('-- Checking for ENV File... Not Found'));
      fs.writeFileSync(envpath, '', { flag: 'wx' });
      if (!failOnNoVerification) console.log(chalk.green('    -- ENV File Generated'));
    }
    else {
      if (!failOnNoVerification) console.log(chalk.green('    -- Checking for ENV File... Found'));
    }

    // Now Load the environment
    const envData = fs.readFileSync(envpath, 'utf8');
    const envObject = envfile.parse(envData);

    const envSampleData = fs.readFileSync(envsamplepath, 'utf8');
    const envSampleObject = envfile.parse(envSampleData);

    const readIntSampleENV = readline.createInterface({
      input: fs.createReadStream(envsamplepath),
      output: false,
    });

    let realENVContents = '';
    if (!failOnNoVerification) console.log(chalk.green('    -- Verifying and building ENV File...'));

    for await (const line of readIntSampleENV) {
      let moddedLine = line;

      // Check if line is comment or environment variable
      if (moddedLine.startsWith('#') || moddedLine.startsWith('\n') || moddedLine.trim().length == 0) {
        // do nothing, just include it in the line
        // console.log("----");
      }
      else {
        // This is an environtment variable, first segregate the comment if any and the variable info
        const delimiter = "#";

        const index = moddedLine.indexOf('#');
        const splits = index == -1 ? [moddedLine.slice(0, index), ''] : [moddedLine.slice(0, index), ' ' + delimiter + moddedLine.slice(index + 1)]

        const envVar = splits[0].split('=')[0]; //  Get environment variable by splitting the sample and then taking first seperation
        const comment = splits[1];

        // Check if envVar exists in real env, if not ask for val
        // console.log(envObject[`${envVar}`])
        if (!envObject[`${envVar}`] || envObject[`${envVar}`].trim() == '') {
          if (failOnNoVerification) {
              console.log('🔥 ', chalk.underline.red(`Failed Verification of ENV! Please first run:`), chalk.bgWhite.black('  npm start  '));
              process.exit(1);
          }

          // env key doesn't exist, ask for input
          if (!failOnNoVerification) console.log(chalk.bgWhite.black(`  Enter ENV Variable Value --> ${envVar}`));

          var value = '';

          while (value.trim().length == 0) {
            const rl = readline.createInterface({
              input: process.stdin,
              output: null,
            });
            value = await doSyncPrompt(rl, `${envSampleObject[envVar]} >`);

            if (value.trim().length == 0) {
              if (!failOnNoVerification) console.log(chalk.red("  Incorrect Entry, Field can't be empty"));
            }
          }

          if (!failOnNoVerification) console.log(chalk.dim(`  [Saved] `), chalk.bgWhite.black(`  ${envVar}=${value}  `));
          moddedLine = `${envVar}=${value}${comment}`;

          fileModified = true;
        }
        else {
          // Value exists so just replicate
          moddedLine = `${envVar}=${envObject[envVar]}${comment}`;
        }
      }

      // finally append the line
      realENVContents = `${realENVContents}\n${moddedLine}`;
    }

    if (fileModified) {
      if (!failOnNoVerification) console.log(chalk.green('    -- new ENV file generated, saving'));
      fs.writeFileSync(envpath, realENVContents, { flag: 'w' });
      if (!failOnNoVerification) console.log(chalk.green('    -- ENV file saved!'));
    }
    else {
      if (!failOnNoVerification) console.log(chalk.green('    -- ENV file verified!'));
    }


    if (!failOnNoVerification) console.log(chalk.green('✔️   ENV Verified / Generated and Loaded!'));
    return null;
  } catch (e) {
    console.log(chalk.red('🔥  Error on env verifier loader: %o', e));
    throw e;
  }

  // Leverages Node.js' awesome async/await functionality
  async function doSyncPrompt(rl, message) {
    var promptInput = await readLineAsync(rl, message);
    rl.close();

    return promptInput;
  }

  function readLineAsync(rl, message) {
    return new Promise((resolve, reject) => {
      rl.question(message, (answer) => {
        resolve(answer.trim());
      });
    });
  }
};
