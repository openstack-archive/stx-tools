#!/usr/bin/env bash

DOMAIN_DIRECTORY=vms

usage() {
    echo "$0 [-h] [-i <iso image>]"
    echo ""
    echo "Options:"
    echo "  -i: StarlingX ISO image"
    echo ""
}

iso_image() {
    local ISOIMAGE=$1
    #ISOIMAGE=$(readlink -f "$ISOIMAGE")
    FILETYPE=$(file --mime-type -b ${ISOIMAGE})
    if ([ "$FILETYPE" != "application/x-iso9660-image" ]); then
        echo "$ISOIMAGE is not an application/x-iso9660-image type"
        exit -1
    fi
}

# Delete a node's disk file in a safe way
delete_disk() {
    local fpath="$1"

    if [ ! -f "$fpath" ]; then
        echo "file to delete is not a regular file: $fpath" >&2
        return 1
    fi

    file -b "$fpath" | grep -q "^QEMU QCOW Image (v3),"
    if [ $? -ne 0 ]; then
        echo "file to delete is not QEMU QCOW Image (v3): $fpath" >&2
        return 1
    fi

    sudo rm "$fpath"
}

# Delete an xml file in a safe way
delete_xml() {
    local fpath="$1"

    if [ ! -f "$fpath" ]; then
        echo "file to delete is not a regular file: $fpath" >&2
        return 1
    fi

    file -b "$fpath" | grep -q "^ASCII text$"
    if [ $? -ne 0 ]; then
        echo "file to delete is not ASCII text: $fpath" >&2
        return 1
    fi

    sudo rm "$fpath"
}

# Create a Controller node
create_controller() {
    local CONFIGURATION=$1
    local CONTROLLER=$2
    local BRIDGE_INTERFACE=$3
    local ISOIMAGE=$4
    local DOMAIN_FILE=${DOMAIN_DIRECTORY}/${CONTROLLER}.xml
    if ([ "$CONFIGURATION" == "simplex" ]); then
        CONTROLLER_NODE_NUMBER=0
    else
        CONTROLLER_NODE_NUMBER=1
    fi
    for ((i=0; i<=$CONTROLLER_NODE_NUMBER; i++)); do
        CONTROLLER_NODE=${CONFIGURATION}-${CONTROLLER}-${i}
        DOMAIN_FILE=${DOMAIN_DIRECTORY}/${CONTROLLER_NODE}.xml
        if ([ "$CONFIGURATION" == "simplex" ] || [ "$CONFIGURATION" == "duplex" ]); then
            DISK_0_SIZE=600
            cp controller_allinone.xml ${DOMAIN_FILE}
        else
            DISK_0_SIZE=200
            cp controller.xml ${DOMAIN_FILE}
        fi
        sed -i -e "
            s,NAME,${CONTROLLER_NODE},
            s,DISK0,/var/lib/libvirt/images/${CONTROLLER_NODE}-0.img,
            s,DISK1,/var/lib/libvirt/images/${CONTROLLER_NODE}-1.img,
            s,%BR1%,${BRIDGE_INTERFACE}1,
            s,%BR2%,${BRIDGE_INTERFACE}2,
            s,%BR3%,${BRIDGE_INTERFACE}3,
            s,%BR4%,${BRIDGE_INTERFACE}4,
        " ${DOMAIN_FILE}
        sudo qemu-img create -f qcow2 /var/lib/libvirt/images/${CONTROLLER_NODE}-0.img ${DISK_0_SIZE}G
        sudo qemu-img create -f qcow2 /var/lib/libvirt/images/${CONTROLLER_NODE}-1.img 200G
        if ([ "$CONFIGURATION" == "simplex" ] || [ "$CONFIGURATION" == "duplex" ]); then
            sed -i -e "
                s,DISK2,/var/lib/libvirt/images/${CONTROLLER_NODE}-2.img,
            " ${DOMAIN_FILE}
            sudo qemu-img create -f qcow2 /var/lib/libvirt/images/${CONTROLLER_NODE}-2.img 200G
        fi
        if [ $i -eq 0 ]; then
            sed -i -e "s,ISO,${ISOIMAGE}," ${DOMAIN_FILE}
        else
            sed -i -e "s,ISO,," ${DOMAIN_FILE}
        fi
        sudo virsh define ${DOMAIN_DIRECTORY}/${CONTROLLER_NODE}.xml
        if [ $i -eq 0 ]; then
            sudo virsh start ${CONTROLLER_NODE}
        fi
        echo "                                               " $i
    done
}

