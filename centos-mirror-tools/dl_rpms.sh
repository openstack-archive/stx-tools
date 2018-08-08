#!/bin/bash -e
#
# SPDX-License-Identifier: Apache-2.0
#
# download RPMs/SRPMs from different sources.
# this script was originated by Brian Avery, and later updated by Yong Hu

usage() {
    echo "$0 [-n] [-c <yum.conf>] <rpms_list> <match_level> "
    echo ""
    echo "Options:"
    echo "  -n: Do not use sudo when performing operations"
    echo "  -c: Use an alternate yum.conf rather than the system file"
    echo "  rpm_list: a list of RPM files to be downloaded."
    echo "  match_level: value could be L1, L2 or L3:"
    echo "    L1: use name, major version and minor version:"
    echo "        vim-7.4.160-2.el7 to search vim-7.4.160-2.el7.src.rpm"
    echo "    L2: use name and major version:"
    echo "        using vim-7.4.160 to search vim-7.4.160-2.el7.src.rpm"
    echo "    L3: use name:"
    echo "        using vim to search vim-7.4.160-2.el7.src.rpm"
    echo ""
}

get_from() {
    list=$1
    base=$(basename $list .lst)
    from=$(echo $base | cut -d'_' -f2-2)
    echo $from
}

# By default, we use "sudo" and we don't use a local yum.conf. These can
# be overridden via flags.
SUDOCMD="sudo -E"
YUMCONFOPT=""

# Parse option flags
while getopts "c:nh" o; do
    case "${o}" in
        n)
            # No-sudo
            SUDOCMD=""
            ;;
        c)
            # Use an alternate yum.conf
            YUMCONFOPT="-c $OPTARG"
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

if [ $# -lt 2 ]; then
    usage
    exit -1
fi

if [ "$1" == "" ]; then
    echo "Need to supply the rpm file list"
    exit -1;
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


from=$(get_from $rpms_list)
FAIL_MOVE_SRPMS="$DESTDIR/${from}_srpms_fail_move_${match_level}.txt"
FOUND_SRPMS="$DESTDIR/${from}_srpms_found_${match_level}.txt"
MISSING_SRPMS="$DESTDIR/${from}_srpms_missing_${match_level}.txt"
URL_SRPMS="$DESTDIR/${from}_srpms_urls_${match_level}.txt"

cat /dev/null > $FAIL_MOVE_SRPMS
cat /dev/null > $FOUND_SRPMS
cat /dev/null > $MISSING_SRPMS
cat /dev/null > $URL_SRPMS

FAIL_MOVE_RPMS="$DESTDIR/${from}_rpms_fail_move_${match_level}.txt"
FOUND_RPMS="$DESTDIR/${from}_rpms_found_${match_level}.txt"
MISSING_RPMS="$DESTDIR/${from}_rpms_missing_${match_level}.txt"
URL_RPMS="$DESTDIR/${from}_rpms_urls_${match_level}.txt"

cat /dev/null > $FAIL_MOVE_RPMS
cat /dev/null > $FOUND_RPMS
cat /dev/null > $MISSING_RPMS
cat /dev/null > $URL_RPMS

#function to download different type of RPMs in different ways
download () {
    _file=$1
    _level=$2
    _list=$(cat $_file)
    _from=$(get_from $_file)
    echo "now the rpm will come from: $_from"
    for ff in $_list; do
        _type=$(echo $ff | rev | cut -d'.' -f2-2 | rev)
        ## download RPM from CentOS repos
        if [ "$_from" == "centos" -o "$_from" == "centos3rdparties" ]; then
            rpm_name=$ff
            if [ $_level == "L1" ]; then
                SFILE=`echo $rpm_name | rev | cut -d'.' -f3- | rev`
            elif [ $match_level == "L2" ];then
                SFILE=`echo $rpm_name | rev | cut -d'-' -f2- | rev`
            else
                SFILE=`echo $rpm_name | rev | cut -d'-' -f3- | rev`
            fi
            echo " ------ using $SFILE to search $rpm_name ------"
            if [ "$_type" == "src" ];then
                download_cmd="${SUDOCMD} yumdownloader -q ${YUMCONFOPT} -C --source $SFILE"
                download_url_cmd="${SUDOCMD} yumdownloader --urls -q ${YUMCONFOPT}-C --source $SFILE"
            else
                download_cmd="${SUDOCMD} yumdownloader -q -C ${YUMCONFOPT} $SFILE --archlist=noarch,x86_64"
                download_url_cmd="${SUDOCMD} yumdownloader --urls -q -C ${YUMCONFOPT} $SFILE --archlist=noarch,x86_64"
            fi
        else
            rpm_name=`echo $ff | cut -d"#" -f1-1`
            rpm_url=`echo $ff | cut -d"#" -f2-2`
            download_cmd="wget $rpm_url"
            SFILE=$rpm_name
        fi
        echo "--> run: $download_cmd"
        if [ "$_type" == "src" ]; then
            if [ ! -e $MDIR_SRC/$rpm_name ]; then
                echo "Looking for $rpm_name"
                if $download_cmd ; then
                    # Success!   Record download URL.
                    # Use 'sort --unique' because sometimes
                    # yumdownloader reports the url twice
                    $download_url_cmd | sort --unique >> $URL_SRPMS

                    if ! mv -f $SFILE* $MDIR_SRC ; then
                        echo "FAILED to move $rpm_name"
                        echo $rpm_name >> $FAIL_MOVE_SRPMS
                    fi
                    echo $rpm_name >> $FOUND_SRPMS
                else
                    echo $rpm_name >> $MISSING_SRPMS
                fi
            else
                echo "Already have ${MDIR_BIN}/${_type}/$rpm_name"
                echo $rpm_name >> $FOUND_SRPMS
            fi
        else  ## noarch or x86_64
            if [ ! -e ${MDIR_BIN}/${_type}/$rpm_name ]; then
                echo "Looking for $rpm_name..."
                if $download_cmd ; then
                    # Success!   Record download URL.
                    # Use 'sort --unique' because sometimes 
                    # yumdownloader reports the url twice
                    $download_url_cmd | sort --unique >> $URL_RPMS

                    mkdir -p $MDIR_BIN/${_type}
                    if ! mv -f $SFILE* $MDIR_BIN/${_type}/ ; then
                        echo "FAILED to move $rpm_name"
                        echo $rpm_name >> $FAIL_MOVE_RPMS
                    fi
                    echo $rpm_name >> $FOUND_RPMS
                else
                    echo $rpm_name >> $MISSING_RPMS
                fi
            else
                echo "Already have ${MDIR_BIN}/${_type}/$rpm_name"
                echo $rpm_name >> $FOUND_RPMS
            fi
        fi
    done
}

# prime the cache
${SUDOCMD} yum ${YUMCONFOPT} makecache

# download files
if [ -s "$rpms_list" ];then
    echo "--> start searching "$rpms_list
    download $rpms_list $match_level
fi

echo "done!!"

exit 0
