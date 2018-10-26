#!/usr/bin/env bash

#set -x

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}" )" )"

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

ISOIMAGE=$(readlink -f "$ISOIMAGE")
FILETYPE=$(file --mime-type -b ${ISOIMAGE})
if ([ "$FILETYPE" != "application/x-iso9660-image" ]); then
    echo "$ISOIMAGE is not an application/x-iso9660-image type"
    exit -1
fi

BRIDGE_INTERFACE=${BRIDGE_INTERFACE:-stxbr}
CONTROLLER=${CONTROLLER:-controller}
COMPUTE=${COMPUTE:-compute}
DOMAIN_DIRECTORY=vms

bash ${SCRIPT_DIR}/destroy_standard_controller.sh

[ ! -d ${DOMAIN_DIRECTORY} ] && mkdir ${DOMAIN_DIRECTORY}

for i in {0..1}; do
    CONTROLLER_NODE=${CONTROLLER}-${i}
    sudo qemu-img create -f qcow2 /var/lib/libvirt/images/${CONTROLLER_NODE}-0.img 200G
    sudo qemu-img create -f qcow2 /var/lib/libvirt/images/${CONTROLLER_NODE}-1.img 200G
    ISOIMAGE=${ISOIMAGE}
    DOMAIN_FILE=${DOMAIN_DIRECTORY}/${CONTROLLER_NODE}.xml
    cp ${SCRIPT_DIR}/controller.xml ${DOMAIN_FILE}
    sed -i -e "
        s,NAME,${CONTROLLER_NODE},
        s,DISK0,/var/lib/libvirt/images/${CONTROLLER_NODE}-0.img,
        s,DISK1,/var/lib/libvirt/images/${CONTROLLER_NODE}-1.img,
        s,%BR1%,${BRIDGE_INTERFACE}1,
        s,%BR2%,${BRIDGE_INTERFACE}2,
        s,%BR3%,${BRIDGE_INTERFACE}3,
        s,%BR4%,${BRIDGE_INTERFACE}4,
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

for i in {0..1}; do
    COMPUTE_NODE=${COMPUTE}-${i}
    sudo qemu-img create -f qcow2 /var/lib/libvirt/images/${COMPUTE_NODE}-0.img 200G
    sudo qemu-img create -f qcow2 /var/lib/libvirt/images/${COMPUTE_NODE}-1.img 200G
    DOMAIN_FILE=${DOMAIN_DIRECTORY}/${COMPUTE_NODE}.xml
    cp ${SCRIPT_DIR}/compute.xml ${DOMAIN_FILE}
    sed -i -e "
        s,NAME,${COMPUTE_NODE},;
        s,DISK0,/var/lib/libvirt/images/${COMPUTE_NODE}-0.img,;
        s,DISK1,/var/lib/libvirt/images/${COMPUTE_NODE}-1.img,
        s,%BR1%,${BRIDGE_INTERFACE}1,
        s,%BR2%,${BRIDGE_INTERFACE}2,
        s,%BR3%,${BRIDGE_INTERFACE}3,
        s,%BR4%,${BRIDGE_INTERFACE}4,
    " ${DOMAIN_FILE}
    sudo virsh define ${DOMAIN_FILE}
done

sudo virt-manager
