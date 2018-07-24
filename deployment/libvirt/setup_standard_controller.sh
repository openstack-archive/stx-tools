#!/usr/bin/env bash

ls *.iso &> /dev/null || (echo "Copy ISO here" && exit 1)

for i in {1..4}; do
    sudo ifconfig virbr$i down || true
    sudo brctl delbr virbr$i || true
    sudo brctl addbr virbr$i
done

sudo ifconfig virbr1 10.10.10.1/24 up
sudo ifconfig virbr2 192.168.204.1/24 up
sudo ifconfig virbr3 up
sudo ifconfig virbr4 up
sudo iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -j MASQUERADE

rm -rf vms; mkdir vms

sudo virsh destroy controller-0 || true
sudo rm -rf /var/lib/libvirt/images/controller-0-0.img
sudo qemu-img create -f qcow2 /var/lib/libvirt/images/controller-0-0.img 200G
sudo rm -rf /var/lib/libvirt/images/controller-0-1.img
sudo qemu-img create -f qcow2 /var/lib/libvirt/images/controller-0-1.img 200G
iso=`pwd`/`ls *.iso`
sed "s~ISO~$iso~g" controller.xml > vms/controller-0.xml
sudo virsh define vms/controller-0.xml
sudo virsh start controller-0

for i in {0..1}; do
    sudo virsh destroy compute-$i || true
    sudo rm -rf /var/lib/libvirt/images/compute-${i}-0.img
    sudo qemu-img create -f qcow2 /var/lib/libvirt/images/compute-${i}-0.img 200G
    sudo rm -rf /var/lib/libvirt/images/compute-${i}-1.img
    sudo qemu-img create -f qcow2 /var/lib/libvirt/images/compute-${i}-1.img 200G
    cp compute.xml vms/compute-${i}.xml
    sed -i -e "s,NAME,compute-$i," \
           -e "s,DISK0,/var/lib/libvirt/images/compute-${i}-0.img," \
           -e "s,DISK1,/var/lib/libvirt/images/compute-${i}-1.img," \
        vms/compute-${i}.xml
    sudo virsh define vms/compute-${i}.xml
done

sudo virt-manager
