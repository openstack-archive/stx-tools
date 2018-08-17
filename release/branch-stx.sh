#!/bin/bash
# branch-stx.sh - create STX branches
#
# branch-stx.sh [--dry-run|-n] [-l] [-m <manifest>] [<repo-url> ...]
#
# --dry-run|-n      Do all work except pushing back to the remote repo.
#                   Useful to validate everything locally before pushing.
#
# -l                List the repo URLS that would be processed and exit
#
# -m <manifest>     Extract the repo list from <manifest> for starlingx
#                   and stx-staging remotes
#
# <repo-url>        Specify one or more direct repo URLs to branch (ie git remote)
#                   These are appended to the list of repos extracted from the
#                   manifest if one is specified.
#
# For each repo:
# * create a new branch $BRANCH
# * tag the new branch with an initial release identifier if $TAG is set
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
# a 'patch' version to SERIES, initially '0'. If TAG is unset no tag is created.
#
# Notes:
# * This script is used for creating milestone, release and feature branches.
# * The default action is to create a milestone branch with prefix 'm/'.
# * To create a release branch set BRANCH directly using a 'r/' prefix.
# * To create a feature branch set BRANCH directly using a 'f/' prefix and set
#   TAG="" to skip tagging the branch point.

set -e

# Defaults
MANIFEST=""

optspec="lm:n-:"
while getopts "$optspec" o; do
    case "${o}" in
        # Hack in longopt support
        -)
            case "${OPTARG}" in
                dry-run)
                    DRY_RUN=1
                    ;;
                *)
                    if [[ "$OPTERR" = 1 ]] && [[ "${optspec:0:1}" != ":" ]]; then
                        echo "Unknown option --${OPTARG}" >&2
                    fi
                    ;;

            esac
            ;;
        l)
            LIST=1
            ;;
        m)
            MANIFEST=${OPTARG}
            ;;
        n)
            DRY_RUN=1
            ;;
    esac
done
shift $((OPTIND-1))

# See if we can build a repo list
if [[ $# == 0 && -z $MANIFEST ]]; then
    echo "ERROR: No repos to process"
    echo "Usage: $0 [--dry-run|-n] [-l] [-m <manifest>] [<repo-url> ...]"
    exit 1
fi

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
    if ! git commit -s -m "Update .gitreview for $branch"; then
        if [[ -z $DRY_RUN ]]; then
            git review -t "create-${branch}"
        else
            echo "### skipping .gitreview submission to $branch"
        fi
    else
        echo "### no changes required for .gitreview"
    fi
}

# branch_repo <repo-uri> <sha> <branch-base>
function branch_repo {
    local repo=$1
    local sha=$2
    local branch=$3
    local tag=$4

    local repo_dir=${repo##*/}

    if [[ ! -d $repo_dir ]]; then
        git clone $repo $repo_dir || true
    fi

    cd $repo_dir
    git checkout master

    if ! git branch | grep $BRANCH; then
        # create branch
        git branch $branch $sha
    fi

    if [[ -n $tag ]]; then
        # tag branch point at $sha
        git tag -f $tag $sha
    fi

    # Push the new goodness back up
    if [[ "$repo" =~ "git.starlingx.io" ]]; then
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

repo_list=""

if [[ -n $MANIFEST ]]; then
    # First get repos from the manifest
    for r in $REMOTES; do
        repos=$($script_dir/getrepo.sh $MANIFEST $r)
        # crap, convert github URLs to git:
        repos=$(sed -e 's|https://github.com/starlingx-staging|git@github.com:starlingx-staging|g' <<<$repos)
        repo_list+=" $repos"
    done
fi

if [[ $# != 0 ]]; then
    # Then add whatever is on the command line
    repo_list+=" $@"
fi

for i in $repo_list; do
    if [[ -z $LIST ]]; then
        branch_repo $i HEAD $BRANCH $TAG
    else
        echo "$i"
    fi
done
