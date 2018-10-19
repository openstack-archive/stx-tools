#!/usr/bin/env bash

MY_WORKING_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}" )" )"
source ${MY_WORKING_DIR}/functions.sh

while getopts "i:" o; do
    case "${o}" in
        i)
            ISOIMAGE=$(readlink -f "$OPTARG")
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${ISOIMAGE}" ]; then
    usage
    exit -1
fi

iso_image_check ${ISOIMAGE}

CONFIGURATION="dedicatedstorage"
BRIDGE_INTERFACE=${BRIDGE_INTERFACE:-stxbr}
CONTROLLER=${CONTROLLER:-controller}
COMPUTE=${COMPUTE:-compute}
COMPUTE_NODES_NUMBER=${COMPUTE_NODES_NUMBER:-1}
STORAGE=${STORAGE:-storage}
STORAGE_NODES_NUMBER=${STORAGE_NODES_NUMBER:-1}
DOMAIN_DIRECTORY=vms

bash destroy_dedicated_storage.sh

[ ! -d ${DOMAIN_DIRECTORY} ] && mkdir ${DOMAIN_DIRECTORY}

create_controller $CONFIGURATION $CONTROLLER $BRIDGE_INTERFACE $ISOIMAGE

for ((i=0; i<=$COMPUTE_NODES_NUMBER; i++)); do
    COMPUTE_NODE=${CONFIGURATION}-${COMPUTE}-${i}
    create_compute ${COMPUTE_NODE}
done

for ((i=0; i<=$STORAGE_NODES_NUMBER; i++)); do
    STORAGE_NODE=${CONFIGURATION}-${STORAGE}-${i}
    create_compute ${STORAGE_NODE}
done

sudo virt-manager
