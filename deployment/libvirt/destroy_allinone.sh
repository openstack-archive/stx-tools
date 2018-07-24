#!/usr/bin/env bash

CONTROLLER=controller-0-allinone
DOMAIN_DIRECTORY=vms
DOMAIN_FILE=$DOMAIN_DIRECTORY/$CONTROLLER.xml
NETWORK_INTERFACE=virbr

if virsh list --all --name | grep ${CONTROLLER}; then
    sudo virsh destroy ${CONTROLLER}
    sudo virsh undefine ${CONTROLLER}
    sudo rm -rf /var/lib/libvirt/images/${CONTROLLER}-0.img
    sudo rm -rf /var/lib/libvirt/images/${CONTROLLER}-1.img
fi

for i in {1..4}; do
    NETWORK_INTERFACE_NAME=${NETWORK_INTERFACE}$i
    if [ -d "/sys/class/net/${NETWORK_INTERFACE_NAME}" ]; then
        sudo ifconfig ${NETWORK_INTERFACE_NAME} down
        sudo brctl delbr ${NETWORK_INTERFACE_NAME}
    fi
done

[ -f ${DOMAIN_FILE} ] && rm ${DOMAIN_FILE}
