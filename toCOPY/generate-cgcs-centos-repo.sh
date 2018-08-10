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
mock_cfg_dest_file=$MY_REPO/cgcs-centos-repo/mock.cfg.proto
comps_xml_dest_file=$MY_REPO/cgcs-centos-repo/Binary/comps.xml

lst_file_dir="$MY_REPO/../stx-tools/centos-mirror-tools"
rpm_lst_files="rpms_from_3rd_parties.lst rpms_from_centos_3rd_parties.lst rpms_from_centos_repo.lst"
missing_rpms_file=missing.txt

rm -f ${missing_rpms_file}

# Strip trailing / from mirror_dir if it was specified...
mirror_dir=$(echo ${mirror_dir} | sed "s%/$%%")

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
done

for lst_file in ${rpm_lst_files} ; do
    while read rpmname; do
        echo "jm - $rpmname"
        rpmname=$(echo ${rpmname} | sed "s/#.*//")        
        if [ -z ${rpmname} ]; then
            echo "jm - $rpmname 1"
            continue
        fi
        echo "jm - $rpmname 2"
        mirror_file=$(find ${mirror_dir} -name ${rpmname})        
        if [ -z "${mirror_file}" ]; then
            echo "jm - $rpmname 4 ${mirror_file}"
            echo "Error -- could not find requested ${rpmname} in ${mirror_dir}"
            echo ${rpmname} >> ${missing_rpms_file}
            continue
        fi
        echo "jm - $rpmname 3 ${mirror_file}"

        # Great, we found the file!  Let's strip the mirror_dir prefix from it...
        ff=$(echo $mirror_file | sed "s%^${mirror_dir}/%%")
        f_name=$(basename "$ff")
        sub_dir=$(dirname "$ff")

        # Make sure we have a subdir (so we don't synlink the first file as
        # the subdir name)
        mkdir -p $dest_dir/$sub_dir

        # Link it!
        echo "Creating symlink for $dest_dir/$sub_dir/$f_name"
        ln -sf "$mirror_dir/$ff" "$dest_dir/$sub_dir"
        if [ $? -ne 0 ]; then
            echo "Failed ${mirror_file}: ln -sf \"$mirror_dir/$ff\" \"$dest_dir/$sub_dir\""
        fi
    done < ${lst_file_dir}/${lst_file}
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

if [ -f "$mock_cfg_dest_file" ]; then
    cp "$mock_cfg_dest_file" "$mock_cfg_dest_file-backup-$timestamp"
fi
cp "$mock_cfg_file" "$mock_cfg_dest_file"

if [ -f "$comps_xml_dest_file" ]; then
    cp "$comps_xml_dest_file" "$comps_xml_dest_file-backup-$timestamp"
fi
cp "$comps_xml_file" "$comps_xml_dest_file"

mkdir -p $MY_REPO/cgcs-centos-repo/Binary/images
mkdir -p $MY_REPO/cgcs-centos-repo/Binary/images/pxeboot
ln -s ${mirror_dir}/Binary/images/efiboot.img $MY_REPO/cgcs-centos-repo/Binary/images
ln -s ${mirror_dir}/Binary/images/pxeboot/initrd.img $MY_REPO/cgcs-centos-repo/Binary/images/pxeboot
ln -s ${mirror_dir}/Binary/images/pxeboot/vmlinuz $MY_REPO/cgcs-centos-repo/Binary/images/pxeboot

mkdir -p $MY_REPO/cgcs-centos-repo/Binary/EFI/BOOT/fonts
for x in BOOTX64.EFI grub.cfg grubx64.efi; do
    ln -sf ${mirror_dir}/Binary/EFI/BOOT/$x $MY_REPO/cgcs-centos-repo/Binary/EFI/BOOT/
done
ln -sf ${mirror_dir}/Binary/EFI/BOOT/fonts/unicode.pf2 $MY_REPO/cgcs-centos-repo/Binary/EFI/BOOT/fonts/

mkdir -p $MY_REPO/cgcs-centos-repo/Binary/isolinux
for x in boot.msg  grub.conf  initrd.img  isolinux.bin  isolinux.cfg  memtest  splash.png  vesamenu.c32  vmlinuz; do
    ln -sf ${mirror_dir}/Binary/isolinux/$x $MY_REPO/cgcs-centos-repo/Binary/isolinux/
done
echo "Done"
