#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}" )" )"
source ${SCRIPT_DIR}/functions.sh

while getopts "i:" o; do
    case "${o}" in
        i)
            ISOIMAGE=$(readlink -f "$OPTARG")
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

iso_image_check ${ISOIMAGE}

BRIDGE_INTERFACE=${BRIDGE_INTERFACE:-stxbr}
CONTROLLER=${CONTROLLER:-controller-allinone}
DOMAIN_DIRECTORY=vms
DOMAIN_FILE=$DOMAIN_DIRECTORY/$CONTROLLER.xml

bash ${SCRIPT_DIR}/destroy_allinone.sh

[ ! -d ${DOMAIN_DIRECTORY} ] && mkdir ${DOMAIN_DIRECTORY}

for i in {0..1}; do
    CONTROLLER_NODE=${CONTROLLER}-${i}
    sudo qemu-img create -f qcow2 /var/lib/libvirt/images/${CONTROLLER_NODE}-0.img 600G
    sudo qemu-img create -f qcow2 /var/lib/libvirt/images/${CONTROLLER_NODE}-1.img 200G
    sudo qemu-img create -f qcow2 /var/lib/libvirt/images/${CONTROLLER_NODE}-2.img 200G
    ISOIMAGE=${ISOIMAGE}
    DOMAIN_FILE=${DOMAIN_DIRECTORY}/${CONTROLLER_NODE}.xml
    cp ${SCRIPT_DIR}/controller_allinone.xml ${DOMAIN_FILE}
    sed -i -e "
        s,NAME,${CONTROLLER_NODE},
        s,DISK0,/var/lib/libvirt/images/${CONTROLLER_NODE}-0.img,
        s,DISK1,/var/lib/libvirt/images/${CONTROLLER_NODE}-1.img,
        s,DISK2,/var/lib/libvirt/images/${CONTROLLER_NODE}-2.img,
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

sudo virt-manager
