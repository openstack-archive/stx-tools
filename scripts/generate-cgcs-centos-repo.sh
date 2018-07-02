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

if [ -z $MY_REPO ]; then
    echo "\$MY_REPO is not set. Ensure you are running this script"
    echo "from the container and \$MY_REPO points to the root of"
    echo "your folder tree."
    exit -1
fi

mirror_dir=$1
dest_dir=$MY_REPO/cgcs-centos-repo
timestamp="$(date +%F_%H%M)"
mock_cfg_file=$dest_dir/mock.cfg.proto

if [[ ( ! -d $mirror_dir/Binary ) || ( ! -d $mirror_dir/Source ) ]]; then
    echo "The mirror $mirror_dir doesn't has the Binary and Source"
    echo "folders. Please provide a valid mirror"
    exit -1
fi

if [ ! -d $dest_dir ]; then
    mkdir -p $dest_dir
fi

for t in "Binary" "Source" ; do
    target_dir=$dest_dir/$t
    if [ ! -d $target_dir ]; then
        mkdir -p $target_dir
    else
        mv -f $target_dir $target_dir-backup-$timestamp
        mkdir -p $target_dir
    fi

    pushd $mirror_dir/$t
    find . -type d -exec mkdir -p ${target_dir}/{} \;
    popd

    all_files=`find $mirror_dir/$t -type f -name "*"`
    for ff in $all_files; do
        f_name=$(basename $ff)
        sub_dir=$(dirname $ff)
        ln -sf $ff $target_dir/$f_name
        echo "Creating symlink for $target_dir/$f_name"
        echo "------------------------------"
    done
done

read -r -d '' MOCK_CFG <<-EOF
config_opts['root'] = 'BUILD_ENV/mock'
config_opts['target_arch'] = 'x86_64'
config_opts['legal_host_arches'] = ('x86_64',)
config_opts['chroot_setup_cmd'] = 'install @buildsys-build'
config_opts['dist'] = 'el7'  # only useful for --resultdir variable subst
config_opts['releasever'] = '7'
config_opts['rpmbuild_networking'] = False

config_opts['yum.conf'] = """
[main]
keepcache=1
debuglevel=2
reposdir=/dev/null
logfile=/var/log/yum.log
retries=20
obsoletes=1
gpgcheck=0
assumeyes=1
syslog_ident=mock
syslog_device=

# repos
[local-std]
name=local-std
baseurl=LOCAL_BASE/MY_BUILD_DIR/std/rpmbuild/RPMS
enabled=1
skip_if_unavailable=1
metadata_expire=0

[local-rt]
name=local-rt
baseurl=LOCAL_BASE/MY_BUILD_DIR/rt/rpmbuild/RPMS
enabled=1
skip_if_unavailable=1
metadata_expire=0

[local-installer]
name=local-installer
baseurl=LOCAL_BASE/MY_BUILD_DIR/installer/rpmbuild/RPMS
enabled=1
skip_if_unavailable=1
metadata_expire=0

[TisCentos7Distro]
name=Tis-Centos-7-Distro
enabled=1
baseurl=LOCAL_BASE/MY_REPO_DIR/cgcs-centos-repo/Binary
failovermethod=priority
exclude=kernel-devel libvirt-devel


"""
EOF

if [ -f $mock_cfg_file ]; then
    mv $mock_cfg_file $mock_cfg_file-backup-$timestamp
fi

echo "Creating mock config file"
echo "$MOCK_CFG" >> $mock_cfg_file
