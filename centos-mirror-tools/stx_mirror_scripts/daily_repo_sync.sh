#!/bin/bash

#
# SPDX-License-Identifier: Apache-2.0
#
# Daily update script for mirror.starlingx.cengn.ca covering
# rpms and src.rpms downloaded from a yum repository.
#
# IMPORTANT: This script is only to be run on the StarlingX mirror.
#            It is not for use by the general StarlinX developer.
#
# Configuration files for repositories to be downloaded are currently
# stored at mirror.starlingx.cengn.ca:/export/config/yum.repos.d.
# Those repos were derived from stx-tools/centos-mirror-tools/yum.repos.d
# with some modifications that will need to be automated in a
# future update.
#
# This script was originated by Scott Little.
#

LOGFILE="/export/log/daily_repo_sync.log"
YUM_CONF_DIR="/export/config"
YUM_REPOS_DIR="$YUM_CONF_DIR/yum.repos.d"
DOWNLOAD_PATH_ROOT="/export/mirror/centos"
URL_UTILS="url_utils.sh"

# These variables drive the download of the centos installer
# and other non-repo files found under the os/x86_64 subdirectory.
OS_PATH_PREFIX=/export/mirror/centos/centos
OS_PATH_SUFFIX=os/x86_64
OS_FILES="EULA GPL"
OS_DIRS="EFI LiveOS images isolinux"

DAILY_REPO_SYNC_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}" )" )"

if [ -f "$DAILY_REPO_SYNC_DIR/$URL_UTILS" ]; then
    source "$DAILY_REPO_SYNC_DIR/$URL_UTILS"
elif [ -f "$DAILY_REPO_SYNC_DIR/../$URL_UTILS" ]; then
    source "$DAILY_REPO_SYNC_DIR/../$URL_UTILS"
else
    echo "Error: Can't find '$URL_UTILS'"
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
        echo "$REPO_ID" | grep -q '[-_][Ss]ource$' && SOURCE_FLAG="--source"
        echo "$REPO_ID" | grep -q '[-_][Ss]ources$' && SOURCE_FLAG="--source"
        echo "$REPO_ID" | grep -q '[-_][Ss]ource[-_]' && SOURCE_FLAG="--source"
        echo "$REPO_ID" | grep -q '[-_][Ss]ources[-_]' && SOURCE_FLAG="--source"

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

        # The following will download the centos installer and other non-repo
        # files and directories found under the os/x86_64 subdirectory.
        if [[ "$DOWNLOAD_PATH" == "$OS_PATH_PREFIX"/*/"$OS_PATH_SUFFIX" ]]; then
            for f in $OS_FILES; do
                CMD="wget '$REPO_URL/$f' --output-document='$DOWNLOAD_PATH/$f'"
                echo "$CMD"
                eval $CMD
                if [ $? -ne 0 ]; then
                    echo "Error: $CMD"
                    ERR_COUNT=$((ERR_COUNT+1))
                    continue
                fi
            done

            for d in $OS_DIRS; do
                CMD="wget -r -N -l 3 -nv -np -e robots=off --reject-regex '.*[?].*' --reject index.html '$REPO_URL/$d/' -P '$OS_PATH_PREFIX/'"
                echo "$CMD"
                eval $CMD
                if [ $? -ne 0 ]; then
                    echo "Error: $CMD"
                    ERR_COUNT=$((ERR_COUNT+1))
                    continue
                fi
            done
        fi

        popd
    done
done | tee $LOGFILE

if [ $ERR_COUNT -ne 0 ]; then
    exit 1
fi

exit 0
