#!/usr/bin/env bash

usage() {
    echo "$0 [-h] [-i <iso image>]"
    echo ""
    echo "Options:"
    echo "  -i: StarlingX ISO image"
    echo ""
}

while getopts "i:" o; do
    case "${o}" in
        i)
            ISOIMAGE="$OPTARG"
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${ISOIMAGE}" ]; then
    usage
    exit -1
fi

CONTROLLER=controller-0-allinone
DOMAIN_DIRECTORY=vms
DOMAIN_FILE=$DOMAIN_DIRECTORY/$CONTROLLER.xml
NETWORK_INTERFACE=virbr

bash destroy_allinone.sh

[ ! -d ${DOMAIN_DIRECTORY} ] && mkdir ${DOMAIN_DIRECTORY}

for i in {1..4}; do
    sudo brctl addbr ${NETWORK_INTERFACE}$i
done

sudo ifconfig ${NETWORK_INTERFACE}1 10.10.10.1/24 up
sudo ifconfig ${NETWORK_INTERFACE}2 192.168.204.1/24 up
sudo ifconfig ${NETWORK_INTERFACE}3 up
sudo ifconfig ${NETWORK_INTERFACE}4 up
sudo iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -j MASQUERADE

sudo qemu-img create -f qcow2 /var/lib/libvirt/images/${CONTROLLER}-0.img 600G
sudo qemu-img create -f qcow2 /var/lib/libvirt/images/${CONTROLLER}-1.img 200G
ISOIMAGE=`pwd`/`ls ${ISOIMAGE}`
sed "s~ISO~${ISOIMAGE}~g" controller_allinone.xml > ${DOMAIN_FILE}
sudo virsh define ${DOMAIN_FILE}
sudo virsh start ${CONTROLLER}

sudo virt-manager
