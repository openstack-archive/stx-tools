#!/usr/bin/env bash

# The StarlingX build process requires a group of source
# code tarballs to create an ISO image. However some of
# these tarballs need to be customized in order to use
# only the relevant parts.

BASE_TARBALLS=(
    "e6aef069b6e97790cb127d5eeb86ae9ff0b7b0e3.tar.gz"
    "mariadb-10.1.28.tar.gz"
    "MLNX_OFED_LINUX-4.2-1.2.0.0-rhel7.4-x86_64.tgz"
    "MLNX_OFED_LINUX-4.3-1.0.1.0-rhel7.4-x86_64.tgz"
    "MLNX_OFED_LINUX-4.3-3.0.2.1-rhel7.5-x86_64.tgz"
)
DOWNLOADS_PATH="output/stx-r1/CentOS/pike/downloads"

# MariaDB - Disable tokuft_logdump
function disable_tokuft_logdump()
{
    local tarball="$1"
    local dirname="mariadb-10.1.28"

    mkdir $dirname
    tar xf $tarball --strip-components 1 -C $dirname
    rm $tarball
    pushd $dirname
        rm -rf storage/tokudb
        rm ./man/tokuft_logdump.1 ./man/tokuftdump.1
        sed -e s/tokuft_logdump.1//g -i man/CMakeLists.txt
        sed -e s/tokuftdump.1//g -i man/CMakeLists.txt
    popd
    tar czvf $tarball $dirname
    rm -rf $dirname
}

# These tarballs include a serie of SRPMs, this function extracts
# them from tarballs.
function extract_mlnx_srpms()
{
    local tarball="$1"
    local pkg_version="$(echo "$tarball" | cut -d "-" -f2-3)"
    local srpm_path="MLNX_OFED_SRC-${pkg_version}/SRPMS/"
    local dirname="$(basename $tarball .tgz)"

    tar -xf "$tarball"
    tar -xf "$dirname/src/MLNX_OFED_SRC-${pkg_version}.tgz"

    # This section of code gets specific SRPMs versions according
    # to the OFED tarball version.
    if [ "$pkg_version" = "4.2-1.2.0.0" ]; then
        cp "$srpm_path/libibverbs-41mlnx1-OFED.4.2.1.0.6.42120.src.rpm" .
    elif [ "$pkg_version" = "4.3-1.0.1.0" ]; then
        cp "$srpm_path/mlnx-ofa_kernel-4.3-OFED.4.3.1.0.1.1.g8509e41.src.rpm" .
        cp "$srpm_path/rdma-core-43mlnx1-1.43101.src.rpm" .
        cp "$srpm_path/libibverbs-41mlnx1-OFED.4.3.0.1.8.43101.src.rpm" .
    elif [ "$pkg_version" = "4.3-3.0.2.1" ]; then
        cp "$srpm_path/mlnx-ofa_kernel-4.3-OFED.4.3.3.0.2.1.gcf60532.src.rpm" .
        cp "$srpm_path/rdma-core-43mlnx1-1.43302.src.rpm" .
        cp "$srpm_path/libibverbs-41mlnx1-OFED.4.3.2.1.6.43302.src.rpm" .
    else
        echo "$pkg_version : unknown version"
    fi

    # Don't delete the original MLNX_OFED_LINUX tarball.
    # We don't use it, but it will prevent re-downloading this file.
    # rm -f "$tarball_name"
    rm -rf "MLNX_OFED_SRC-${pkg_version}"
    rm -rf "$dirname"
}

# This function extracts some directories from the
# source code, and they are compressed as individual tarballs.
function extract_tpm_components()
{
    local tarball="$1"
    local dirname="linux-tpmdd-e6aef06"
    local integrity_module="integrity"
    local tpm_module="tpm"
    local integrity_tarball="integrity-kmod-e6aef069.tar.gz"
    local tpm_tarball="tpm-kmod-e6aef069.tar.gz"

    tar xf "$tarball"
    mv $dirname/security/integrity/ $integrity_module
    mv $dirname/drivers/char/tpm  $tpm_module

    # compress tpm sub-modules
    tar czvf $integrity_tarball $integrity_module
    tar czvf $tpm_tarball $tpm_module
    rm -rf $dirname
}

# This function creates a tarball using a github
# repository and making checkout to an specific
# version (V930).
function create_tss_tarball()
{
    local tarball="tss2-930.tar.gz"
    local projectdir="tss2-930"
    local tss_repo="https://git.code.sf.net/p/ibmtpm20tss/tss"
    local tss_version="v930"

    git clone $tss_repo $projectdir
    pushd $projectdir
        git checkout $tss_version
        rm -rf .git
    popd
    tar czvf $tarball $projectdir
    rm -rf $projectdir
}

function main()
{
    cd "$DOWNLOADS_PATH"
    for TARBALL in "${BASE_TARBALLS[@]}"; do
        if [ ! -f "$TARBALL" ]; then
            echo "error: $TARBALL no found!" >&2
            continue
        fi

        if [ "$TARBALL" = "mariadb-10.1.28.tar.gz" ]; then
            disable_tokuft_logdump "$TARBALL"
        fi

        if [[ "$TARBALL" =~ ^'MLNX_OFED_LINUX' ]]; then
            extract_mlnx_srpms "$TARBALL"
        fi

        if [ "$TARBALL" = "e6aef069b6e97790cb127d5eeb86ae9ff0b7b0e3.tar.gz" ]; then
            extract_tpm_components "$TARBALL"
        fi
    done

    create_tss_tarball
}

main "$@"
