#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}" )" )"

source ${SCRIPT_DIR}/functions.sh

BRIDGE_INTERFACE=${BRIDGE_INTERFACE:-stxbr}
CONTROLLER=${CONTROLLER:-controller-allinone}
DOMAIN_DIRECTORY=vms

for i in {0..1}; do
    CONTROLLER_NODE=${CONTROLLER}-${i}
    DOMAIN_FILE=$DOMAIN_DIRECTORY/$CONTROLLER_NODE.xml
    if virsh list --all --name | grep ${CONTROLLER_NODE}; then
        STATUS=$(virsh list --all | grep ${CONTROLLER_NODE} | awk '{ print $3}')
        if ([ "$STATUS" == "running" ])
        then
            sudo virsh destroy ${CONTROLLER_NODE}
        fi
        sudo virsh undefine ${CONTROLLER_NODE}
        delete_disk /var/lib/libvirt/images/${CONTROLLER_NODE}-0.img
        delete_disk /var/lib/libvirt/images/${CONTROLLER_NODE}-1.img
        delete_disk /var/lib/libvirt/images/${CONTROLLER_NODE}-2.img
        [ -e ${DOMAIN_FILE} ] && delete_xml ${DOMAIN_FILE}
    fi
done
