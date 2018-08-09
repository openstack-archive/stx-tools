#!/bin/bash
# branch-stx.sh - create STX branches based on today
#
# branch-stx.sh [--dry-run] [<manifest>]
#
# * get the repo list from stx-manifest in both starlingx and stx-staging remotes
# * create a new branch
# * tag the new branch with an initial release identifier
#
# Some environment variables are available for modifying this script's behaviour:
#
# SERIES is the base of the branch and tag names, similar to how it is used
# in OpenStack branch names.  StarlingX formats SERIES based on year and month
# as YYYY.MM although that is only a convention, no tooling assumes that format.
#
# BRANCH is the actual branch name, derived by adding 'm/' (for milestones) or
# 'r/' (for periodic releases) to SERIES.
#
# TAG is the release tag that represents the actual release, derived by adding
# a 'patch' version to SERIES, initially '0'.

set -e

# Grab options
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=1
    shift;
fi

# Where to get the repo list
MANIFEST=${1:-default.xml}

# SERIES is the base of the branch and release tag names: year.month (YYYY.MM)
SERIES=${SERIES:-$(date '+%Y.%m')}

# branch: m/YYYY.MM
BRANCH=${BRANCH:-m/$SERIES}

# tag: YYYY.MM.0
TAG=${TAG:-$SERIES.0}

# The list of remotes to extract from MANIFEST
REMOTES="starlingx stx-staging"

# This is where other scripts live that we need
script_dir=$(realpath $(dirname $0))

# update_gitreview <branch>
# Based on update_gitreview() from https://github.com/openstack/releases/blob/a7db6cf156ba66d50e1955db2163506365182ee8/tools/functions#L67
function update_gitreview {
    typeset branch="$1"

    git checkout $branch
    # Remove a trailing newline, if present, to ensure consistent
    # formatting when we add the defaultbranch line next.
    typeset grcontents="$(echo -n "$(cat .gitreview | grep -v defaultbranch)")
defaultbranch=$branch"
    echo "$grcontents" > .gitreview
    git add .gitreview
    git commit -s -m "Update .gitreview for $branch"
    git show
    if [[ -z $DRY_RUN ]]; then
        git review -t "create-${branch}"
    else
        echo "### skipping review submission to $branch"
    fi
}

# branch_repo <remote> <repo-uri> <sha> <branch-base>
function branch_repo {
    local remote=$1
    local repo=$2
    local sha=$3
    local branch=$4
    local tag=$5

    local repo_dir=${repo##*/}

    if [[ ! -d $repo_dir ]]; then
        git clone $i $repo_dir || true
    fi

    cd $repo_dir
    git checkout master

    if ! git branch | grep $BRANCH; then
        # create branch
        git branch $branch $sha
    fi

    # tag branch point at $sha
    git tag -f $tag $sha

    # Push the new goodness back up
    if [[ "$r" == "starlingx" ]]; then
        # Do the Gerrit way

        # set up gerrit remote
        git review -s

        # push
        if [[ -z $DRY_RUN ]]; then
            git push gerrit $branch
        else
            echo "### skipping push to $branch"
        fi

        update_gitreview $branch
    else
        # Do the Github way
        # push
        if [[ -z $DRY_RUN ]]; then
            git push --tags -u origin $branch
        else
            echo "### skipping push to $branch"
        fi
    fi

    cd -
}

for r in $REMOTES; do
    repos=$($script_dir/getrepo.sh $MANIFEST $r)
    # crap, convert github URLs to git:
    repos=$(sed -e 's|https://github.com/starlingx-staging|git@github.com:starlingx-staging|g' <<<$repos)
    for i in $repos; do
        branch_repo $r $i HEAD $BRANCH $TAG
    done
done
