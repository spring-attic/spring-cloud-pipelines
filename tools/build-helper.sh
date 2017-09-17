#!/bin/bash

[[ -z $DEBUG ]] || set -o xtrace

set -o errexit
set -o errtrace
set -o nounset
set -o pipefail

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function usage {
    echo "usage: $0: <download-shellcheck|download-bats|initialize-submodules>"
    exit 1
}

if [[ $# -ne 1 ]]; then
    usage
fi

case $1 in
    download-shellcheck)
        if [[ "${OSTYPE}" == linux* ]]; then
            SHELLCHECK_VERSION="v0.4.6"
            SHELLCHECK_ARCHIVE="shellcheck-${SHELLCHECK_VERSION}.linux.x86_64.tar.xz"
            SHELLCHECK_ARCHIVE_SHA512SUM="d9ac3e4fb2383b2d6862415e8052459ce24fd5402806b9ce739990d5c1cccebe4121288df29de32dcef5daa115874ddf7f9730de256bf134ee11cd9704aaa64c"
            if [[ -x "${ROOT_DIR}/../common/build/shellcheck-${SHELLCHECK_VERSION}/shellcheck" ]]; then
                echo "shellcheck already downloaded - skipping..."
                exit 0
            fi
            wget -P "${ROOT_DIR}/../build/" \
                "https://storage.googleapis.com/shellcheck/${SHELLCHECK_ARCHIVE}"
            pushd "${ROOT_DIR}/../build/"
            echo "${SHELLCHECK_ARCHIVE_SHA512SUM} ${SHELLCHECK_ARCHIVE}" | sha512sum -c -
            tar xvf "${SHELLCHECK_ARCHIVE}"
            rm -vf -- "${SHELLCHECK_ARCHIVE}"
            popd
        else
            echo "It seems that automatic installation is not supported on your platform."
            echo "Please install shellcheck manually:"
            echo "    https://github.com/koalaman/shellcheck#installing"
            exit 1
        fi
        ;;
    download-bats)
        if [[ -x "${ROOT_DIR}/../common/build/bats/bin/bats" ]]; then
            echo "bats already downloaded - skipping..."
            exit 0
        fi
        git clone https://github.com/sstephenson/bats.git "${ROOT_DIR}/../common/build/bats"
        ;;
    initialize-submodules)
        files="$( ls "${ROOT_DIR}/../common/src/test/bats/test_helper/bats-assert/" || echo "" )"
        if [ ! -z "${files}" ]; then
            echo "Submodules already initialized";
        else
            git submodule init
            git submodule update
        fi
        ;;
    *)
        usage
        ;;
esac
