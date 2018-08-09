#!/bin/bash -e
# download RPMs/SRPMs from different sources.
# this script was originated by Brian Avery, and later updated by Yong Hu

if [ $# -lt 3 ]; then
    echo "$0 <rpms_list> <match_level> <from_where>"
    echo "rpm_list: a list of RPM files to be downloaded."
    echo "match_level: value could be L1, L2 or L3:"
    echo "  L1: use name, major version and minor version:"
    echo "      vim-7.4.160-2.el7 to search vim-7.4.160-2.el7.src.rpm"
    echo "  L2: use name and major version:"
    echo "      using vim-7.4.160 to search vim-7.4.160-2.el7.src.rpm"
    echo "  L3: use name:"
    echo "      using vim to search vim-7.4.160-2.el7.src.rpm"
    echo "  K1: Use Koji rather than yum repos as a source."
    echo "      Koji has a longer retention period than epel mirrors."
    echo "from_where: where to download the RPMs: 'centos'from CentOS Repos,"
    echo "otherwise from 3rd-party websets"
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

from=$3

timestamp=$(date +%F_%H%M)
echo $timestamp

DESTDIR="output"
MDIR_SRC=$DESTDIR/stx-r1/CentOS/pike/Source
mkdir -p $MDIR_SRC
MDIR_BIN=$DESTDIR/stx-r1/CentOS/pike/Binary
mkdir -p $MDIR_BIN

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
    _list=$1
    _level=$2
    _from=$3
    _type=$4

    echo "now the rpm will come from: $_from"
    for ff in $_list; do
        ## download RPM from CentOS repos
        download_cmd=""
        download_url_cmd=""
        if [ "$_from" == "centos" -o "$_from" == "3rd-centos" ]; then
            rpm_name=$ff
            if [ $_level == "K1" ]; then
                SFILE=`echo $rpm_name | rev | cut -d'.' -f3- | rev`
                download_cmd="wget $(./koji_url.py $rpm_name)"
                download_url_cmd="echo $(./koji_url.py $rpm_name)"
            else
                if [ $_level == "L1" ]; then
                    SFILE=`echo $rpm_name | rev | cut -d'.' -f3- | rev`
                elif [ $match_level == "L2" ];then
                    SFILE=`echo $rpm_name | rev | cut -d'-' -f2- | rev`
                else
                    SFILE=`echo $rpm_name | rev | cut -d'-' -f3- | rev`
                fi
                echo " ------ using $SFILE to search $rpm_name ------"
                if [ "$_type" == "src" ];then
                    download_cmd="sudo -E yumdownloader -q -C --source $SFILE"
                    download_url_cmd="sudo -E yumdownloader --urls -q -C --source $SFILE"
                else
                    download_cmd="sudo -E yumdownloader -q -C $SFILE --archlist=noarch,x86_64"
                    download_url_cmd="sudo -E yumdownloader --urls -q -C $SFILE --archlist=noarch,x86_64"
                fi
            fi
        else
            rpm_name=`echo $ff | cut -d"#" -f1-1`
            rpm_url=`echo $ff | cut -d"#" -f2-2`
            shell_download_cmd="wget $rpm_url"
            SFILE=$rpm_name
        fi
        if [ "$_type" == "src" ]; then
            if [ ! -e $MDIR_SRC/$rpm_name ]; then
                echo "Looking for $rpm_name"
                echo "--> run: $download_cmd"
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
                echo "Already have ${MDIR_SRC}/${_type}/$rpm_name"
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
sudo -E yum makecache

#go to download *.noarch.rpm files
noarch_rpms=`echo "$(cat $rpms_list | grep '.noarch.rpm')"`
if [ ! -z "$noarch_rpms" ];then
    echo "--> start searching noarch RPMs ....."
    download "$noarch_rpms" $match_level $from "noarch"
fi

#go to download *.x86_64.rpm files
x86_64_rpms=`echo "$(cat $rpms_list | grep '.x86_64.rpm')"`
if [ ! -z "$x86_64_rpms" ];then
    echo "--> start searching x86_64 RPMs ....."
    download "$x86_64_rpms" $match_level $from "x86_64"
fi

#go to download *.src.rpm files
src_rpms=`echo "$(cat $rpms_list | grep '.src.rpm')"`
if [ ! -z "$src_rpms" ];then
    echo "--> start searching source RPMs ....."
    download "$src_rpms" $match_level $from "src"
fi

echo "done!!"

exit 0
