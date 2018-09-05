#!/bin/bash -e
#
# SPDX-License-Identifier: Apache-2.0
#
# download RPMs/SRPMs from different sources.
# this script was originated by Brian Avery, and later updated by Yong Hu

set -o errexit
set -o nounset

# By default, we use "sudo" and we don't use a local yum.conf. These can
# be overridden via flags.

SUDOCMD="sudo -E"
RELEASEVER="--releasever=7"
YUMCONFOPT=""

source utils.sh

usage() {
    echo "$0 [-n] [-c <yum.conf>] <rpms_list> <match_level> "
    echo ""
    echo "Options:"
    echo "  -n: Do not use sudo when performing operations"
    echo "  -c: Use an alternate yum.conf rather than the system file"
    echo "  -x: Clean log files only, do not run."
    echo "  rpm_list: a list of RPM files to be downloaded."
    echo "  match_level: value could be L1, L2 or L3:"
    echo "    L1: use name, major version and minor version:"
    echo "        vim-7.4.160-2.el7 to search vim-7.4.160-2.el7.src.rpm"
    echo "    L2: use name and major version:"
    echo "        using vim-7.4.160 to search vim-7.4.160-2.el7.src.rpm"
    echo "    L3: use name:"
    echo "        using vim to search vim-7.4.160-2.el7.src.rpm"
    echo "    K1: Use Koji rather than yum repos as a source."
    echo "        Koji has a longer retention period than epel mirrors."
    echo ""
    echo "Returns: 0 = All files downloaded successfully"
    echo "         1 = Some files could not be downloaded"
    echo "         2 = Bad arguements or other error"
    echo ""
}


CLEAN_LOGS_ONLY=0
dl_rc=0

# Parse option flags
while getopts "c:nxh" o; do
    case "${o}" in
        n)
            # No-sudo
            SUDOCMD=""
            ;;
        x)
            # Clean only
            CLEAN_LOGS_ONLY=1
            ;;
        c)
            # Use an alternate yum.conf
            YUMCONFOPT="-c $OPTARG"
            RELEASEVER="--$(grep releasever= ${OPTARG})"
            ;;
        h)
            # Help
            usage
            exit 0
            ;;
        *)
            usage
            exit 2
            ;;
    esac
done
shift $((OPTIND-1))

if [ $# -lt 2 ]; then
    usage
    exit 2
fi

if [ "$1" == "" ]; then
    echo "Need to supply the rpm file list"
    exit 2;
else
    rpms_list=$1
    echo "using $rpms_list as the download name lists"
fi

match_level="L1"

if [ ! -z "$2" -a "$2" != " " ];then
    match_level=$2
fi

timestamp=$(date +%F_%H%M)
echo $timestamp

DESTDIR="output"
MDIR_SRC=$DESTDIR/stx-r1/CentOS/pike/Source
mkdir -p $MDIR_SRC
MDIR_BIN=$DESTDIR/stx-r1/CentOS/pike/Binary
mkdir -p $MDIR_BIN

LOGSDIR="logs"
from=$(get_from $rpms_list)
LOG="$LOGSDIR/${match_level}_failmoved_url_${from}.log"
MISSING_SRPMS="$LOGSDIR/${match_level}_srpms_missing_${from}.log"
MISSING_RPMS="$LOGSDIR/${match_level}_rpms_missing_${from}.log"
FOUND_SRPMS="$LOGSDIR/${match_level}_srpms_found_${from}.log"
FOUND_RPMS="$LOGSDIR/${match_level}_rpms_found_${from}.log"
cat /dev/null > $LOG
cat /dev/null > $MISSING_SRPMS
cat /dev/null > $MISSING_RPMS
cat /dev/null > $FOUND_SRPMS
cat /dev/null > $FOUND_RPMS


if [ $CLEAN_LOGS_ONLY -eq 1 ];then
    exit 0
fi

# Function to download different types of RPMs in different ways
download () {
    local _file=$1
    local _level=$2
    local _list=$(cat $_file)
    local _from=$(get_from $_file)

    local _arch=""

    local rc=0
    local download_cmd=""
    local download_url=""
    local rpm_name=""
    local SFILE=""

    echo "now the rpm will come from: $_from"
    for ff in $_list; do
        _arch=$(get_arch_from_rpm $ff)
        rpm_name="$(get_rpm_name $ff)"
        download_cmd="$(get_download_cmd $ff $_level)"
        dest_dir="$(get_dest_directory $_arch)"

        if [ ! -e $dest_dir/$rpm_name ]; then
            echo "Looking for $rpm_name"
            echo "--> run: $download_cmd"
            if $download_cmd ; then
                download_url="$(get_url $ff $_level)"
                SFILE="$(get_rpm_level_name $rpm_name $_level)"
                process_result "$_arch" "$dest_dir" "$download_url" "$SFILE"
            else
                echo "Warning: $rpm_name not found"
                echo "missing_srpm:$rpm_name" >> $LOG
                echo $rpm_name >> $MISSING_SRPMS
                rc=1
            fi
        else
            echo "Already have $dest_dir/$rpm_name"
            echo "already_there_srpm:$rpm_name" >> $LOG
        fi
        echo
    done

    return $rc
}


# Prime the cache
${SUDOCMD} yum ${YUMCONFOPT} ${RELEASEVER} makecache

# Download files
if [ -s "$rpms_list" ];then
    echo "--> start searching $rpms_list"
    download $rpms_list $match_level
    if [ $? -ne 0 ]; then
        dl_rc=1
    fi
fi

echo "Done!"

exit $dl_rc
