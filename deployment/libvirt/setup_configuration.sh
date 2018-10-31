#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}" )" )"
source ${SCRIPT_DIR}/functions.sh

while getopts "c:i:" o; do
    case "${o}" in
        c)
            CONFIGURATION="$OPTARG"
            ;;
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

if [[ -z ${CONFIGURATION} ]] || [[ -z "${ISOIMAGE}" ]]; then
    usage
    exit -1
fi

iso_image_check ${ISOIMAGE}
configuration_check ${CONFIGURATION}

CONFIGURATION=${CONFIGURATION:-simplex}
BRIDGE_INTERFACE=${BRIDGE_INTERFACE:-stxbr}
CONTROLLER=${CONTROLLER:-controller}
COMPUTE=${COMPUTE:-compute}
COMPUTE_NODES_NUMBER=${COMPUTE_NODES_NUMBER:-1}
DOMAIN_DIRECTORY=vms

bash ${SCRIPT_DIR}/destroy_configuration.sh -c $CONFIGURATION

[ ! -d ${DOMAIN_DIRECTORY} ] && mkdir ${DOMAIN_DIRECTORY}

create_controller $CONFIGURATION $CONTROLLER $BRIDGE_INTERFACE $ISOIMAGE

if ([ "$CONFIGURATION" == "standardcontroller" ]); then
    for ((i=0; i<=$COMPUTE_NODES_NUMBER; i++)); do
        COMPUTE_NODE=${CONFIGURATION}-${COMPUTE}-${i}
        create_compute ${COMPUTE_NODE}
    done
fi

sudo virt-manager
