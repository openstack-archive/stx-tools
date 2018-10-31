#!/bin/bash

#
# SPDX-License-Identifier: Apache-2.0
#

#
# Replicate a yum.conf and yum.repo.d under a temporary directory and
# then modify the files to point to equivalent repos in the StarlingX mirror.
# This script was originated by Scott Little
#

MAKE_CENGN_YUM_CONF_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}" )" )"

source "$MAKE_CENGN_YUM_CONF_DIR/url_utils.sh"

DISTRO="centos"

TEMP_DIR=""
SRC_REPO_DIR="$MAKE_CENGN_YUM_CONF_DIR/yum.repos.d"
SRC_YUM_CONF="$MAKE_CENGN_YUM_CONF_DIR/yum.conf.sample"

RETAIN_REPODIR=0

usage () {
    echo ""
    echo "$0 -d <dest_dir> [-D <distro>] [-y <src_yum_conf>] [-r <src_repos_dir>] [-R]"
    echo ""
}

while getopts "D:d:Rr:y:" o; do
    case "${o}" in
        D)
            DISTRO="${OPTARG}"
            ;;
        d)
            TEMP_DIR="${OPTARG}"
            ;;
        r)
            SRC_REPO_DIR="${OPTARG}"
            ;;
        R)
            RETAIN_REPODIR=1
            ;;
        y)
            SRC_YUM_CONF="${OPTARG}"
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

if [ ! -f $SRC_YUM_CONF ]; then
    echo "Error: yum.conf not found at '$SRC_YUM_CONF'"
    exit 1
fi

if [ ! -d $SRC_REPO_DIR ]; then
    echo "Error: repo dir not found at '$SRC_REPO_DIR'"
    exit 1
fi

if [ "$TEMP_DIR" == "" ]; then
    echo "Error: working dir not provided"
    usage
    exit 1
fi

if [ ! -d $TEMP_DIR ]; then
    echo "Error: working dir not found at '$TEMP_DIR'"
    exit 1
fi

get_releasever () {
    yum version nogroups | grep Installed | cut -d ' ' -f 2 | cut -d '/' -f 1
}

get_arch () {
    yum version nogroups | grep Installed | cut -d ' ' -f 2 | cut -d '/' -f 2
}

CENGN_REPOS_DIR="$TEMP_DIR/yum.repos.d"
CENGN_YUM_CONF="$TEMP_DIR/yum.conf"
CENGN_YUM_LOG="$TEMP_DIR/yum.log"
CENGN_YUM_CACHDIR="$TEMP_DIR/cache/yum/\$basearch/\$releasever"

RELEASEVER=$(get_releasever)
ARCH=$(get_arch)

echo "\cp -r '$SRC_REPO_DIR' '$CENGN_REPOS_DIR'"
\cp -r "$SRC_REPO_DIR" "$CENGN_REPOS_DIR"
echo "\cp '$SRC_YUM_CONF' '$CENGN_YUM_CONF'"
\cp "$SRC_YUM_CONF" "$CENGN_YUM_CONF"

if grep -q '^reposdir=' $TEMP_DIR/yum.conf; then
    if [ $RETAIN_REPODIR -eq 1 ]; then
        sed "s#^reposdir=.*\$#reposdir=$CENGN_REPOS_DIR#" -i $TEMP_DIR/yum.conf 
    else
        sed "s#^reposdir=.*\$#reposdir=\1 $CENGN_REPOS_DIR#" -i $TEMP_DIR/yum.conf 
    fi
else
    if [ $RETAIN_REPODIR -eq 1 ]; then
        echo "reposdir=$SRC_REPO_DIR $CENGN_REPOS_DIR" >> $TEMP_DIR/yum.conf
    else
        echo "reposdir=$CENGN_REPOS_DIR" >> $TEMP_DIR/yum.conf
    fi
fi

sed "s#^logfile=.*\$#logfile=$CENGN_YUM_LOG#" -i $TEMP_DIR/yum.conf 
sed "s#^cachedir=.*\$#cachedir=$CENGN_YUM_CACHDIR#" -i $TEMP_DIR/yum.conf 

for REPO in $(find "$CENGN_REPOS_DIR" -type f -name '*repo'); do
    if grep -q '^mirrorlist=' "$REPO" ; then
        sed '/^mirrorlist=/d' -i "$REPO"
        sed 's%^#baseurl%baseurl%' -i "$REPO"
    fi

    sed "s#/[$]releasever/#/$RELEASEVER/#g" -i "$REPO"
    sed "s#/[$]basearch/#/$ARCH/#g" -i "$REPO"
    sed 's#^gpgcheck=1#gpgcheck=0#' -i "$REPO"
    sed '/^gpgkey=/d' -i "$REPO"
    for URL in $(grep '^baseurl=' "$REPO" | sed 's#^baseurl=##'); do
        CENGN_URL="$(url_to_cengn_url "$URL" "$DISTRO")"
        sed "s#^baseurl=$URL\$#baseurl=$CENGN_URL#" -i "$REPO"
    done
    sed "s#^name=\(.*\)#name=CENGN_\1#" -i "$REPO"
    sed "s#^\[\([^]]*\)\]#[CENGN_\1]#" -i "$REPO"
done

echo $TEMP_DIR
