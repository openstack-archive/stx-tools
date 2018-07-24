#!/usr/bin/env bash

sudo virsh destroy controller-0 || true
sudo rm -rf /var/lib/libvirt/images/controller-0-0.img
sudo rm -rf /var/lib/libvirt/images/controller-0-1.img

for i in {0..1}; do
    sudo virsh destroy compute-$i || true
    sudo rm -rf /var/lib/libvirt/images/compute-${i}-0.img
    sudo rm -rf /var/lib/libvirt/images/compute-${i}-1.img
done

for i in {1..4}; do
    sudo ifconfig virbr$i down || true
    sudo brctl delbr virbr$i || true
done
