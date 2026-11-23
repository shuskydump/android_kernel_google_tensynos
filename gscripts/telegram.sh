#!/usr/bin/env bash
# shellcheck shell=bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=config.sh
source "${SCRIPT_DIR}/config.sh"

BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-}"

if [[ -z "${BOT_TOKEN}" || -z "${CHAT_ID}" ]]; then
    msg "TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID is not set. Skipping Telegram notification."
    exit 0
fi

API_URL="https://api.telegram.org/bot${BOT_TOKEN}"

send_message() {
    local text="$1"
    curl -sS -X POST "${API_URL}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d text="${text}" \
        -d parse_mode="HTML" \
        -d disable_web_page_preview="true" > /dev/null
}

send_document() {
    local file_path="$1"
    local caption="${2:-}"

    [[ -f "${file_path}" ]] || die "File not found: ${file_path}"

    curl -sS -X POST "${API_URL}/sendDocument" \
        -F chat_id="${CHAT_ID}" \
        -F document=@"${file_path}" \
        -F caption="${caption}" \
        -F parse_mode="HTML" > /dev/null
}

get_device_name() {
    case "$1" in
        gs201)
            echo "Pixel 7 / 7 Pro / 7a (gs201)"
            ;;
        zuma)
            echo "Pixel 8 / 8 Pro / 8a (zuma)"
            ;;
        zumapro)
            echo "Pixel 9 / 9 Pro / XL / Fold (zumapro)"
            ;;
        *)
            echo "$1"
            ;;
    esac
}

get_variant_desc() {
    case "$1" in
        ksu-susfs)
            echo "KernelSU + SuSFS"
            ;;
        ksu-next-susfs)
            echo "KernelSU-Next + SuSFS"
            ;;
        *)
            echo "$1"
            ;;
    esac
}

send_build_notification() {
    local target="$1"
    local variant="$2"
    local branch="${3:-$(git -C "${KERNEL_REPO}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")}"

    local dev_name
    dev_name="$(get_device_name "${target}")"

    local var_desc
    var_desc="$(get_variant_desc "${variant}")"

    local commit_sha
    commit_sha="$(git -C "${KERNEL_REPO}" rev-parse --short HEAD 2>/dev/null || echo "unknown")"

    local commit_msg
    commit_msg="$(git -C "${KERNEL_REPO}" log -1 --pretty=%s 2>/dev/null | sed 's/[<>&]/ /g' || echo "Kernel Build")"

    local zip_name
    zip_name="$(build_name "${target}" "${variant}")"
    local zip_path="${DIST_DIR}/${zip_name}"

    local date_str
    date_str="$(date -u '+%Y-%m-%d %H:%M UTC')"

    local post
    post="⚡ <b>Sultan Kernel Build Completed</b>

📱 <b>Device:</b> ${dev_name}
📦 <b>Variant:</b> <code>${variant}</code> (${var_desc})
🌿 <b>Branch:</b> <code>${branch}</code>
🔨 <b>Commit:</b> <code>${commit_sha}</code> - <i>${commit_msg}</i>
📅 <b>Date:</b> ${date_str}

✨ <b>Features:</b>
• ${var_desc}
• NoMount integration
• Sultan battery, scheduler & performance optimizations
• OTG host shim support
• Flashable AnyKernel3 package

📥 <i>Flashing ZIP attached below.</i>"

    msg "Sending Telegram build post..."
    send_message "${post}"

    if [[ -f "${zip_path}" ]]; then
        msg "Uploading ${zip_name} to Telegram..."
        send_document "${zip_path}" "📦 <b>${zip_name}</b> | ${dev_name}"
        msg "Upload completed."
    else
        warn "ZIP file not found at ${zip_path}, skipped attachment."
    fi
}

send_release_notification() {
    local release_notes="${1:-Nightly Release}"
    local date_str
    date_str="$(date -u '+%Y-%m-%d %H:%M UTC')"

    local post
    post="🚀 <b>Sultan Kernel Nightly Release</b>
📅 <b>Date:</b> ${date_str}

📝 <b>Release Notes:</b>
${release_notes}

📦 <i>All kernel build zips attached below.</i>"

    msg "Sending Telegram release post..."
    send_message "${post}"

    for zip_file in "${DIST_DIR}"/*.zip; do
        [[ -f "${zip_file}" ]] || continue
        local fname
        fname="$(basename "${zip_file}")"
        msg "Uploading ${fname} to Telegram..."
        send_document "${zip_file}" "📦 <b>${fname}</b>"
    done

    msg "Release notifications and files sent to Telegram."
}

MODE="${1:-}"

case "${MODE}" in
    build)
        [[ $# -ge 3 ]] || die "Usage: $0 build <target> <variant> [branch]"
        send_build_notification "$2" "$3" "${4:-}"
        ;;
    release)
        send_release_notification "${2:-}"
        ;;
    *)
        die "Usage: $0 <build|release> ..."
        ;;
esac
