#!/bin/bash
# lib/patch-bootloader.sh — patch GRUB and isolinux configs for preseed boot

patch_bootloader() {
    local boot_params="auto=true priority=critical ipv6.disable=1 preseed/file=/preseed.cfg"

    # GRUB (UEFI)
    local grub_cfg="$WORK_DIR/isofiles/boot/grub/grub.cfg"
    if [ -f "$grub_cfg" ]; then
        echo "=== Patching GRUB config for UEFI boot ..."
        sed -i "s|--- quiet|${boot_params} --- quiet|g" "$grub_cfg"
        sed -i '1i set timeout=0\nset timeout_style=hidden\nset default=0' "$grub_cfg"
        local matches
        matches=$(grep -c "preseed/file" "$grub_cfg" || true)
        echo "    Patched $matches entries in grub.cfg"
    else
        echo "WARNING: GRUB config not found at $grub_cfg, skipping UEFI patch"
    fi

    # isolinux (BIOS)
    for cfg in isolinux/txt.cfg isolinux/gtk.cfg; do
        local cfg_file="$WORK_DIR/isofiles/$cfg"
        if [ -f "$cfg_file" ]; then
            echo "=== Patching $cfg for BIOS boot ..."
            sed -i "s|--- quiet|${boot_params} --- quiet|g" "$cfg_file"
            local matches
            matches=$(grep -c "preseed/file" "$cfg_file" || true)
            echo "    Patched $matches entries in $cfg"
        fi
    done

    # isolinux timeout
    local isolinux_cfg="$WORK_DIR/isofiles/isolinux/isolinux.cfg"
    if [ -f "$isolinux_cfg" ]; then
        sed -i 's|^timeout 0|timeout 1|' "$isolinux_cfg"
        echo "    Set isolinux timeout to 0.1 seconds"
    fi
}
