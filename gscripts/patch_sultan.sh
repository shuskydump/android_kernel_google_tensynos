#!/usr/bin/env bash
# shellcheck shell=bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=config.sh
source "${SCRIPT_DIR}/config.sh"

if [ $# -ne 2 ]; then
    echo "Usage: $0 <gs201|zuma|zumapro> <ksu-susfs|ksu-next-susfs>"
    exit 1
fi

case "$1" in
    gs201|zuma|zumapro)
        TARGET="$1"
        ;;
    *)
        echo "Error: '$1' is not a valid target. Valid targets: gs201, zuma, zumapro"
        exit 1
        ;;
esac

case "$2" in
    ksu-susfs|ksu-next-susfs)
        VARIANT="$2"
        ;;
    *)
        echo "Error: '$2' is not a valid variant. Valid variants: ksu-susfs, ksu-next-susfs"
        exit 1
        ;;
esac

prepare_anykernel() {
    msg "Setting up AnyKernel for target: ${TARGET}"

    rm -rf "${ANYKERNEL_DIR}"
    mkdir -p "${ANYKERNEL_DIR}"

    if [[ -d "${ANYKERNEL_SRC_DIR}" ]]; then
        cp -r "${ANYKERNEL_SRC_DIR}/tools" "${ANYKERNEL_DIR}/"
        cp -r "${ANYKERNEL_SRC_DIR}/META-INF" "${ANYKERNEL_DIR}/"
        cp "${ANYKERNEL_SRC_DIR}/LICENSE" "${ANYKERNEL_DIR}/" 2>/dev/null || true
        cp "${ANYKERNEL_SRC_DIR}/README.md" "${ANYKERNEL_DIR}/" 2>/dev/null || true

        if [[ -f "${ANYKERNEL_SRC_DIR}/anykernel.sh.${TARGET}" ]]; then
            cp "${ANYKERNEL_SRC_DIR}/anykernel.sh.${TARGET}" "${ANYKERNEL_DIR}/anykernel.sh"
        elif [[ -f "${ANYKERNEL_SRC_DIR}/anykernel.sh" ]]; then
            cp "${ANYKERNEL_SRC_DIR}/anykernel.sh" "${ANYKERNEL_DIR}/anykernel.sh"
        fi

        chmod +x "${ANYKERNEL_DIR}/anykernel.sh" 2>/dev/null || true
        chmod +x "${ANYKERNEL_DIR}/tools/"* 2>/dev/null || true
        chmod +x "${ANYKERNEL_DIR}/META-INF/com/google/android/update-binary" 2>/dev/null || true
    else
        die "In-tree AnyKernel template directory not found at ${ANYKERNEL_SRC_DIR}"
    fi
}

msg "Patches and modules (KernelSU, SuSFS, NoMount, OTG Host Shim) are integrated in-tree."
msg "Configuring defconfig for ${TARGET}"

DEFCONFIG="${KERNEL_REPO}/arch/arm64/configs/${TARGET}_defconfig"

# Ensure core configurations are set
for cfg in \
    "CONFIG_KSU=y" \
    "CONFIG_KSU_SUSFS=y" \
    "CONFIG_KSU_SUSFS_SUS_SU=n" \
    "CONFIG_HEADERS_INSTALL=y" \
    "CONFIG_NOMOUNT=y" \
    "CONFIG_TMPFS_XATTR=y" \
    "CONFIG_TMPFS_POSIX_ACL=y"
do
    if ! grep -q "^${cfg}$" "$DEFCONFIG"; then
        echo "${cfg}" >> "$DEFCONFIG"
    fi
done

prepare_anykernel

msg "$TARGET $VARIANT ready for build"
