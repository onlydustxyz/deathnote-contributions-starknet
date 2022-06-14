#!/bin/bash

### CONSTANTS
SCRIPT_DIR=`readlink -f $0 | xargs dirname`
ROOT=`readlink -f $SCRIPT_DIR/..`
CACHE_FILE=$ROOT/build/deployed_contracts.txt
STARKNET_ACCOUNTS_FILE=$HOME/.starknet_accounts/starknet_open_zeppelin_accounts.json
PROTOSTAR_TOML_FILE=$ROOT/protostar.toml
NETWORK=
WALLET=$STARKNET_WALLET

### FUNCTIONS
. $SCRIPT_DIR/logging.sh # Logging utilities
. $SCRIPT_DIR/tools.sh   # script utilities

# print the script usage
usage() {
    print "$0 [-a ACCOUNT_ADDRESS] [-p PROFILE] [-n NETWORK] [-x ADMIN_ADDRESS] [-w WALLET]"
}

# build the protostar project
build() {
    log_info "Building project to generate latest version of the ABI"
    execute protostar build
    if [ $? -ne 0 ]; then exit_error "Problem during build"; fi
}

# get the account address from the account alias in protostar accounts file
# $1 - account alias (optional). __default__ if not provided
get_account_address() {
    [ $# -eq 0 ] && account=__default__ || account=$1
    grep $account $STARKNET_ACCOUNTS_FILE -A3 -m1 | sed -n 's@^.*"address": "\(.*\)".*$@\1@p'
}

# get the network from the profile in protostar config file
# $1 - profile
get_network() {
    profile=$1
    grep profile.$profile $PROTOSTAR_TOML_FILE -A3 -m1 | sed -n 's@^.*network="\(.*\)".*$@\1@p'
}

# check starknet binary presence
check_starknet() {
    which starknet &> /dev/null
    [ $? -ne 0 ] && exit_error "Unable to locate starknet binary. Did you activate your virtual env ?"
}

# make sure wallet variable is set
check_wallet() {
    [ -z $WALLET ] && exit_error "Please provide the wallet to use (option -w or environment variable STARKNET_WALLET)"
}

# wait for a transaction to be received
# $1 - transaction hash to check
wait_for_acceptance() {
    tx_hash=$1
    print -n $(magenta "Waiting for transaction to be accepted")
    while true 
    do
        tx_status=`starknet tx_status --hash $tx_hash --network $NETWORK | sed -n 's@^.*"tx_status": "\(.*\)".*$@\1@p'`
        case "$tx_status"
            in
                NOT_RECEIVED|RECEIVED|PENDING) print -n  $(magenta .);;
                REJECTED) return 1;;
                ACCEPTED_ON_L1|ACCEPTED_ON_L2) return 0; break;;
                *) exit_error "\nUnknown transaction status '$tx_status'";;
            esac
            sleep 2
    done
}

# send a transaction
# $* - command line to execute
# return The contract address
send_transaction() {
    transaction=$*

    while true
    do
        execute $transaction || exit_error "Error when sending transaction"
        
        contract_address=`sed -n 's@Contract address: \(.*\)@\1@p' logs.json`
        tx_hash=`sed -n 's@Transaction hash: \(.*\)@\1@p' logs.json`

        wait_for_acceptance $tx_hash

        case $? in
            0) log_success "\nTransaction accepted!"; break;;
            1) log_warning "\nTransaction rejected!"; ask "Do you want to retry";;
        esac
    done || exit_error

    echo $contract_address
}

