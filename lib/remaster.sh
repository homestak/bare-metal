#!/bin/bash
# lib/remaster.sh — extract and rebuild ISO with xorriso

extract_iso() {
    echo "=== Extracting ISO to $WORK_DIR/isofiles ..."
    mkdir -p "$WORK_DIR/isofiles"
    xorriso $XORRISO_QUIET -osirrox on -indev "$SOURCE_ISO" -extract / "$WORK_DIR/isofiles"
    chmod -R u+w "$WORK_DIR/isofiles"

    # Replace splash image if present
    local splash="$SCRIPT_DIR/lib/splash.png"
    if [ -f "$splash" ] && [ -f "$WORK_DIR/isofiles/isolinux/splash.png" ]; then
        echo "=== Replacing boot splash image ..."
        cp "$WORK_DIR/isofiles/isolinux/splash.png" "$WORK_DIR/isofiles/isolinux/splash.png.0"
        cp "$splash" "$WORK_DIR/isofiles/isolinux/splash.png"
        echo "    Replaced isolinux/splash.png (original backed up as splash.png.0)"
    fi
}

rebuild_iso() {
    echo "=== Rebuilding ISO as $OUTPUT_ISO ..."
    xorriso $XORRISO_QUIET -as mkisofs \
        -o "$OUTPUT_ISO" \
        -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
        -c isolinux/boot.cat \
        -b isolinux/isolinux.bin \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -eltorito-alt-boot \
        -e boot/grub/efi.img \
        -no-emul-boot -isohybrid-gpt-basdat \
        "$WORK_DIR/isofiles"

    echo "=== Remastered ISO: $OUTPUT_ISO ($(du -h "$OUTPUT_ISO" | cut -f1))"
}
