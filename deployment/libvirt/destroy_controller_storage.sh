#!/usr/bin/env bash

MY_WORKING_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}" )" )"

source ${MY_WORKING_DIR}/functions.sh

CONFIGURATION="controllerstorage"
CONTROLLER=${CONTROLLER:-controller}
COMPUTE=${COMPUTE:-compute}
COMPUTE_NODES_NUMBER=${COMPUTE_NODES_NUMBER:-1}

destroy_controller ${CONFIGURATION} ${CONTROLLER}

for ((i=0; i<=$COMPUTE_NODES_NUMBER; i++)); do
    COMPUTE_NODE=${CONFIGURATION}-${COMPUTE}-${i}
    destroy_compute $COMPUTE_NODE
done
