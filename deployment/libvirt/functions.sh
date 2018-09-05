#!/usr/bin/env bash

# delete a node's disk file in a safe way
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

# delete an xml file in a safe way
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

