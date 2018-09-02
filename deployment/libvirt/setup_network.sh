#!/usr/bin/env bash

usage() {
    echo "$0 [-h]"
    echo ""
    echo "Options:"
#    echo "  -i: StarlingX ISO image"
    echo ""
}

while getopts "i:" o; do
    case "${o}" in
        *)
            usage
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))

BRIDGE_INTERFACE=${BRIDGE_INTERFACE:-stxbr}
INTERNAL_NETWORK=${INTERNAL_NETWORK:-10.10.10.0/24}
INTERNAL_IP=${INTERNAL_IP:-10.10.10.1/24}
EXTERNAL_NETWORK=${EXTERNAL_NETWORK:-192.168.204.0/24}
EXTERNAL_IP=${EXTERNAL_IP:-192.168.204.1/24}

if [[ -r /sys/class/net/${BRIDGE_INTERFACE}1 ]]; then
    echo "${BRIDGE_INTERFACE}1 exists, cowardly refusing to overwrite it, exiting..."
    exit 1
fi

for i in {1..4}; do
    sudo brctl addbr ${BRIDGE_INTERFACE}$i
done

sudo ifconfig ${BRIDGE_INTERFACE}1 $INTERNAL_IP up
sudo ifconfig ${BRIDGE_INTERFACE}2 $EXTERNAL_IP up
sudo ifconfig ${BRIDGE_INTERFACE}3 up
sudo ifconfig ${BRIDGE_INTERFACE}4 up
sudo iptables -t nat -A POSTROUTING -s $EXTERNAL_NETWORK -j MASQUERADE
