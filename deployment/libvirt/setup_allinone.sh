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

FILETYPE=$(file --mime-type -b ${ISOIMAGE})
if ([ "$FILETYPE" != "application/x-iso9660-image" ]); then
    echo "$ISOIMAGE is not an application/x-iso9660-image type"
    exit -1
fi

CONTROLLER=controller-allinone
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


for i in {0..1}; do
    CONTROLLER_NODE=${CONTROLLER}-${i}
    sudo qemu-img create -f qcow2 /var/lib/libvirt/images/${CONTROLLER_NODE}-0.img 600G
    sudo qemu-img create -f qcow2 /var/lib/libvirt/images/${CONTROLLER_NODE}-1.img 200G
    ISOIMAGE=`pwd`/`ls ${ISOIMAGE}`
    DOMAIN_FILE=${DOMAIN_DIRECTORY}/${CONTROLLER_NODE}.xml
    cp controller.xml ${DOMAIN_FILE}
    sed -i -e "
        s,NAME,${CONTROLLER_NODE},
        s,DISK0,/var/lib/libvirt/images/${CONTROLLER_NODE}-0.img,
        s,DISK1,/var/lib/libvirt/images/${CONTROLLER_NODE}-1.img,
    " ${DOMAIN_FILE}
    if [ $i -eq 0 ]; then
        sed -i -e "s,ISO,${ISOIMAGE}," ${DOMAIN_FILE}
    else
        sed -i -e "s,ISO,," ${DOMAIN_FILE}
    fi
    sudo virsh define ${DOMAIN_DIRECTORY}/${CONTROLLER_NODE}.xml
    if [ $i -eq 0 ]; then
        sudo virsh start ${CONTROLLER_NODE}
    fi
done

sudo virt-manager
