#!/bin/bash

#
# SPDX-License-Identifier: Apache-2.0
#
# Daily update script for mirror.starlingx.cengn.ca covering
# rpms and src.rpms dowloaded from a yum repository.
#
# Configuration files for repositories to be downloaded are currently
# stored at mirror.starlingx.cengn.ca:/export/config/yum.repos.d.
# Those repos were derived from stx-tools/centos-mirror-tools/yum.repos.d
# with some modifications that will need to be automated in a
# future update.
#
# This script was originated by Scott Little.
#

LOGFILE="/export/log/repo_update.log"
YUM_CONF_DIR="/export/config"
YUM_REPOS_DIR="$YUM_CONF_DIR/yum.repos.d"
DOWNLOAD_PATH_ROOT="/export/mirror/centos"

DAILY_CENTOS_SYNC_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}" )" )"

if [ -f "$DAILY_CENTOS_SYNC_DIR/url_utils.sh" ]; then
    source "$DAILY_CENTOS_SYNC_DIR/url_utils.sh"
elif [ -f "$DAILY_CENTOS_SYNC_DIR/../url_utils.sh" ]; then
    source "$DAILY_CENTOS_SYNC_DIR/url_utils.sh"
else
    echo "Error: Can't find 'url_utils.sh'"
    exit 1
fi

CREATEREPO=$(which createrepo_c)
if [ $? -ne 0 ]; then
   CREATEREPO="createrepo"
fi

number_of_cpus () {
    /usr/bin/nproc
}

if [ -f $LOGFILE ]; then
    rm -f $LOGFILE
fi

ERR_COUNT=0
YUM_CONF="$YUM_CONF_DIR/yum.conf"
if [ ! -f "$YUM_CONF" ]; then
    echo "Error: Missing yum.conf file at '$YUM_CONF'"
    exit 1
fi

for REPO in $(find $YUM_REPOS_DIR -name '*.repo'); do
    for REPO_ID in $(grep '^[[]' $REPO | sed 's#[][]##g'); do

        REPO_URL=$(yum repoinfo --config="$YUM_CONF"  --disablerepo="*" --enablerepo="$REPO_ID" | grep Repo-baseurl | cut -d ' ' -f 3)
        DOWNLOAD_PATH="$DOWNLOAD_PATH_ROOT/$(repo_url_to_sub_path "$REPO_URL")"

        echo "Processing: REPO=$REPO  REPO_ID=$REPO_ID  REPO_URL=$REPO_URL  DOWNLOAD_PATH=$DOWNLOAD_PATH"

        # Assume it's a repo of binary rpms unless repoid ends in
        # some variation of 'source'.
        SOURCE_FLAG=""
        echo "$REPO_ID" | grep -q '\[-_][Ss]ource$' && SOURCE_FLAG="--source"
        echo "$REPO_ID" | grep -q '\[-_][Ss]ources$' && SOURCE_FLAG="--source"

        if [ ! -d "$DOWNLOAD_PATH" ]; then
            CMD="mkdir -p '$DOWNLOAD_PATH'"
            echo "$CMD"
            eval $CMD
            if [ $? -ne 0 ]; then
                echo "Error: $CMD"
                ERR_COUNT=$((ERR_COUNT+1))
                continue
            fi
        fi

        CMD="reposync --norepopath $SOURCE_FLAG -l --config=$YUM_CONF --repoid=$REPO_ID --download_path='$DOWNLOAD_PATH'"
        echo "$CMD"
        eval $CMD
        if [ $? -ne 0 ]; then
            echo "Error: $CMD"
            ERR_COUNT=$((ERR_COUNT+1))
            continue
        fi

        CMD="pushd '$DOWNLOAD_PATH'"
        echo "$CMD"
        eval $CMD
        if [ $? -ne 0 ]; then
            echo "Error: $CMD"
            ERR_COUNT=$((ERR_COUNT+1))
            continue
        fi

        OPTIONS="--workers $(number_of_cpus)"
        if [ -f comps.xml ]; then
            OPTIONS="$OPTIONS -g comps.xml"
        fi
        if [ -d repodata ]; then 
            OPTIONS="$OPTIONS --update"
        fi

        CMD="$CREATEREPO $OPTIONS ."
        echo "$CMD"
        eval $CMD
        if [ $? -ne 0 ]; then
            echo "Error: $CMD"
            ERR_COUNT=$((ERR_COUNT+1))
            popd
            continue
        fi

        popd
    done
done | tee $LOGFILE

if [ $ERR_COUNT -ne 0 ]; then
    exit 1
fi

exit 0
