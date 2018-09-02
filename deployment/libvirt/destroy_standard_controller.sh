#!/usr/bin/env bash

BRIDGE_INTERFACE=${BRIDGE_INTERFACE:-stxbr}
CONTROLLER=${CONTROLLER:-controller}
COMPUTE=${COMPUTE:-compute}
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
        sudo rm -rf /var/lib/libvirt/images/${COMPUTE_NODE}-0.img
        sudo rm -rf /var/lib/libvirt/images/${COMPUTE_NODE}-1.img
        [ -e ${DOMAIN_FILE} ] && rm ${DOMAIN_FILE}
    fi
done
