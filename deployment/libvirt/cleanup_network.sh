#!/usr/bin/env bash
#
# cleanup_network.sh - Cleans up network interfaces - not safe to run blindly!

NETWORK_DEFAULT=${NETWORK_DEFAULT:-default}
BRIDGE_INTERFACE=${BRIDGE_INTERFACE=stxbr0}

if virsh net-list --name | grep ${NETWORK_DEFAULT} ; then
    sudo virsh net-destroy ${NETWORK_DEFAULT}
    sudo virsh net-undefine ${NETWORK_DEFAULT}
    sudo rm -rf /etc/libvirt/qemu/networks/autostart/${NETWORK_DEFAULT}.xml
fi

if [ -d "/sys/class/net/${BRIDGE_INTERFACE}" ]; then
    sudo ifconfig ${BRIDGE_INTERFACE} down || true
    sudo brctl delbr ${BRIDGE_INTERFACE} || true
fi
