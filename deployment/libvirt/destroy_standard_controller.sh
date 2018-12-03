#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}" )" )"

source ${SCRIPT_DIR}/functions.sh

CONFIGURATION="standardcontroller"
BRIDGE_INTERFACE=${BRIDGE_INTERFACE:-stxbr}
CONTROLLER=${CONTROLLER:-controller}
COMPUTE=${COMPUTE:-compute}
DOMAIN_DIRECTORY=vms

destroy_controller ${CONFIGURATION} ${CONTROLLER}

for i in {0..1}; do
    COMPUTE_NODE=${COMPUTE}-${i}
    DOMAIN_FILE=$DOMAIN_DIRECTORY/$COMPUTE_NODE.xml
    if virsh list --all --name | grep ${COMPUTE_NODE}; then
        STATUS=$(virsh list --all | grep ${COMPUTE_NODE} | awk '{ print $3}')
        if ([ "$STATUS" == "running" ])
        then
            sudo virsh destroy ${COMPUTE_NODE}
        fi
        sudo virsh undefine ${COMPUTE_NODE}
        delete_disk /var/lib/libvirt/images/${COMPUTE_NODE}-0.img
        delete_disk /var/lib/libvirt/images/${COMPUTE_NODE}-1.img
        [ -e ${DOMAIN_FILE} ] && delete_xml ${DOMAIN_FILE}
    fi
done
