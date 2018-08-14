#!/usr/bin/env bash

# The build of StarlingX relies, besides RPM Binaries and Sources, in this
# repository which is a collection of packages in the form of Tar Compressed
# files and RPMs obtained from a Tar Compressed file. This script and a text
# file containing a list of packages enable their download and the creation
# of the repository based in common and specific requirements dictated
# by the StarlingX building system recipes.

# input files:
# The files tarball-dl.lst and mvn-artifacts.lst contain the list of packages
# and artifacts for building this sub-mirror.
script_path="$(dirname $(readlink -f $0))"
tarball_file="$script_path/tarball-dl.lst"
mvn_artf_file="$script_path/mvn-artifacts.lst"

if [ ! -e $tarball_file -o ! -e $mvn_artf_file ];then
    echo "$download_list does not exist, please have a check!"
    exit -1
fi

# The 2 categories we can divide the list of packages in the output directory:
# - General hosted under "downloads" output directory.
# - Puppet hosted under "downloads/puppet" output directory.
# to be populated under $MY_REPO/addons/wr-cgcs/layers/cgcs/downloads/puppet

logs_dir="$script_path/logs"
output_main="$script_path/output"
output_path=$output_main/stx-r1/CentOS/pike
output_tarball=$output_path/downloads
output_puppet=$output_tarball/puppet

mkdir -p $output_tarball
mkdir -p $output_puppet
if [ ! -d "$logs_dir" ]; then
    mkdir "$logs_dir"
fi

output_log_download_failed="$logs_dir/log_download_tarball_missing.txt"
[ -f $output_log_download_failed ] && rm $output_log_download_failed

output_log_checksum_failed="$logs_dir/log_checksum_tarball_failed.txt"
[ -f $output_log_checksum_failed ] && rm $output_log_checksum_failed

download_package() {
    url=$1
    path=$2
    status=0
    wget --spider $url
    status=$?
    if [ status != 0 ]; then
        echo "$url is not there"
    else
        echo "$url is being downloaded"
        wget -t 5 --wait=1 $url -O $path
        status=$?
        if [ $status != 0 ]; then
            echo "Error: Failed to download $url" 1>&2
        else
            echo "$url downloaded"
        fi
    fi
    return $status
}

check_md5_package() {
    status=0
    md5=`md5sum ${1} | awk '{ print $1 }'`
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

# This script will iterate over the tarball.lst text file and execute specific
# tasks based on the name of the package:

for line in $(cat $tarball_file); do

    # A line from the text file starting with "#" character is ignored

    if [[ "$line" =~ ^'#' ]]; then
        echo "Skip $line"
        continue
    fi

    # The text file contains 3 columns separated by a character "#"
    # - Column 1, name of package including extensions as it is referenced
    #   by the build system recipe, character "!" at the beginning of the name package
    #   denotes special handling is required tarball_name=`echo $line | cut -d"#" -f1-1`
    # - Column 2, name of the directory path after it is decompressed as it is
    #   referenced in the build system recipe.
    # - Column 3, the URL for the package download

    tarball_name=$(echo $line | cut -d"," -f1-1)
    directory_name=$(echo $line | cut -d"," -f2-2)
    tarball_checksum=$(echo $line | cut -d"," -f3-3)
    tarball_url=$(echo $line | cut -d"," -f4-4)

    # - For the General category and the Puppet category:
    #   - Packages have a common process: download, decompressed,
    #     change the directory path and compressed.

    if [[ "$line" =~ ^pupp* ]]; then
        download_path=$output_puppet/$tarball_name
        download_directory=$output_puppet
    else
        download_path=$output_tarball/$tarball_name
        download_directory=$output_tarball
    fi

    if [[ "$line" =~ ^MLNX_OFED_LINUX ]]; then
        download_path=$output_tarball/$directory_name
    fi

    cd $download_directory

    # We have 6 packages from the text file which require special handling
    # besides the common process: remove directory, remove text from some
    # files, clone a git repository, etc.

    if [ ! -e $download_path ]; then

        download_package $tarball_url $download_path
        if [[ $? != 0 ]]; then
            echo "Error: Download failed $tarball_name" 1>&2
            echo "$tarball_name" >> "$output_log_download_failed"
            continue
        fi

        if [ "$tarball_name" = "integrity-kmod-e6aef069.tar.gz" ]; then
            tar xf $tarball_name
            mv linux-tpmdd-e6aef06/security/integrity/ $directory_name
            rm -f $tarball_name
            tar czvf $tarball_name $directory_name
            rm -rf linux-tpmdd-e6aef06
            rm -rf $directory_name
        elif [ "$tarball_name" = "mariadb-10.1.28.tar.gz" ]; then
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
        # The mvn.repo.tgz tarball will be created downloading a serie of
        # of maven artifacts described in mvn-artifacts file.
        elif [ "$tarball_name" = "mvn.repo.tgz" ]; then
            mkdir -p "$directory_name"
            if [ ! -f "$mvn_artf_file" ]; then
                echo "$mvn_artf_file no found" 1>&2
                exit 1
            fi
            while read -r artf; do
                echo "download: $(basename $artf)"
                wget "$tarball_url/$artf" -P "$directory_name/$(dirname $artf)"
            done < "$mvn_artf_file"

            # Create tarball
            tar -zcvf "$tarball_name" -C "$directory_name"/ .
            rm  -rf "$directory_name"
            mv "$tarball_name" "$download_directory"
        elif [[ "$tarball_name" =~ ^'MLNX_OFED_LINUX' ]]; then
            mv $download_path $tarball_name
            pkg_version=$(echo "$tarball_name" | cut -d "-" -f2-3)
            srpm_path="MLNX_OFED_SRC-${pkg_version}/SRPMS/"
            tar -xf "$tarball_name"
            directory_name=`echo $tarball_name | sed 's/.tgz//'`
            tar -xf "$directory_name/src/MLNX_OFED_SRC-${pkg_version}.tgz"
            # This section of code gets specific SRPMs versions according
            # to the OFED tarbal version,
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
        elif [ "$tarball_name" = "tpm-kmod-e6aef069.tar.gz" ]; then
            tar xf $tarball_name
            mv linux-tpmdd-e6aef06/drivers/char/tpm $directory_name
            rm -f $tarball_name
            tar czvf $tarball_name $directory_name
            rm -rf linux-tpmdd-e6aef06
            rm -rf $directory_name
        elif [ "$tarball_name" = "tss2-930.tar.gz" ]; then
            git clone https://git.code.sf.net/p/ibmtpm20tss/tss ibmtpm20tss-tss
            pushd ibmtpm20tss-tss
            git checkout v930
            rm -rf .git
            popd
            mv ibmtpm20tss-tss $directory_name
            tar czvf $tarball_name $directory_name
            rm -rf $directory_name
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

    cd $script_path

    check_md5_package $download_path $tarball_checksum
    if [[ $? != 0 ]]; then
        echo "Error: Checksum failed $tarball_name" 1>&2
        echo $line >> $output_log_checksum_failed
    fi

done

# End of file

