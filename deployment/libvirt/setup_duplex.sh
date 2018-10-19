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

CONFIGURATION="duplex"
BRIDGE_INTERFACE=${BRIDGE_INTERFACE:-stxbr}
CONTROLLER=${CONTROLLER:-controller}
DOMAIN_DIRECTORY=vms

bash destroy_duplex.sh

[ ! -d ${DOMAIN_DIRECTORY} ] && mkdir ${DOMAIN_DIRECTORY}

create_controller $CONFIGURATION $CONTROLLER $BRIDGE_INTERFACE $ISOIMAGE

sudo virt-manager
