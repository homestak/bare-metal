#!/bin/bash
# lib/inject-preseed.sh — inject preseed.cfg + authorized_keys into both initrds

inject_preseed() {
    echo "=== Injecting preseed into initrd ..."
    mkdir -p "$WORK_DIR/initrd-inject"
    cp "$PRESEED" "$WORK_DIR/initrd-inject/preseed.cfg"

    # Stamp build metadata into the preseed copy
    local build_time commit
    build_time="$(date -Iseconds)"
    commit="$(git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
    sed -i "1i# build: ${build_time}\n# commit: ${commit}" "$WORK_DIR/initrd-inject/preseed.cfg"

    # Substitute secrets from .secrets into the preseed copy
    local secrets="$SCRIPT_DIR/.secrets"
    if [ -f "$secrets" ]; then
        # shellcheck source=/dev/null
        source "$secrets"
        sed -i \
            -e "s|CHANGEME_ROOT_HASH|${ROOT_PASSWORD_HASH}|g" \
            -e "s|CHANGEME_USER_HASH|${USER_PASSWORD_HASH}|g" \
            -e "s|CHANGEME_FULLNAME|${USER_FULLNAME}|g" \
            -e "s|CHANGEME_USERNAME|${USERNAME}|g" \
            "$WORK_DIR/initrd-inject/preseed.cfg"
        echo "    Substituted secrets from .secrets"
    else
        echo "    WARNING: .secrets not found — CHANGEME placeholders will remain in preseed"
    fi

    # Apply partman mode — "confirm" (default) removes the auto-confirm lines
    # so the installer pauses for user input; "auto" keeps them for unattended use
    if [ "${PARTMAN_MODE:-confirm}" = "confirm" ]; then
        sed -i \
            -e '/^d-i partman\/confirm boolean true$/d' \
            -e '/^d-i partman\/confirm_nooverwrite boolean true$/d' \
            "$WORK_DIR/initrd-inject/preseed.cfg"
        echo "    Partman mode: confirm (will prompt before partitioning)"
    else
        echo "    Partman mode: auto (no confirmation prompt)"
    fi

    # Build authorized_keys from keys/*.pub
    local key_count=0 files_to_inject="preseed.cfg"
    if compgen -G "$SCRIPT_DIR/keys/*.pub" >/dev/null; then
        cat "$SCRIPT_DIR"/keys/*.pub > "$WORK_DIR/initrd-inject/authorized_keys"
        key_count=$(find "$SCRIPT_DIR/keys" -name '*.pub' | wc -l)
        files_to_inject="preseed.cfg
authorized_keys"
        echo "    Found $key_count SSH public key(s) in keys/"
    else
        echo "    WARNING: No .pub files found in keys/ — no authorized_keys will be installed"
    fi

    cd "$WORK_DIR/initrd-inject" || return 1
    # shellcheck disable=SC2086
    printf '%s\n' $files_to_inject | cpio -o -H newc 2>/dev/null | gzip > "$WORK_DIR/preseed.cpio.gz"

    for initrd in install.amd/initrd.gz install.amd/gtk/initrd.gz; do
        if [ -f "$WORK_DIR/isofiles/$initrd" ]; then
            cat "$WORK_DIR/preseed.cpio.gz" >> "$WORK_DIR/isofiles/$initrd"
            echo "    Injected into $initrd"
        fi
    done
    cd "$SCRIPT_DIR" || return 1
}
