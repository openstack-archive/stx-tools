#!/bin/bash

#
# SPDX-License-Identifier: Apache-2.0
#
# Daily update script for mirror.starlingx.cengn.ca covering
# tarballs and other files not downloaded from a yum repository.
# This script was originated by Scott Little.
#
# IMPORTANT: This script is only to be run on the StarlingX mirror.
#            It is not for use by the general StarlinX developer.
#
# This script was originated by Scott Little.
#

DAILY_DL_SYNC_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}" )" )"

if [ -f "$DAILY_DL_SYNC_DIR/url_utils.sh" ]; then
    source "$DAILY_DL_SYNC_DIR/url_utils.sh"
elif [ -f "$DAILY_DL_SYNC_DIR/../url_utils.sh" ]; then
    source "$DAILY_DL_SYNC_DIR/../url_utils.sh"
else
    echo "Error: Can't find 'url_utils.sh'"
    exit 1
fi


LOGFILE=/export/log/daily_dl_sync.log
DOWNLOAD_PATH_ROOT=/export/mirror/centos

STX_TOOLS_BRANCH="master"
STX_TOOLS_BRANCH_ROOT_DIR="$HOME"
STX_TOOLS_GIT_URL="https://git.starlingx.io/stx-tools.git"
STX_TOOLS_OS_SUBDIR="centos-mirror-tools"

usage () {
    echo "$0 [-b <branch>] [-d <dir>]"
    echo ""
    echo "Options:"
    echo "  -b: Use an alternate branch of stx-tools. Default is 'master'."
    echo "  -d: Directory where we will clone stx-tools. Default is \$HOME."
    echo ""
}

while getopts "b:d:h" opt; do
    case "${opt}" in
        b)
            # branch
            STX_TOOLS_BRANCH="${OPTARG}"
            if [ $"STX_TOOLS_BRANCH" == "" ]; then
                usage
                exit 1
            fi
            ;;
        d)
            # download directory for stx-tools
            STX_TOOLS_BRANCH_ROOT_DIR="${OPTARG}"
            if [ "$STX_TOOLS_BRANCH_ROOT_DIR" == "" ]; then
                usage
                exit 1
            fi
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

STX_TOOLS_DL_ROOT_DIR="$STX_TOOLS_BRANCH_ROOT_DIR/$STX_TOOLS_BRANCH"
STX_TOOLS_DL_DIR="$STX_TOOLS_DL_ROOT_DIR/stx-tools"
LST_FILE_DIR="$STX_TOOLS_DL_DIR/$STX_TOOLS_OS_SUBDIR"

dl_git_from_url () {
    local GIT_URL="$1"
    local BRANCH="$2"
    local DL_DIR="$3"
    local DL_ROOT_DIR=""
    local SAVE_DIR
    local CMD=""

    SAVE_DIR="$(pwd)"

    if [ "$DL_DIR" == "" ]; then
        DL_DIR="$DOWNLOAD_PATH_ROOT/$(repo_url_to_sub_path "$GIT_URL" | sed 's#[.]git$##')"
    fi

    echo "dl_git_from_url  GIT_URL='$GIT_URL'  BRANCH='$BRANCH'  DL_DIR='$DL_DIR'"
    DL_ROOT_DIR=$(dirname "$DL_DIR")

    if [ ! -d "$DL_DIR" ]; then
        if [ ! -d "$DL_ROOT_DIR" ]; then
            CMD="mkdir -p '$DL_ROOT_DIR'"
            echo "$CMD"
            eval $CMD
            if [ $? -ne 0 ]; then
                echo "Error: $CMD"
                cd "$SAVE_DIR"
                return 1
            fi
        fi

        CMD="cd '$DL_ROOT_DIR'"
        echo "$CMD"
        eval $CMD
        if [ $? -ne 0 ]; then
            echo "Error: $CMD"
            cd "$SAVE_DIR"
            return 1
        fi

        CMD="git clone --bare '$GIT_URL' '$DL_DIR'"
        echo "$CMD"
        eval $CMD
        if [ $? -ne 0 ]; then
            echo "Error: $CMD"
            cd "$SAVE_DIR"
            return 1
        fi

        CMD="cd '$DL_DIR'"
        echo "$CMD"
        eval $CMD
        if [ $? -ne 0 ]; then
            echo "Error: $CMD"
            cd "$SAVE_DIR"
            return 1
        fi

        CMD="git --bare update-server-info"
        echo "$CMD"
        eval $CMD
        if [ $? -ne 0 ]; then
            echo "Error: $CMD"
            cd "$SAVE_DIR"
            return 1
        fi

        if [ -f hooks/post-update.sample ]; then
            CMD="mv -f hooks/post-update.sample hooks/post-update"
            echo "$CMD"
            eval $CMD
            if [ $? -ne 0 ]; then
                echo "Error: $CMD"
                cd "$SAVE_DIR"
                return 1
            fi
        fi
    fi

    CMD="cd '$DL_DIR'"
    echo "$CMD"
    eval $CMD
    if [ $? -ne 0 ]; then
        echo "Error: $CMD"
        cd "$SAVE_DIR"
        return 1
    fi

    CMD="git fetch"
    echo "$CMD"
    eval $CMD
    if [ $? -ne 0 ]; then
        echo "Error: $CMD"
        cd "$SAVE_DIR"
        return 1
    fi

    cd "$SAVE_DIR"
    return 0
}


