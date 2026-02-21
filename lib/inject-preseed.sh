#!/bin/bash
# lib/inject-preseed.sh — inject preseed.cfg into both initrds

inject_preseed() {
    echo "=== Injecting preseed into initrd ..."
    mkdir -p "$WORK_DIR/initrd-inject"
    cp "$PRESEED" "$WORK_DIR/initrd-inject/preseed.cfg"

    cd "$WORK_DIR/initrd-inject"
    echo preseed.cfg | cpio -o -H newc 2>/dev/null | gzip > "$WORK_DIR/preseed.cpio.gz"

    for initrd in install.amd/initrd.gz install.amd/gtk/initrd.gz; do
        if [ -f "$WORK_DIR/isofiles/$initrd" ]; then
            cat "$WORK_DIR/preseed.cpio.gz" >> "$WORK_DIR/isofiles/$initrd"
            echo "    Injected preseed.cfg into $initrd"
        fi
    done
    cd "$SCRIPT_DIR"
}
