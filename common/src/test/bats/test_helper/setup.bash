#!/usr/bin/env bash
# https://unix.stackexchange.com/questions/228597/how-to-copy-a-folder-recursively-in-an-idempotent-way-using-cp
shopt -s dotglob

export PIPELINES_TEST_DIR="${BATS_TMPDIR}/BATS"
rm -rf "${PIPELINES_TEST_DIR}"
mkdir -p "${PIPELINES_TEST_DIR}"
cp -R "${BATS_TEST_DIRNAME}"/../../main/bash/* "${PIPELINES_TEST_DIR}/"
cp -R "${BATS_TEST_DIRNAME}"/fixtures/* "${PIPELINES_TEST_DIR}/"
cd "${PIPELINES_TEST_DIR}"
