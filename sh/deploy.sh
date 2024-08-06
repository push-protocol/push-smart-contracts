#!/bin/bash

while getopts ":n:c:u:k:s:v:" opt; do
  case $opt in
    n) network="$OPTARG"
    ;;
    c) chain="$OPTARG"
    ;;
    k) private_key="$OPTARG"
    ;;
    s) deployment_script="$OPTARG"
    ;;
    v) verification_key="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    exit 1
    ;;
  esac

  case $OPTARG in
    -*) echo "Option $opt needs a valid argument" >&2
    exit 1
    ;;
  esac
done

if [ -z ${network+x} ]; then
    echo "network (-n) is unset" >&2
    exit 1
fi

if [ -z ${chain+x} ]; then
    echo "chain (-c) is unset" >&2
    exit 1
fi

if [ -z ${deployment_script+x} ]; then
    echo "deployment script file (-s) is unset" >&2
    exit 1
fi

if [ -z ${private_key+x} ]; then
    echo "private key (-k) is unset" >&2
    exit 1
fi

set -euo pipefail

ROOT=$(dirname $0)
ENV=$ROOT/../env
FORGE_SCRIPTS=$ROOT/../scripts

. $ENV/$network/$chain.env

# Construct the base command
forge_command="forge script $FORGE_SCRIPTS/Deployment/$deployment_script \
    --rpc-url $RPC \
    --broadcast \
    --private-key $private_key \
    --slow \
    --skip test"

# Conditionally add the --verify and --etherscan-api-key options
if [ -n "${verification_key+x}" ]; then
  forge_command+=" --verify --etherscan-api-key $verification_key"
fi

# Execute the command
eval $forge_command