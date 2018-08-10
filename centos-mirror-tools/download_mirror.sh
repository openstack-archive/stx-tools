#!/bin/bash -e
#
# SPDX-License-Identifier: Apache-2.0
#

usage() {
    echo "$0 [-n] [-c <yum.conf>] [-g]"
    echo ""
    echo "Options:"
    echo "  -n: Do not use sudo when performing operations (option passed on to"
    echo "      subscripts when appropriate)"
    echo "  -c: Use an alternate yum.conf rather than the system file (option passed"
    echo "      on to subscripts when appropriate)"
    echo "  -g: do not change group IDs of downloaded artifacts"
    echo ""
}


rpm_downloader="./dl_rpms.sh"
tarball_downloader="./dl_tarball.sh"

# track optional arguments
change_group_ids=1
use_system_yum_conf=1
rpm_downloader_extra_args=""
tarball_downloader_extra_args=""

# lst files to use as input
rpms_from_3rd_parties="./rpms_from_3rd_parties.lst"
rpms_from_centos_repo="./rpms_from_centos_repo.lst"
rpms_from_centos_3rd_parties="./rpms_from_centos_3rd_parties.lst"
other_downloads="./other_downloads.lst"

# Parse out optional -c or -n arguments
while getopts "c:ngh" o; do
    case "${o}" in
        n)
            # Pass -n ("no-sudo") to rpm downloader
            rpm_downloader_extra_args="${rpm_downloader_extra_args} -n"
            ;;
        c)
            # Pass -c ("use alternate yum.conf") to rpm downloader
            use_system_yum_conf=0
            rpm_downloader_extra_args="${rpm_downloader_extra_args} -c ${OPTARG}"
            ;;
        g)
            # Do not attempt to change group IDs on downloaded packages
            change_group_ids=0
            ;;
        h)
            # Help
            usage
            exit 0
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))

echo "--------------------------------------------------------------"

echo "WARNING: this script HAS TO access internet (http/https/ftp),"
echo "so please make sure your network working properly!!"

mkdir -p ./logs

need_file(){
    for f in $*; do
        if [ ! -e $f ]; then
            echo "ERROR: $f does not exist."
            exit -1
        fi
    done
}

# Check extistence of prerequisites files
need_file ${rpm_downloader} dl_other_from_centos_repo.sh ${tarball_downloader}
need_file ${rpms_from_3rd_parties}
need_file ${rpms_from_centos_3rd_parties}
need_file ${rpms_from_centos_repo}
need_file ${other_downloads}
need_file tarball-dl.lst mvn-artifacts.lst

if [ ! -e $rpm_downloader ];then
    echo "ERROR: $rpm_downloader does NOT exist!!"
    exit -1
fi

#download RPMs/SRPMs from 3rd_party websites (not CentOS repos) by "wget"
echo "step #1: start downloading RPMs/SRPMs from 3rd-party websites..."

