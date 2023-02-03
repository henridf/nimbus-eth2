#!/usr/bin/env bash
# Via Adrian Sutton

if [ -z "$1" ]; then
  echo "Usage: run-geth-el.sh <network-metadata-dir>"
  exit 1
fi

if [ ! -d "$1" ]; then
  echo "Please supply a valid network metadata directory"
  exit 1
fi

set -Eeu

NETWORK=$(cd "$1"; pwd)

cd $(dirname "$0")

source geth_binaries.sh
source repo_paths.sh


: ${GETH_AUTH_RPC_PORT:=18550}
: ${GETH_WS_PORT:=18551}

DATA_DIR="$(create_data_dir_for_network "$NETWORK")"
GETH_EIP4844_BINARY="/Users/henridf/gitclones/go-ethereum-eip4844/build/bin/geth"

JWT_TOKEN="$DATA_DIR/jwt-token"
create_jwt_token "$JWT_TOKEN"

NETWORK_ID=$(cat "$NETWORK/genesis.json" | jq '.config.chainId')

EXECUTION_BOOTNODES=""
if [[ -f "$NETWORK/bootstrap_nodes.txt" ]]; then
  EXECUTION_BOOTNODES+=$(awk '{print $1}' "$NETWORK/bootstrap_nodes.txt" "$NETWORK/bootstrap_nodes.txt" | paste -s -d, -)
fi

GETH_DATA_DIR="$DATA_DIR/geth"
EXECUTION_GENESIS_JSON="${NETWORK}/genesis.json"

set -x

if [[ ! -d "$GETH_DATA_DIR/geth" ]]; then
  # Initialize the genesis
  $GETH_EIP4844_BINARY --http --ws -http.api "engine" --datadir "${GETH_DATA_DIR}" init "${EXECUTION_GENESIS_JSON}"
fi

$GETH_EIP4844_BINARY \
    --authrpc.port ${GETH_AUTH_RPC_PORT} \
    --authrpc.jwtsecret "$JWT_TOKEN" \
    --allow-insecure-unlock \
    --datadir "${GETH_DATA_DIR}" \
    --bootnodes "${EXECUTION_BOOTNODES}" \
    --port 30308 \
    --password "" \
    --metrics \
    --syncmode=full \
    --networkid $NETWORK_ID 2>&1 | tee geth.log
