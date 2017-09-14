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
            SHELLCHECK_ARCHIVE="shellcheck-latest.linux.x86_64.tar.xz"
            SHELLCHECK_ARCHIVE_SHA512SUM="53ee4adc1d53d3689b9b7b815e6a0dc6022d1a4fe594f96a43742076659b6a3e483335ccd38367fcbd2b73ecf55dae1958cd989a6e2875e68dabbbc3c89084fd"
            if [[ -x "${ROOT_DIR}/../common/build/shellcheck-latest/shellcheck" ]]; then
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
