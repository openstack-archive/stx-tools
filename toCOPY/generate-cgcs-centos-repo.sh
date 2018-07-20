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
dest_dir=$MY_REPO/cgcs-centos-repo
timestamp="$(date +%F_%H%M)"
mock_cfg_file=$MY_REPO/build-tools/repo_files/mock.cfg.proto
comps_xml_file=$MY_REPO/build-tools/repo_files/comps.xml
mock_cfg_file_dest=$MY_REPO/cgcs-centos-repo/mock.cfg.proto
comps_xml_file_dest=$MY_REPO/cgcs-centos-repo/Binary/comps.xml

if [[ ( ! -d $mirror_dir/Binary ) || ( ! -d $mirror_dir/Source ) ]]; then
    echo "The mirror $mirror_dir doesn't has the Binary and Source"
    echo "folders. Please provide a valid mirror"
    exit -1
fi

if [ ! -d "$dest_dir" ]; then
    mkdir -p "$dest_dir"
fi

for t in "Binary" "Source" ; do
    target_dir=$dest_dir/$t
    if [ ! -d "$target_dir" ]; then
        mkdir -p "$target_dir"
    else
        mv -f "$target_dir" "$target_dir-backup-$timestamp"
        mkdir -p "$target_dir"
    fi

    pushd "$mirror_dir/$t"|| exit 1
    find . -type d -exec mkdir -p "${target_dir}"/{} \;
    all_files=$(find . -type f -name "*")
    popd || exit 1


    for ff in $all_files; do
        f_name=$(basename "$ff")
        sub_dir=$(dirname "$ff")
        ln -sf "$mirror_dir/$t/$ff" "$target_dir/$sub_dir"
        echo "Creating symlink for $target_dir/$sub_dir/$f_name"
        echo "------------------------------"
    done
done


if [ ! -f "$mock_cfg_file" ]; then
    echo "Cannot find mock.cfg.proto file!"
    exit 1
fi

if [ ! -f "$comps_xml_file" ]; then
    echo "Cannot find comps.xml file!"
    exit 1
fi

echo "Copying mock.cfg.proto and comps.xml files."

if [ -f "$mock_cfg_file_dest" ]; then
    cp "$mock_cfg_file_dest" "$mock_cfg_file_dest-backup-$timestamp"
fi
cp "$mock_cfg_file" "$mock_cfg_file_dest"

if [ -f "$comps_xml_file_dest" ]; then
    cp "$comps_xml_file_dest" "$comps_xml_file_dest-backup-$timestamp"
fi
cp "$comps_xml_file" "$comps_xml_file_dest"

echo "Done"
