#!/usr/bin/env bash
# shellcheck shell=bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=config.sh
source "${SCRIPT_DIR}/config.sh"

RELEASE_TAG="${RELEASE_TAG:-Nightly}"

###############################################################################
# Arguments
###############################################################################

SOURCE_SHA="${1:-HEAD}"
KSU_SHA="${2:-}"
NEXT_SHA="${3:-}"
SUSFS_SHA="${4:-}"
NOMOUNT_SHA="${5:-}"
RELEASE_NOTES="${6:-Release}"

###############################################################################
# Verify build output
###############################################################################

shopt -s nullglob

FILES=("${DIST_DIR}"/*.zip)

(( ${#FILES[@]} )) || die "No ZIP files found in ${DIST_DIR}"

###############################################################################
# Create nightly.json
###############################################################################

cat > "${DIST_DIR}/nightly.json" <<EOF
{
  "source": "${SOURCE_SHA}",
  "kernelsu": "${KSU_SHA}",
  "kernelsu_next": "${NEXT_SHA}",
  "susfs": "${SUSFS_SHA}",
  "nomount": "${NOMOUNT_SHA}"
}
EOF

###############################################################################
# Create release if necessary
###############################################################################

if ! gh release view $RELEASE_TAG >/dev/null 2>&1; then

    msg "Creating Nightly release"

    gh release create $RELEASE_TAG \
        --title "$RELEASE_TAG" \
        --notes "$RELEASE_NOTES"

fi

###############################################################################
# Upload packages
###############################################################################

msg "Uploading kernel packages"

gh release upload $RELEASE_TAG \
    "${DIST_DIR}"/*.zip \
    --clobber

###############################################################################
# Upload nightly.json
###############################################################################

msg "Uploading nightly.json"

gh release upload $RELEASE_TAG \
    "${DIST_DIR}/nightly.json" \
    --clobber

###############################################################################
# Update release notes
###############################################################################

msg "Updating release notes"

gh release edit $RELEASE_TAG \
    --title "$RELEASE_TAG" \
    --notes "$RELEASE_NOTES"

###############################################################################
# Done
###############################################################################

msg "Nightly release updated"
