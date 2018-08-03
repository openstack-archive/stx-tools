#!/usr/bin/env bash

#set -x

# The build of StarlingX relies, besides RPM Binaries and Sources, in this
# repository which is a collection of packages in the form of Tar Compressed
# files and 3 RPMs obtained from a Tar Compressed file. This script and a text
# file containing a list of packages enable their download and the creation
# of the repository based in common and specific requirements dictated
# by the StarlingX building system recipes.

# input files:
# The files tarball-dl.lst and mvn-artifacts.lst contain the list of packages
# and artifacts for building this sub-mirror.

script_path="$(dirname $(readlink -f $0))"
tarball_mirror="$script_path/${1}"
tarball_list="$script_path/tarball-dl.lst"
mvn_artf_file="$script_path/mvn-artifacts.lst"

if [ ! -e $tarball_list -o ! -e $mvn_artf_file ];then
    echo "$tarball_list does not exist, please have a check!"
    exit -1
fi

# The 2 categories we can divide the list of packages in the output directory:
# - General hosted under "downloads" output directory.
# - Puppet hosted under "downloads/puppet" output directory.
# to be soft linked under build container $MY_REPO/addons/wr-cgcs/layers/cgcs/

output_tarball=$tarball_mirror
output_puppet=$output_tarball/puppet

# Log Directory
logs_dir="$script_path/logs"
output_log="$logs_dir/log_download_tarball_missing.txt"

tarball_list_failed="tarball-dl.failed"
[ -f $tarball_list_failed ] && rm $tarball_list_failed

mkdir -p $output_tarball
mkdir -p $output_puppet

if [ ! -d "$logs_dir" ]; then
    mkdir "$logs_dir"
fi

download_package_wget() {
    wget --spider ${1}
    if [ $? != 0 ]; then
        echo "$1 is broken"
    else
        wget -t 5 --wait=1 ${1} -O ${2}
        if [ $? != 0 ]; then
            echo "$1" > "$output_log"
        fi
    fi
}

check_md5_package() {
    status=0
    md5=`md5sum ${1} | awk '{ print $1 }'`
    echo "Package: ${1}"
    if [ ${md5} == ${2} ]; then
        echo "Checksum Ok"
    elif [ ${2} == "Skip" ]; then
        echo "Checksum Skipped"
    else
        echo "Checksum Failed"
        status=1
    fi
    return $status
}

if [ ! -d "$tarball_mirror" ]; then
     echo "Tarball repository does not exist, creating..."
     mkdir -p $tarball_mirror
fi

