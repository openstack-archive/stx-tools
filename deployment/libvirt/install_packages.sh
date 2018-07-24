#!/usr/bin/env bash

user=`whoami`
cat << EOF | sudo tee /etc/sudoers.d/${user}
${user} ALL = (root) NOPASSWD:ALL
EOF

#install libvirt/qemu
sudo apt-get install virt-manager libvirt-bin qemu-system -y
sudo virsh net-destroy default
sudo virsh net-undefine default
sudo rm -rf /etc/libvirt/qemu/networks/autostart/default.xml
cat << EOF | sudo tee /etc/libvirt/qemu.conf
user = "root"
group = "root"
EOF

sudo service libvirt-bin restart
sudo ifconfig virbr0 down
sudo brctl delbr virbr0
