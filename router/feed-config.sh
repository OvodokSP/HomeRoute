#!/bin/sh
# Render reviewed HomeRoute router feed lines.
# Read-only helper: it prints desired content and never writes files.

set -eu

mode=${1:-help}
arch=${2:-}

show_help() {
    cat <<'EOF'
Usage: feed-config.sh render-chur <entware-arch>
       feed-config.sh hrneo-status

Supported Chur architectures:
  aarch64-3.10
  mips-3.4
  mipsel-3.4
EOF
}

render_chur() {
    case "$1" in
        aarch64-3.10)
            printf '%s\n' 'src/gz chur https://ward-sentry.github.io/chur-keenetic/1_0_0/aarch64-3.10'
            ;;
        mips-3.4)
            printf '%s\n' 'src/gz chur https://ward-sentry.github.io/chur-keenetic/1_0_0/mips-3.4'
            ;;
        mipsel-3.4)
            printf '%s\n' 'src/gz chur https://ward-sentry.github.io/chur-keenetic/1_0_0/mipsel-3.4'
            ;;
        *)
            printf '[FAIL] unsupported Entware architecture: %s\n' "$1" >&2
            exit 2
            ;;
    esac
}

case "$mode" in
    render-chur)
        [ -n "$arch" ] || {
            printf '%s\n' '[FAIL] Entware architecture is required' >&2
            exit 2
        }
        render_chur "$arch"
        ;;
    hrneo-status)
        printf '%s\n' 'HOMEROUTE_FEED component=hrneo status=PINNED_ARTIFACT version=3.18.3-1 integrity=GIT_BLOB_ONLY live_install=false'
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        printf '[FAIL] unknown feed-config mode: %s\n' "$mode" >&2
        show_help >&2
        exit 2
        ;;
esac
