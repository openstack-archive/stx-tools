#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}" )" )"

source ${SCRIPT_DIR}/functions.sh

CONFIGURATION="standardcontroller"
CONTROLLER=${CONTROLLER:-controller}
COMPUTE=${COMPUTE:-compute}
COMPUTE_NODES_NUMBER=${COMPUTE_NODES_NUMBER:-1}
DOMAIN_DIRECTORY=vms

destroy_controller ${CONFIGURATION} ${CONTROLLER}

for ((i=0; i<=$COMPUTE_NODES_NUMBER; i++)); do
    COMPUTE_NODE=${COMPUTE}-${i}
    destroy_compute $COMPUTE_NODE
done
