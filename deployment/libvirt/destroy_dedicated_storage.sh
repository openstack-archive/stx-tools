#!/usr/bin/env bash

MY_WORKING_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}" )" )"

source ${MY_WORKING_DIR}/functions.sh

CONFIGURATION="dedicatedstorage"
CONTROLLER=${CONTROLLER:-controller}
COMPUTE=${COMPUTE:-compute}
COMPUTE_NODES_NUMBER=${COMPUTE_NODES_NUMBER:-1}
STORAGE=${STORAGE:-storage}
STORAGE_NODES_NUMBER=${STORAGE_NODES_NUMBER:-1}

destroy_controller ${CONFIGURATION} ${CONTROLLER}

for ((i=0; i<=$COMPUTE_NODES_NUMBER; i++)); do
    COMPUTE_NODE=${CONFIGURATION}-${COMPUTE}-${i}
    destroy_compute $COMPUTE_NODE
done

for ((i=0; i<=$STORAGE_NODES_NUMBER; i++)); do
    STORAGE_NODE=${CONFIGURATION}-${STORAGE}-${i}
    destroy_storage $STORAGE_NODE
done
