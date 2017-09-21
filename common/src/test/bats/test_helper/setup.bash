#!/usr/bin/env bash
export PIPELINES_TEST_DIR="${BATS_TMPDIR}/BATS"
rm -rf "${PIPELINES_TEST_DIR}"
mkdir -p "${PIPELINES_TEST_DIR}"
cp -rf "${BATS_TEST_DIRNAME}/../../main/bash/" "${PIPELINES_TEST_DIR}"
cp -rf "${BATS_TEST_DIRNAME}/fixtures/" "${PIPELINES_TEST_DIR}"
cd "${PIPELINES_TEST_DIR}"