# Delete a Controller node
destroy_controller() {
    local CONFIGURATION=$1
    local CONTROLLER=$2
    if ([ "$CONFIGURATION" == "simplex" ]); then
        CONTROLLER_NODE_NUMBER=0
    else
        CONTROLLER_NODE_NUMBER=1
    fi
    for ((i=0; i<=$CONTROLLER_NODE_NUMBER; i++)); do
        CONTROLLER_NODE=${CONFIGURATION}-${CONTROLLER}-${i}
        DOMAIN_FILE=$DOMAIN_DIRECTORY/$CONTROLLER_NODE.xml
        if virsh list --all --name | grep ${CONTROLLER_NODE}; then
            STATUS=$(virsh list --all | grep ${CONTROLLER_NODE} | awk '{ print $3}')
            if ([ "$STATUS" == "running" ])
            then
                sudo virsh destroy ${CONTROLLER_NODE}
            fi
            sudo virsh undefine ${CONTROLLER_NODE}
            delete_disk /var/lib/libvirt/images/${CONTROLLER_NODE}-0.img
            delete_disk /var/lib/libvirt/images/${CONTROLLER_NODE}-1.img
            if ([ "$CONFIGURATION" == "simplex" ] || [ "$CONFIGURATION" == "duplex" ]); then
                delete_disk /var/lib/libvirt/images/${CONTROLLER_NODE}-2.img
            fi
            [ -e ${DOMAIN_FILE} ] && delete_xml ${DOMAIN_FILE}
        fi
    done
}

# Create a Compute node
create_compute() {
    COMPUTE_NODE=$1
    sudo qemu-img create -f qcow2 /var/lib/libvirt/images/${COMPUTE_NODE}-0.img 200G
    sudo qemu-img create -f qcow2 /var/lib/libvirt/images/${COMPUTE_NODE}-1.img 200G
    DOMAIN_FILE=${DOMAIN_DIRECTORY}/${COMPUTE_NODE}.xml
    cp compute.xml ${DOMAIN_FILE}
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
}

# Delete a Compute node
destroy_compute() {
    local COMPUTE_NODE=$1
    local DOMAIN_FILE=$DOMAIN_DIRECTORY/$COMPUTE_NODE.xml
    if virsh list --all --name | grep ${COMPUTE_NODE}; then
        STATUS=$(virsh list --all | grep ${COMPUTE_NODE} | awk '{ print $3}')
        if ([ "$STATUS" == "running" ])
        then
            sudo virsh destroy ${COMPUTE_NODE}
        fi
        sudo virsh undefine ${COMPUTE_NODE}
        delete_disk /var/lib/libvirt/images/${COMPUTE_NODE}-0.img
        delete_disk /var/lib/libvirt/images/${COMPUTE_NODE}-1.img
        [ -e ${DOMAIN_FILE} ] && delete_xml ${DOMAIN_FILE}
    fi
}

# Create a Storage node
create_compute() {
    local STORAGE_NODE=$1
    local DOMAIN_FILE=${DOMAIN_DIRECTORY}/${STORAGE_NODE}.xml
    sudo qemu-img create -f qcow2 /var/lib/libvirt/images/${STORAGE_NODE}-0.img 200G
    sudo qemu-img create -f qcow2 /var/lib/libvirt/images/${STORAGE_NODE}-1.img 200G
    cp storage.xml ${DOMAIN_FILE}
    sed -i -e "
        s,NAME,${STORAGE_NODE},;
        s,DISK0,/var/lib/libvirt/images/${STORAGE_NODE}-0.img,;
        s,DISK1,/var/lib/libvirt/images/${STORAGE_NODE}-1.img,
        s,%BR1%,${BRIDGE_INTERFACE}1,
        s,%BR2%,${BRIDGE_INTERFACE}2,
        s,%BR3%,${BRIDGE_INTERFACE}3,
        s,%BR4%,${BRIDGE_INTERFACE}4,
    " ${DOMAIN_FILE}
    sudo virsh define ${DOMAIN_FILE}
}

# Delete a Storage node
destroy_storage() {
    local STORAGE_NODE=$1
    local DOMAIN_FILE=$DOMAIN_DIRECTORY/$STORAGE_NODE.xml
    if virsh list --all --name | grep ${STORAGE_NODE}; then
        STATUS=$(virsh list --all | grep ${STORAGE_NODE} | awk '{ print $3}')
        if ([ "$STATUS" == "running" ])
        then
            sudo virsh destroy ${STORAGE_NODE}
        fi
        sudo virsh undefine ${STORAGE_NODE}
        delete_disk /var/lib/libvirt/images/${STORAGE_NODE}-0.img
        delete_disk /var/lib/libvirt/images/${STORAGE_NODE}-1.img
        [ -e ${DOMAIN_FILE} ] && delete_xml ${DOMAIN_FILE}
    fi
}