# Deploy the Badge, Registry and Metadata contracts and log the deployed addresses in the cache file
deploy_all_contracts() {
    [ -f $CACHE_FILE ] && {
        . $CACHE_FILE
        log_info "Found those deployed accounts:"
        cat $CACHE_FILE
        ask "Do you want to deploy missing contracts and initialize them" || return 
    }

    print Profile: $PROFILE
    print Account alias: $ACCOUNT
    print Admin address: $ADMIN_ADDRESS
    print Network: $NETWORK

    ask "Are you OK to deploy with those parameters" || return 

    [ ! -z $PROFILE ] && PROFILE_OPT="--profile $PROFILE"

    if [ -z $BADGE_ADDRESS ]; then
        log_info "Deploying badge..."
        BADGE_ADDRESS=`send_transaction "protostar $PROFILE_OPT deploy ./build/badge.json --inputs $ADMIN_ADDRESS"` || exit_error
    fi

    if [ -z $REGISTRY_ADDRESS ]; then
        log_info "Deploying badge registry..."
        REGISTRY_ADDRESS=`send_transaction "protostar $PROFILE_OPT deploy ./build/badge_registry.json --inputs $ADMIN_ADDRESS"` || exit_error
    fi

    if [ -z $METADATA_ADDRESS ]; then
        log_info "Deploying github metadata..."
        METADATA_ADDRESS=`send_transaction "protostar $PROFILE_OPT deploy ./build/github_contributions.json --inputs $ADMIN_ADDRESS"` || exit_error
    fi

    (
        echo "BADGE_ADDRESS=$BADGE_ADDRESS"
        echo "REGISTRY_ADDRESS=$REGISTRY_ADDRESS"
        echo "METADATA_ADDRESS=$METADATA_ADDRESS"
    ) | tee >&2 $CACHE_FILE

    [ ! -z $ACCOUNT ] && ACCOUNT_OPT="--account $ACCOUNT"

    log_info "Setting badge contract inside registry"
    send_transaction "starknet invoke $ACCOUNT_OPT --network $NETWORK --address $REGISTRY_ADDRESS --abi ./build/badge_registry_abi.json --function set_badge_contract --inputs $BADGE_ADDRESS"

    log_info "Setting registry contract inside github contributions"
    send_transaction "starknet invoke $ACCOUNT_OPT --network $NETWORK --address $METADATA_ADDRESS --abi ./build/github_contributions_abi.json --function set_registry_contract --inputs $REGISTRY_ADDRESS"

    log_info "Register metadata contract under the 'GITHUB' label"
    GITHUB_LABEL=78380272211266
    send_transaction "starknet invoke $ACCOUNT_OPT --network $NETWORK --address $BADGE_ADDRESS --abi ./build/badge_abi.json --function register_metadata_contract --inputs $GITHUB_LABEL $METADATA_ADDRESS"

    log_info "Granting 'MINTER' role to the registry"
    send_transaction "starknet invoke $ACCOUNT_OPT --network $NETWORK --address $BADGE_ADDRESS --abi ./build/badge_abi.json --function grant_minter_role --inputs $REGISTRY_ADDRESS"

    log_info "Granting 'REGISTER' role to the signer back-end"
    SIGNER_BACKEND_ADDRESS=0x7343772b33dd34cbb1e23b9abefdde5b7addccb3e3c66943b78e5e52d416c29
    send_transaction "starknet invoke $ACCOUNT_OPT --network $NETWORK --address $REGISTRY_ADDRESS --abi ./build/badge_registry_abi.json --function grant_register_role --inputs $SIGNER_BACKEND_ADDRESS"

    log_info "Granting 'FEEDER' role to the feeder back-end"
    FEEDER_BACKEND_ADDRESS=0x7343772b33dd34cbb1e23b9abefdde5b7addccb3e3c66943b78e5e52d416c29
    send_transaction "starknet invoke $ACCOUNT_OPT --network $NETWORK --address $METADATA_ADDRESS --abi ./build/github_contributions_abi.json --function grant_feeder_role --inputs $FEEDER_BACKEND_ADDRESS"
}

### ARGUMENT PARSING
while getopts a:p:h option
do
    case "${option}"
    in
        a) ACCOUNT=${OPTARG};;
        x) ADMIN_ADDRESS=${OPTARG};;
        p) PROFILE=${OPTARG};;
        n) NETWORK=${OPTARG};;
        w) WALLET=${OPTARG};;
        h) usage; exit_success;;
        \?) usage; exit_error;;
    esac
done

[ -z $ADMIN_ADDRESS ] && ADMIN_ADDRESS=`get_account_address $ACCOUNT`
[ -z $ADMIN_ADDRESS ] && exit_error "Unable to determine account address"

[[ -z $NETWORK && ! -z $PROFILE ]] && NETWORK=`get_network $PROFILE`
[ -z $NETWORK ] && exit_error "Unable to determine network"

### PRE_CONDITIONS
check_starknet
check_wallet

### BUSINESS LOGIC

build # Need to generate ABI and compiled contracts
deploy_all_contracts

exit_success
