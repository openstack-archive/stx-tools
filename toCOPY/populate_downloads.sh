#!/bin/bash
#
# SPDX-License-Identifier: Apache-2.0
#

usage () {
    echo "$0 <mirror-path>"
}

if [ $# -ne 1 ]; then
    usage
    exit -1
fi

if [ -z "$MY_REPO" ]; then
    echo "\$MY_REPO is not set. Ensure you are running this script"
    echo "from the container and \$MY_REPO points to the root of"
    echo "your folder tree."
    exit -1
fi

mirror_dir=$1
tarball_lst=${MY_REPO}/../stx-tools/centos-mirror-tools/tarball-dl.lst
downloads_dir=${MY_REPO}/stx/downloads
extra_downloads="mlnx-ofa_kernel-4.3-OFED.4.3.3.0.2.1.gcf60532.src.rpm libibverbs-41mlnx1-OFED.4.2.1.0.6.42120.src.rpm rdma-core-43mlnx1-1.43302.src.rpm"

mkdir -p ${MY_REPO}/stx/downloads

while read x; do
    if [ -z $x ]; then
        continue
    fi
    if echo $x | grep -q "^#"; then
        continue
    fi

    # Get first element of item & strip leading ! if appropriate
    tarball_file=$(echo $x | sed "s/#.*//" | sed "s/^!//")
    
    # put the file in downloads 
    source_file=$(find ${mirror_dir}/downloads -name "${tarball_file}")    
    if [ -z ${source_file} ]; then
        echo "Could not find ${tarball_file}"
    else
        rel_path=$(echo ${source_file} | sed "s%^${mirror_dir}/downloads/%%")
        rel_dir_name=$(dirname ${rel_path})
        if [ ! -e ${downloads_dir}/${rel_dir_name}/${tarball_file} ]; then
            mkdir -p ${downloads_dir}/${rel_dir_name}
            cp -v ${source_file} ${downloads_dir}/${rel_dir_name}/
        fi
    fi    
done < ${tarball_lst}

for x in ${extra_downloads}; do
    cp ${mirror_dir}/downloads/$x ${downloads_dir}
done