dl_file_from_url () {
    local URL="$1"
    local DOWNLOAD_PATH=""
    local DOWNLOAD_DIR=""
    local PROTOCOL=""
    local CMD=""

    DOWNLOAD_PATH="$DOWNLOAD_PATH_ROOT/$(repo_url_to_sub_path "$URL")"
    DOWNLOAD_DIR="$(dirname "$DOWNLOAD_PATH")"
    PROTOCOL=$(url_protocol $URL)
    echo "$PROTOCOL  $URL  $DOWNLOAD_PATH"

    if [ -f "$DOWNLOAD_PATH" ]; then
        echo "Already have '$DOWNLOAD_PATH'"
        return 0
    fi

    case "$PROTOCOL" in
        https|http)
            if [ ! -d "$DOWNLOAD_DIR" ]; then
                CMD="mkdir -p '$DOWNLOAD_DIR'"
                echo "$CMD"
                eval "$CMD"
                if [ $? -ne 0 ]; then
                    echo "Error: $CMD"
                    return 1
                fi
            fi

            CMD="wget '$URL' --tries=5 --wait=15 --output-document='$DOWNLOAD_PATH'"
            echo "$CMD"
            eval $CMD
            if [ $? -ne 0 ]; then
                echo "Error: $CMD"
                return 1
            fi
            ;;
        *)
            echo "Error: Unknown protocol '$PROTOCOL' for url '$URL'"
            ;;
    esac

    return 0
}


raw_dl_from_rpm_lst () {
    local FILE="$1"
    local RPM=""
    local URL=""
    local ERROR_COUNT=0

    # Expected format <rpm>#<url>
    grep -v '^#' $FILE | while IFS='#' read -r RPM URL; do
        echo "Processing: RPM=$RPM  URL=$URL"
        dl_file_from_url "$URL"
        ERR_COUNT=$((ERR_COUNT+$?))
    done

    return $ERR_COUNT
}