if [ ${use_system_yum_conf} -eq 0 ]; then
    # Restore StarlingX_3rd repos from backup
    REPO_SOURCE_DIR=/localdisk/yum.repos.d
    REPO_DIR=/etc/yum.repos.d
    if [ -d $REPO_SOURCE_DIR ] && [ -d $REPO_DIR ]; then
        \cp -f $REPO_SOURCE_DIR/*.repo $REPO_DIR/
    fi
fi

$rpm_downloader ${rpm_downloader_extra_args} ${rpms_from_3rd_parties} L1 3rd | tee ./logs/log_download_rpms_from_3rd_party.txt
if [ $? != 0 ];then
    echo "ERROR: something wrong with downloading, please check the log!!"
fi

# download RPMs/SRPMs from 3rd_party repos by "yumdownloader"
$rpm_downloader ${rpm_downloader_extra_args} ${rpms_from_centos_3rd_parties} L1 3rd-centos | tee ./logs/log_download_rpms_from_centos_3rd_parties_L1.txt
if [ ${use_system_yum_conf} -eq 1 ]; then
    # deleting the StarlingX_3rd to avoid pull centos packages from the 3rd Repo.
    rm -f /etc/yum.repos.d/StarlingX_3rd.repo
fi

echo "step #2: start 1st round of downloading RPMs and SRPMs with L1 match criteria..."
# download RPMs/SRPMs from CentOS repos by "yumdownloader"
if [ ! -e ${rpms_from_centos_repo} ];then
    echo "ERROR: ${rpms_from_centos_repo} does NOT exist!!"
    exit -1
fi

$rpm_downloader ${rpm_downloader_extra_args} ${rpms_from_centos_repo} L1 centos | tee ./logs/log_download_rpms_from_centos_L1.txt

if [ $? == 0 ]; then
    echo "finish 1st round of RPM downloading successfully!"
    if [ -e "./output/centos_rpms_missing_L1.txt" ]; then
        missing_num=`wc -l ./output/centos_rpms_missing_L1.txt | cut -d " " -f1-1`
        if [ "$missing_num" != "0" ];then
            echo "ERROR:  -------RPMs missing $missing_num in yumdownloader with L1 match ---------------"
        fi
    fi

    if [ -e "./output/centos_srpms_missing_L1.txt" ]; then
        missing_num=`wc -l ./output/centos_srpms_missing_L1.txt | cut -d " " -f1-1`
        if [ "$missing_num" != "0" ];then
            echo "ERROR: --------- SRPMs missing $missing_num in yumdownloader with L1 match ---------------"
        fi
    fi
else
    echo "finish 1st round with failures!"
fi

## verify all RPMs SRPMs we download for the GPG keys
find ./output -type f -name "*.rpm" | xargs rpm -K | grep -i "MISSING KEYS" > ./rpm-gpg-key-missing.txt

# remove all i686.rpms to avoid pollute the chroot dep chain
find ./output -name "*.i686.rpm" | tee ./output/all_i686.txt
find ./output -name "*.i686.rpm" | xargs rm -f

line1=`wc -l ${rpms_from_3rd_parties} | cut -d " " -f1-1`
line2=`wc -l ${rpms_from_centos_repo} | cut -d " " -f1-1`
line3=`wc -l ${rpms_from_centos_3rd_parties} | cut -d " " -f1-1`

let total_line=$line1+$line2+$line3
echo "We expect to download $total_line RPMs."
num_of_downloaded_rpms=`find ./output -type f -name "*.rpm" | wc -l | cut -d" " -f1-1`
echo "There are $num_of_downloaded_rpms RPMs in output directory."
if [ "$total_line" != "$num_of_downloaded_rpms" ]; then
    echo "WARNING: Not the same number of RPMs in output as RPMs expected to be downloaded, need to check outputs and logs."
fi

if [ $change_group_ids -eq 1 ]; then
    # change "./output" and sub-folders to 751 (cgcs) group
    chown  751:751 -R ./output
fi


echo "step #3: start downloading other files ..." 

other_downloader="./dl_other_from_centos_repo.sh"
$other_downloader ${other_downloads} ./output/stx-r1/CentOS/pike/Binary/ | tee ./logs/log_download_other_files_centos.txt
if [ $? == 0 ];then
    echo "step #3: done successfully"
fi

# StarlingX requires a group of source code pakages, in this section
# they will be downloaded.
echo "step #4: start downloading tarball compressed files"
${tarball_downloader} ${tarball_downloader_extra_args}

echo "IMPORTANT: The following 3 files are just bootstrap versions. Based"
echo "on them, the workable images for StarlingX could be generated by"
echo "running \"update-pxe-network-installer\" command after \"build-iso\""
echo "    - out/stx-r1/CentOS/pike/Binary/LiveOS/squashfs.img"
echo "    - out/stx-r1/CentOS/pike/Binary/images/pxeboot/initrd.img"
echo "    - out/stx-r1/CentOS/pike/Binary/images/pxeboot/vmlinuz"

