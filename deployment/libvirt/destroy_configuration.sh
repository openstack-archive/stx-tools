#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}" )" )"

source ${SCRIPT_DIR}/functions.sh

while getopts "c:" o; do
    case "${o}" in
        c)
            CONFIGURATION=${OPTARG}
            ;;
        *)
            usage_destroy
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))

if [[ -z ${CONFIGURATION} ]]; then
    usage_destroy
    exit -1
fi

configuration_check ${CONFIGURATION}

CONFIGURATION=${CONFIGURATION:-simplex}
CONTROLLER=${CONTROLLER:-controller}
DOMAIN_DIRECTORY=vms

destroy_controller ${CONFIGURATION} ${CONTROLLER}

if ([ "$CONFIGURATION" == "standardcontroller" ]); then
    COMPUTE=${COMPUTE:-compute}
    COMPUTE_NODES_NUMBER=${COMPUTE_NODES_NUMBER:-1}
    for ((i=0; i<=$COMPUTE_NODES_NUMBER; i++)); do
        COMPUTE_NODE=${CONFIGURATION}-${COMPUTE}-${i}
        destroy_compute $COMPUTE_NODE
    done
fi
