#!/usr/bin/env bash

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
        sudo rm -rf /var/lib/libvirt/images/${CONTROLLER_NODE}-0.img
        sudo rm -rf /var/lib/libvirt/images/${CONTROLLER_NODE}-1.img
        [ -e ${DOMAIN_FILE} ] && rm ${DOMAIN_FILE}
    fi
done
