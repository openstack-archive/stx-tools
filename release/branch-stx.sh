#!/bin/bash
# branch-stx.sh - create STX branches based on today
#
# branch-stx.sh [<manifest>]
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
    git review -t "create-${branch}"
}

# branch_repo <repo-uri> <sha> <branch-base>
function branch_repo {
    local repo=$1
    local sha=$2
    local branch=$3
    local tag=$4

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

    cd -
}

for r in $REMOTES; do
    repos=$($script_dir/getrepo.sh $MANIFEST $r)
    # crap, convert github URLs to git:
    repos=$(sed -e 's|https://github.com/starlingx-staging|git@github.com:starlingx-staging|g' <<<$repos)
    for i in $repos; do
        branch_repo $i HEAD $BRANCH $TAG
        repo_dir=${i##*/}
        cd $repo_dir
        if [[ "$r" == "starlingx" ]]; then
            # Do the Gerrit way

            # set up gerrit remote
            git review -s

            # push
            git push gerrit $BRANCH

            update_gitreview $BRANCH
        else
            # Do the Github way
            # push
            git push --tags -u origin $BRANCH
        fi
        cd -
    done
done
