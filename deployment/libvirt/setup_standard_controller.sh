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

CONFIGURATION="standardcontroller"
BRIDGE_INTERFACE=${BRIDGE_INTERFACE:-stxbr}
CONTROLLER=${CONTROLLER:-controller}
COMPUTE=${COMPUTE:-compute}
DOMAIN_DIRECTORY=vms

bash ${SCRIPT_DIR}/destroy_standard_controller.sh

[ ! -d ${DOMAIN_DIRECTORY} ] && mkdir ${DOMAIN_DIRECTORY}

create_controller $CONFIGURATION $CONTROLLER $BRIDGE_INTERFACE $ISOIMAGE

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
