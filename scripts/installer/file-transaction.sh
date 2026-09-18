#!/bin/sh
# HomeRoute sandbox file transaction helper.
# This helper is repository-test tooling. It refuses to operate without an
# explicit sandbox marker and never enables live router/VPS apply.

set -eu

die() {
    printf '[FAIL] %s\n' "$1" >&2
    exit 2
}

require_sandbox() {
    root=${HOMEROUTE_SANDBOX_ROOT:-}
    [ -n "$root" ] || die 'HOMEROUTE_SANDBOX_ROOT is required'

    case "$root" in
        /|/bin|/boot|/dev|/etc|/home|/opt|/proc|/root|/run|/sbin|/srv|/sys|/tmp|/usr|/var)
            die "refusing unsafe sandbox root: $root"
            ;;
    esac

    [ -d "$root" ] || die "sandbox root does not exist: $root"
    [ -f "$root/.homeroute-sandbox" ] || die "sandbox marker missing: $root/.homeroute-sandbox"

    HOMEROUTE_SANDBOX_ROOT=$(CDPATH= cd -- "$root" && pwd)
    export HOMEROUTE_SANDBOX_ROOT
}

safe_relative() {
    relative=$1
    [ -n "$relative" ] || die 'empty managed path'
    case "$relative" in
        /*|.|..|../*|*/../*|*/..)
            die "unsafe managed path: $relative"
            ;;
    esac
}

tx_begin() {
    require_sandbox
    txid=${HOMEROUTE_TX_ID:-tx-$$}
    case "$txid" in
        *[!A-Za-z0-9._-]*|'') die "unsafe transaction id: $txid" ;;
    esac

    TX_DIR="$HOMEROUTE_SANDBOX_ROOT/.homeroute-transactions/$txid"
    MANIFEST="$TX_DIR/manifest.tsv"
    BACKUP_DIR="$TX_DIR/files"
    STATUS_FILE="$TX_DIR/status"

    [ ! -e "$TX_DIR" ] || die "transaction already exists: $txid"
    mkdir -p "$BACKUP_DIR"
    : > "$MANIFEST"
    printf '%s\n' 'ACTIVE' > "$STATUS_FILE"

    export TX_DIR MANIFEST BACKUP_DIR STATUS_FILE
    printf '[TX] begin id=%s\n' "$txid"
}

manifest_has() {
    relative=$1
    awk -F '\t' -v p="$relative" '$2 == p { found=1 } END { exit(found ? 0 : 1) }' "$MANIFEST"
}

tx_snapshot_file() {
    relative=$1
    safe_relative "$relative"
    manifest_has "$relative" && return 0

    target="$HOMEROUTE_SANDBOX_ROOT/$relative"
    if [ -e "$target" ]; then
        [ -f "$target" ] || die "managed object is not a regular file: $relative"
        mkdir -p "$BACKUP_DIR/$(dirname "$relative")"
        cp -p "$target" "$BACKUP_DIR/$relative"
        printf 'present\t%s\n' "$relative" >> "$MANIFEST"
        printf '[TX] snapshot present %s\n' "$relative"
    else
        printf 'absent\t%s\n' "$relative" >> "$MANIFEST"
        printf '[TX] snapshot absent %s\n' "$relative"
    fi
}

tx_apply_file() {
    relative=$1
    source_file=$2
    safe_relative "$relative"
    [ -f "$source_file" ] || die "desired source file missing: $source_file"

    tx_snapshot_file "$relative"
    target="$HOMEROUTE_SANDBOX_ROOT/$relative"

    if [ -f "$target" ] && cmp -s "$target" "$source_file"; then
        printf '[NO CHANGE] %s\n' "$relative"
        return 0
    fi

    mkdir -p "$(dirname "$target")"
    tmp="$target.homeroute.$$"
    cp "$source_file" "$tmp"
    mv "$tmp" "$target"
    printf '[CHANGE] %s\n' "$relative"
}

tx_verify_file() {
    relative=$1
    source_file=$2
    safe_relative "$relative"
    target="$HOMEROUTE_SANDBOX_ROOT/$relative"
    [ -f "$target" ] || return 1
    cmp -s "$target" "$source_file"
}

tx_commit() {
    [ -n "${STATUS_FILE:-}" ] || die 'transaction not started'
    printf '%s\n' 'COMMITTED' > "$STATUS_FILE"
    printf '[TX] commit\n'
}

tx_rollback() {
    [ -n "${MANIFEST:-}" ] || die 'transaction not started'
    [ -f "$MANIFEST" ] || die 'transaction manifest missing'

    reverse="$TX_DIR/manifest.reverse.tsv"
    awk '{ lines[NR]=$0 } END { for (i=NR; i>=1; i--) print lines[i] }' "$MANIFEST" > "$reverse"

    tab=$(printf '\t')
    while IFS="$tab" read -r state relative; do
        [ -n "$relative" ] || continue
        safe_relative "$relative"
        target="$HOMEROUTE_SANDBOX_ROOT/$relative"
        case "$state" in
            present)
                snapshot="$BACKUP_DIR/$relative"
                [ -f "$snapshot" ] || die "snapshot missing during rollback: $relative"
                mkdir -p "$(dirname "$target")"
                tmp="$target.rollback.$$"
                cp -p "$snapshot" "$tmp"
                mv "$tmp" "$target"
                printf '[ROLLBACK] restored %s\n' "$relative"
                ;;
            absent)
                rm -f "$target"
                printf '[ROLLBACK] removed transaction-created %s\n' "$relative"
                ;;
            *)
                die "unknown manifest state: $state"
                ;;
        esac
    done < "$reverse"

    rm -f "$reverse"
    printf '%s\n' 'ROLLED_BACK' > "$STATUS_FILE"
    printf '[TX] rollback complete\n'
}