raw_dl_from_non_rpm_lst () {
    local FILE="$1"
    local TAR=""
    local URL=""
    local METHOD=""
    local UTIL=""
    local SCRIPT=""
    local BRANCH=""
    local SUBDIRS_FILE=""
    local TARBALL_NAME=""
    local ERROR_COUNT=0

    # Expected format <tar-file>#<tar-dir>#<url>
    #          or     !<tar-file>#<tar-dir>#<url>#<method>#[<util>]#[<script>]
    grep -v '^#' $FILE | while IFS='#' read -r TAR DIR URL METHOD UTIL SCRIPT; do
        if [ "$URL" == "" ]; then
            continue
        fi

        echo "Processing: TAR=$TAR  DIR=$DIR  URL=$URL  METHOD=$METHOD  UTIL=$UTIL  SCRIPT=$SCRIPT"
        TARBALL_NAME="${TAR//!/}"
        if [[ "$TAR" =~ ^'!' ]]; then
            case $METHOD in
                http|http_script)
                    dl_file_from_url "$URL"
                    if [ $? -ne 0 ]; then
                        echo "Error: Failed to download '$URL' while processing '$TARBALL_NAME'"
                        ERR_COUNT=$((ERR_COUNT+1))
                    fi
                    ;;
                http_filelist|http_filelist_script)
                    SUBDIRS_FILE="$LST_FILE_DIR/$UTIL"
                    if [ ! -f "$SUBDIRS_FILE" ]; then
                        echo "$SUBDIRS_FILE no found" 1>&2
                        ERR_COUNT=$((ERR_COUNT+1))
                    fi

                    grep -v '^#' "$SUBDIRS_FILE" | while read -r ARTF; do
                        if [ "$ARTF" == "" ]; then
                            continue
                        fi

                        dl_file_from_url "$URL/$ARTF"
                        if [ $? -ne 0 ]; then
                            echo "Error: Failed to download artifact '$ARTF' from list '$SUBDIRS_FILE' while processing '$TARBALL_NAME'"
                            ERR_COUNT=$((ERR_COUNT+1))
                            break
                        fi
                    done
                    ;;
                git|git_script)
                    BRANCH="$UTIL"
                    dl_git_from_url "$URL" "$BRANCH" ""
                    if [ $? -ne 0 ]; then
                        echo "Error: Failed to download '$URL' while processing '$TARBALL_NAME'"
                        ERR_COUNT=$((ERR_COUNT+1))
                    fi
                    ;;
                *)
                    echo "Error: Unknown method '$METHOD' while processing '$TARBALL_NAME'"
                    ERR_COUNT=$((ERR_COUNT+1))
                    ;;
            esac
        else
            dl_file_from_url "$URL"
            if [ $? -ne 0 ]; then
                echo "Error: Failed to download '$URL' while processing '$TARBALL_NAME'"
                ERR_COUNT=$((ERR_COUNT+1))
            fi
        fi
    done

    return $ERR_COUNT
}


stx_tool_clone_or_update () {
    local CMD

    CMD="mkdir -p '$STX_TOOLS_DL_DIR'"
    echo "$CMD"
    eval "$CMD"
    if [ $? -ne 0 ]; then
        echo "Error: $CMD"
        return 1
    fi

    dl_git_from_url "$STX_TOOLS_GIT_URL" "$STX_TOOLS_BRANCH" "$STX_TOOLS_DL_DIR"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to download '$STX_TOOLS_GIT_URL'"
        return 1;
    fi
    return 0
}


if [ -f $LOGFILE ]; then
    rm -f $LOGFILE
fi

(
ERR_COUNT=0

stx_tool_clone_or_update
if [ $? -ne 0 ]; then
    echo "Error: Failed to update stx_tools. Can't continue."
    exit 1
fi

# At time of writing, only expect rpms_3rdparties.lst
RPM_LST_FILES=$(grep -l '://' $LST_FILE_DIR/rpms*.lst)

# At time of writing, only expect tarball-dl.lst
NON_RPM_FILES=$(grep -l '://' $LST_FILE_DIR/*lst | grep -v '[/]rpms[^/]*$')

for RPM_LST_FILE in $RPM_LST_FILES; do
    raw_dl_from_rpm_lst "$RPM_LST_FILE"
    ERR_COUNT=$((ERR_COUNT+$?))
done

for NON_RPM_FILE in $NON_RPM_FILES; do
    raw_dl_from_non_rpm_lst "$NON_RPM_FILE"
    ERR_COUNT=$((ERR_COUNT+$?))
done

if [ $ERR_COUNT -ne 0 ]; then
    echo "Error: Failed to download $ERR_COUNT files"
    exit 1
fi

exit 0
) | tee $LOGFILE

exit ${PIPESTATUS[0]}