for line in $(cat $tarball_list); do

    if [[ "$line" =~ ^'#' ]]; then
        echo "Skip $line"
        continue
    fi

    tarball_name=$(echo $line | cut -d"," -f1-1)
    directory_name=$(echo $line | cut -d"," -f2-2)
    tarball_checksum=$(echo $line | cut -d"," -f3-3)
    tarball_url=$(echo $line | cut -d"," -f4-4)

    if [[ "$line" =~ ^pupp* ]]; then
        tarball_directory=$output_puppet
        tarball_path=$output_puppet/$tarball_name
    else
        tarball_directory=$output_tarball
        tarball_path=$output_tarball/$tarball_name
    fi

    if [[ "$line" =~ ^MLNX_OFED_LINUX ]]; then
        tarball_path=$output_tarball/$directory_name
    fi

    pushd $tarball_directory

    if [ ! -e $tarball_path ]; then
        download_package_wget $tarball_url $tarball_path
        if [[ "$tarball_name" =~ ^integrity-kmod* ]]; then
            tar xf e6aef069b6e97790cb127d5eeb86ae9ff0b7b0e3.tar.gz
            mv linux-tpmdd-e6aef06/security/integrity/ $directory_name
            tar czvf $tarball_name $directory_name
            rm -rf linux-tpmdd-e6aef06
            rm -rf $directory_name
            rm e6aef069b6e97790cb127d5eeb86ae9ff0b7b0e3.tar.gz
        elif [[ "$tarball_name" =~ ^tpm-kmod* ]]; then
            tar xf e6aef069b6e97790cb127d5eeb86ae9ff0b7b0e3.tar.gz
            mv linux-tpmdd-e6aef06/drivers/char/tpm $directory_name
            tar czvf $tarball_name $directory_name
            rm -rf linux-tpmdd-e6aef06
            rm -rf $directory_name
            rm e6aef069b6e97790cb127d5eeb86ae9ff0b7b0e3.tar.gz
        elif [[ "$tarball_name" =~ ^qat1.7.upstream* ]]; then
            echo "None"
        elif [[ "$tarball_name" =~ ^mariadb* ]]; then
            mkdir $directory_name
            tar xf $tarball_name --strip-components 1 -C $directory_name
            rm $tarball_name
            pushd $directory_name
            rm -rf storage/tokudb
            rm ./man/tokuft_logdump.1 ./man/tokuftdump.1
            sed -e s/tokuft_logdump.1//g -i man/CMakeLists.txt
            sed -e s/tokuftdump.1//g -i man/CMakeLists.txt
            popd
            tar czvf $tarball_name $directory_name
            rm -rf $directory_name
        elif [[ "$tarball_name" =~ ^tss2-930* ]]; then
            git clone https://git.code.sf.net/p/ibmtpm20tss/tss ibmtpm20tss-tss
            pushd ibmtpm20tss-tss
            git checkout v930
            rm -rf .git
            popd
            mv ibmtpm20tss-tss $directory_name
            tar czvf $tarball_name $directory_name
            rm -rf $directory_name
        elif [[ "$tarball_name" =~ ^MLNX_OFED_LINUX* ]]; then
            mv $tarball_path $tarball_name
            pkg_version=$(echo "$tarball_name" | cut -d "-" -f2-3)
            srpm_path="MLNX_OFED_SRC-${pkg_version}/SRPMS/"
            tar -xf "$tarball_name"
            tarball=$directory_name
            directory_name=`echo $tarball_name | sed 's/.tgz//'`
            tar -xf "$directory_name/src/MLNX_OFED_SRC-${pkg_version}.tgz"
            # This section of code gets specific SRPMs versions according
            # to the OFED tarball version
            if [ "$pkg_version" = "4.2-1.2.0.0" ]; then
                cp "$srpm_path/libibverbs-41mlnx1-OFED.4.2.1.0.6.42120.src.rpm" .
            elif [ "$pkg_version" = "4.3-1.0.1.0" ]; then
                cp "$srpm_path/mlnx-ofa_kernel-4.3-OFED.4.3.1.0.1.1.g8509e41.src.rpm" .
                cp "$srpm_path/rdma-core-43mlnx1-1.43101.src.rpm" .
            elif [ "$pkg_version" = "4.3-3.0.2.1" ]; then
                cp "$srpm_path/mlnx-ofa_kernel-4.3-OFED.4.3.3.0.2.1.gcf60532.src.rpm" .
                cp "$srpm_path/rdma-core-43mlnx1-1.43302.src.rpm" .
            else
                echo "$pkg_version : unknown version"
            fi
            rm -f "$tarball_name"
            rm -rf "MLNX_OFED_SRC-${pkg_version}"
            rm -rf "$directory_name"
        else
            directory_name_original=$(tar -tf $tarball_name | head -1 | cut -f1 -d"/")
            if [ "$directory_name" != "$directory_name_original" ]; then
                mkdir -p $directory_name
                tar xf $tarball_name --strip-components 1 -C $directory_name
                tar -czf $tarball_name $directory_name
                rm -r $directory_name
            fi
        fi
    fi

    popd

    check_md5_package $tarball_path $tarball_checksum
    if [[ $? != 0 ]]; then
        echo $line >> $tarball_list_failed
    fi

done
