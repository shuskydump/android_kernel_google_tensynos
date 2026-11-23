#!/usr/bin/env bash
# shellcheck shell=bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=config.sh
source "${SCRIPT_DIR}/config.sh"

usage() {
cat <<EOF
Usage:
    $0 <target> <variant>
EOF
}

###############################################################################
# Arguments
###############################################################################

[[ $# -eq 2 ]] || {
    usage
    exit 1
}

TARGET="$1"
VARIANT="$2"

require_target "${TARGET}"
require_variant "${VARIANT}"

###############################################################################
# Directories
###############################################################################

ANYKERNEL_DIR="${ANYKERNEL_DIR:-${REPO_ROOT}/AnyKernel}"

[[ -d "${ANYKERNEL_DIR}" ]] \
    || die "AnyKernel directory not found."

ensure_directories

ZIP_NAME="$(build_name "${TARGET}" "${VARIANT}")"

###############################################################################
# Clean previous package
###############################################################################

rm -f "${DIST_DIR:?}/${ZIP_NAME}"

###############################################################################
# Create zip
###############################################################################

msg "Packaging ${ZIP_NAME}"

(
    cd "${ANYKERNEL_DIR}"

    zip -r9 \
        "${DIST_DIR}/${ZIP_NAME}" \
        . \
        -x ".git/*" \
        -x ".github/*" \
        -x "*.zip" \
        -x "README.md"
)

###############################################################################
# Verify
###############################################################################

[[ -f "${DIST_DIR}/${ZIP_NAME}" ]] \
    || die "Failed to create ${ZIP_NAME}"

# Validate AK3 zip structure: anykernel.sh must be at zip root
if ! unzip -l "${DIST_DIR}/${ZIP_NAME}" | grep -q " anykernel.sh$"; then
    die "Invalid AK3 zip: anykernel.sh not found at zip root!"
fi

msg "Package created and verified as valid AK3 zip"

echo
echo "Output:"
echo "  ${DIST_DIR}/${ZIP_NAME}"
echo
