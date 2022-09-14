#!/bin/bash

gen_keys() {
    cardano-cli address key-gen \
                --verification-key-file "$1.cardano.vk" \
                --signing-key-file "$1.cardano.sk"
    hydra-tools gen-hydra-key --output-file "$1.hydra"
}

run_cardano_node() {
    (cd devnet;
     cardano-node run \
                 --config cardano-node.json \
                 --topology topology.json \
                 --database-path db \
                 --socket-path node.socket \
                 --shelley-operational-certificate opcert.cert \
                 --shelley-kes-key kes.skey \
                 --shelley-vrf-key vrf.skey
    )
}

run_hydra_node() {
    local n_nodes=$1
    local node_id=$2
    source .env &&
        hydra-node \
            --node-id $node_id \
            --port 5$(printf "%03d" $node_id) \
            --api-port 9$(printf "%03d" $node_id) \
            --monitoring-port 6$(printf "%03d" $node_id) \
            $(for n in $(seq 1 $n_nodes); do
                  if [ $n != $node_id ]; then
                      echo --peer 127.0.0.1:5$(printf "%03d" $n)
                      echo --hydra-verification-key "${n}.hydra.vk"
                      echo --cardano-verification-key "${n}.cardano.vk"
                  fi
              done) \
            --hydra-signing-key "${node_id}.hydra.sk" \
            --cardano-signing-key "${node_id}.cardano.sk" \
            --hydra-scripts-tx-id $HYDRA_SCRIPTS_TX_ID \
            --ledger-genesis devnet/genesis-shelley.json \
            --ledger-protocol-parameters devnet/protocol-parameters.json \
            --network-id 42 \
            --node-socket devnet/node.socket
}

run_all() {
    local n_nodes=$1
    local prefix=$2
    (rm -rf -- $prefix
     mkdir $prefix
     cd $prefix
     ../prepare-devnet.sh
     for n in $(seq 1 $n_nodes); do
         gen_keys $n
     done
     run_cardano_node > cardano-node.log 2>&1 &
     cardano_node_process=$!
     sleep 2;
     # Seed devnet
     export CARDANO_NODE_SOCKET_PATH="devnet/node.socket";
     rm -f -- .env
     ../seed-devnet.sh $(which cardano-cli) $(which hydra-node) $prefix
     # Start nodes
     for i in $(seq 1 $n_nodes); do
         run_hydra_node $n_nodes $i > $i.log 2>&1 &
         sleep 0.1
     done
     sleep infinity
     kill $cardano_node_process
    )
}
