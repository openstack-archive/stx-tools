#!/usr/bin/env bash

NETWORK_DEFAULT=default
INTERFACE=virbr0

sudo apt-get install virt-manager libvirt-bin qemu-system -y

if virsh net-list --name | grep ${NETWORK_DEFAULT} ; then
    sudo virsh net-destroy ${NETWORK_DEFAULT}
    sudo virsh net-undefine ${NETWORK_DEFAULT}
    sudo rm -rf /etc/libvirt/qemu/networks/autostart/${NETWORK_DEFAULT}.xml
fi

cat << EOF | sudo tee /etc/libvirt/qemu.conf
user = "root"
group = "root"
EOF

sudo service libvirt-bin restart

if [ -d "/sys/class/net/${INTERFACE}" ]; then
    sudo ifconfig ${INTERFACE} down || true
    sudo brctl delbr ${INTERFACE} || true
fi
