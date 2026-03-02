# Debian 13 Preseed Automated Install Project

## Project Goal
Build a remastered Debian 13 (Trixie) ISO with a baked-in preseed file for fully unattended installs. The same tooling works for both DVD and netinst ISOs.

## Environment

### Hosts
- **father** — build machine. Debian 13, ZFS on NVMe, Proxmox VE. This is where the remaster script runs and USBs are written.
- **mother** — target machine. Intel NUC7i7BNB (i7-7567U, 32GB DDR4, Crucial 275GB SSD + WD 4TB ZFS). Debian 13 fresh installs go here.

### Working Directory on father
```
~/homestak/bare-metal/
  build                               # entry point — sources lib/, runs build
  reinstall                           # remote reinstall via efibootmgr --bootnext
  preseed.cfg                         # preseed file for mother (CHANGEME placeholders in git)
  .secrets                            # password hashes + user identity (.gitignore'd)
  keys/                               # SSH public keys (.pub files, .gitignore'd)
    .gitkeep                          # keeps directory in git
  lib/
    remaster.sh                       # extract + rebuild ISO with xorriso
    inject-preseed.sh                 # secrets substitution + authorized_keys + cpio/gzip into both initrds
    patch-bootloader.sh               # sed on grub.cfg, txt.cfg, gtk.cfg
    splash.png                        # custom Homestak boot splash (640x480)
  iso/                                # .gitignore'd
    debian-13.3.0-amd64-netinst.iso   # source netinst ISO (default)
    debian-13.3.0-amd64-DVD-1.iso     # source DVD ISO (alternate)
    debian-13-preseed.iso             # output remastered ISO
  test/
    build.bats                        # 20 bats tests (flags, dry-run, env vars, preflight, partman)
    reinstall.bats                    # 13 bats tests (flags, dry-run, env vars)
  tools/
    preseed-extraction.sh             # utility for reverse-engineering a running install
```

### USB Devices on father
Color-coded Verbatim STORE N GO drives (28.9G each):
- **Red** (serial 23061806330192, ~30 MB/s) — auto/netinst (fully unattended)
- **Green** (serial 23061677640013, ~15 MB/s) — confirm/netinst (prompts before partitioning)
- **Blue** (serial 23061806320148) — confirm/DVD

Retired drives:
- **A** — 57.8G USB DISK 3.0 (~21 MB/s)
- **B** — 58.2G USB Flash Drive (~20 MB/s)
- **C** — 3.9G Flash Disk (~4 MB/s, too small for DVD ISO)

## What Works (All Confirmed on mother)
- ISO extraction and rebuild with xorriso (hybrid MBR + EFI)
- Custom Homestak splash screen (replaces isolinux/splash.png)
- Preseed injection into both initrds (text: `install.amd/initrd.gz`, graphical: `install.amd/gtk/initrd.gz`)
- Boot parameter patching via sed on grub.cfg (UEFI), isolinux/txt.cfg and gtk.cfg (BIOS)
- GRUB: timeout=0, timeout_style=hidden, default=0 — instant boot, no menu visible, brief splash
- isolinux: timeout=1 (0.1s, minimum non-zero value)
- Both text and graphical installer paths work fully unattended
- Dynamic disk selection via `partman/early_command` (smallest non-USB disk)
- Partman modes via `--partman` flag: `confirm` (default, prompts before partitioning) or `auto` (fully unattended)
- Locale, keyboard, network, hostname, timezone, partitioning, user account, GRUB — all preseed correctly
- Standard task enabled (`tasksel tasksel/first multiselect standard`) — full baseline CLI system (man-db, less, bash-completion, file, lsof, pciutils, ca-certificates, etc.)
- Extra packages via pkgsel/include: openssh-server, sudo, curl, wget, git, vim, htop (no desktop/GNOME)
- SSH public keys loaded from `keys/*.pub` directory — drop `.pub` files to add keys, all keys go to both jderose and root
- Secrets substituted at build time: preseed.cfg has CHANGEME placeholders, `inject-preseed.sh` sources `.secrets` and sed-replaces them
- late_command: root SSH enabled, jderose sudoers, authorized_keys (from keys/*.pub via initrd)
- NTP clock sync during install (fixes bad BIOS clock, ensures correct time from first boot)
- IPv6 disabled on installed system (GRUB_CMDLINE_LINUX="ipv6.disable=1" + update-grub)
- Instant GRUB boot on installed system (GRUB_TIMEOUT=0 + GRUB_TIMEOUT_STYLE=hidden via late_command)
- Remote reinstall via `efibootmgr --bootnext` (no physical access needed), including back-to-back reinstalls
- CD eject disabled (`cdrom-detect/eject false`) — prevents USB from entering degraded state after install
- Works with both DVD and netinst ISOs (netinst is default)

## Boot Parameters
The sed pattern for patching boot configs produces:
```
auto=true priority=critical ipv6.disable=1 preseed/file=/preseed.cfg --- quiet
```

Important: parameters go BEFORE `---`. The `---` separator divides kernel params from initrd params. Preseed params must be on the kernel side.

## Preseed File Structure (preseed.cfg)
Key sections and their current correct values:

```
#_preseed_V1

### Localization
d-i debian-installer/language string en
d-i debian-installer/country string US
d-i debian-installer/locale string en_US.UTF-8
d-i localechooser/supported-locales multiselect en_US.UTF-8

### Keyboard
d-i keyboard-configuration/xkb-keymap select us
d-i keyboard-configuration/layoutcode string us
d-i keyboard-configuration/modelcode string pc105
d-i keyboard-configuration/variantcode string
d-i keyboard-configuration/optionscode string

### Network
d-i netcfg/choose_interface select eno1
d-i netcfg/use_autoconfig boolean true
d-i netcfg/get_hostname string mother
d-i netcfg/get_domain string core
d-i netcfg/target_network_config select ifupdown

### Wi-Fi (uncomment for wireless-only hosts)
#d-i netcfg/choose_interface select wlan0
#d-i netcfg/wireless_essid string MyNetwork
#d-i netcfg/wireless_security_type select wpa
#d-i netcfg/wireless_wpa string MyPassword

### Partman early command - select smallest non-USB disk
d-i partman/early_command string \
    USBDEV=$(list-devices usb-partition | sed "s/\(.*\)./\1/" | sort -u); \
    INSTALL_DISK=""; SMALLEST=999999999999; \
    for DISK in $(list-devices disk); do \
        echo "$USBDEV" | grep -q "^${DISK}$" && continue; \
        SIZE=$(cat /sys/block/$(basename $DISK)/size); \
        if [ "$SIZE" -lt "$SMALLEST" ]; then \
            SMALLEST=$SIZE; \
            INSTALL_DISK=$DISK; \
        fi; \
    done; \
    debconf-set partman-auto/disk $INSTALL_DISK; \
    debconf-set grub-installer/bootdev $INSTALL_DISK

### Mirror
d-i apt-setup/use_mirror boolean true
d-i apt-setup/disable-cdrom-entries boolean true
d-i apt-setup/non-free-firmware boolean true
d-i mirror/country string manual
d-i mirror/http/hostname string deb.debian.org
d-i mirror/http/directory string /debian
d-i mirror/http/proxy string
choose-mirror-bin mirror/country string manual
choose-mirror-bin mirror/http/hostname string deb.debian.org
choose-mirror-bin mirror/http/directory string /debian
choose-mirror-bin mirror/http/proxy string

### Clock and timezone
d-i clock-setup/utc boolean true
d-i clock-setup/ntp boolean true
d-i clock-setup/ntp-server string pool.ntp.org
d-i time/zone string America/Denver

### Partitioning (atomic recipe: EFI + swap + single root)
d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select atomic
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
# These two lines are present in preseed.cfg but removed by --partman confirm (default).
# Kept intact by --partman auto for fully unattended installs.
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
d-i partman-efi/non_efi_system boolean true

### Base system
d-i base-installer/kernel/image string linux-image-amd64
d-i base-installer/initramfs-tools/driver-policy string most

### Account setup
# Values substituted from .secrets at build time by inject-preseed.sh
d-i passwd/root-password-crypted password CHANGEME_ROOT_HASH
d-i passwd/root-login boolean true
d-i passwd/user-fullname string CHANGEME_FULLNAME
d-i passwd/username string CHANGEME_USERNAME
d-i passwd/user-password-crypted password CHANGEME_USER_HASH

### Package selection
tasksel tasksel/first multiselect standard
d-i pkgsel/include string openssh-server sudo curl wget git vim htop
d-i pkgsel/upgrade select full-upgrade
popularity-contest popularity-contest/participate boolean false

### GRUB bootloader
d-i grub-installer/only_debian boolean true
d-i grub-installer/force-efi-extra-removable boolean true

### late_command handles:
# - PermitRootLogin yes in sshd_config
# - jderose NOPASSWD sudo
# - authorized_keys for jderose and root (copied from /authorized_keys in initrd, built from keys/*.pub)
# - IPv6 disable (GRUB_CMDLINE_LINUX + update-grub)
# - Instant GRUB boot (GRUB_TIMEOUT=0 + GRUB_TIMEOUT_STYLE=hidden)

### Finish
d-i cdrom-detect/eject boolean false
d-i finish-install/reboot_in_progress note
```

## Build Script
Entry point: `./build`. Sources `lib/remaster.sh`, `lib/inject-preseed.sh`, `lib/patch-bootloader.sh`.

Flags:
- `-h, --help` — show usage
- `-n, --dry-run` — show config without building
- `-q, --quiet` — suppress xorriso output
- `-y, --yes` — skip USB write confirmation
- `-u, --usb DEVICE` — write to USB after build
- `-s, --source-iso PATH` — source ISO
- `-p, --preseed PATH` — preseed file
- `-o, --output-iso PATH` — output ISO
- `--no-write` — build ISO but skip USB write
- `--partman MODE` — `confirm` (default, prompts before partitioning) or `auto` (fully unattended)

Env vars with defaults (flags take precedence):
- `SOURCE_ISO` — default `$SCRIPT_DIR/iso/debian-13.3.0-amd64-netinst.iso`
- `PRESEED` — default `$SCRIPT_DIR/preseed.cfg`
- `OUTPUT_ISO` — default `$SCRIPT_DIR/iso/debian-13-preseed.iso`
- `WORK_DIR` — default `/tmp/bare-metal.$$` (cleaned up on exit via trap)
- `USB_DEVICE` — optional, triggers dd to USB with confirmation

Steps:
1. Preflight checks (xorriso, cpio, gzip, isolinux isohdpfx.bin, source ISO, preseed file, .secrets warning)
2. `extract_iso` — xorriso extract + replace splash (lib/remaster.sh)
3. `inject_preseed` — substitute secrets from `.secrets`, apply partman mode, build authorized_keys from `keys/*.pub`, cpio+gzip append into both initrds (lib/inject-preseed.sh)
4. `patch_bootloader` — sed on grub.cfg, txt.cfg, gtk.cfg, isolinux.cfg (lib/patch-bootloader.sh)
5. `rebuild_iso` — xorriso mkisofs hybrid MBR+EFI (lib/remaster.sh)
6. Optionally dd to USB_DEVICE with `conv=fsync`

### Secrets and Keys

preseed.cfg is committed with CHANGEME placeholders:
- `CHANGEME_ROOT_HASH`, `CHANGEME_USER_HASH` — password hashes
- `CHANGEME_FULLNAME`, `CHANGEME_USERNAME` — user identity

At build time, `inject-preseed.sh` sources `.secrets` and sed-replaces the placeholders in the working copy. The `.secrets` file is `.gitignore`'d.

SSH public keys live in `keys/*.pub` (also `.gitignore`'d). At build time, all `.pub` files are concatenated into `authorized_keys` and injected into the initrd alongside `preseed.cfg`. The late_command copies `/authorized_keys` to both `~jderose/.ssh/` and `~root/.ssh/`.

### Partman Modes

`--partman confirm` (default): removes `partman/confirm` and `partman/confirm_nooverwrite` lines from the preseed so the installer pauses for user confirmation before partitioning. Safe for interactive installs.

`--partman auto`: keeps those lines intact so partitioning proceeds without prompting. Use for fully unattended installs.

Note: setting `partman/confirm boolean false` does NOT work — it answers "No" to the confirmation prompt, which loops (see lesson #14). The only way to require confirmation is to remove the lines entirely.

## Remote Reinstall

The `reinstall` script handles the full remote reinstall lifecycle — no physical access needed, just a USB with the preseed ISO plugged into the target.

```bash
# Build + write USB on father, move USB to mother, then:
./reinstall mother          # interactive (prompts for YES)
./reinstall mother --yes    # fully unattended
```

Entry point: `./reinstall <hostname>`. Performs: SSH preflight, auto-detect USB boot entry, `efibootmgr --bootnext`, reboot, poll for SSH, verify fresh install.

Flags:
- `-h, --help` — show usage
- `-n, --dry-run` — show config without acting (queries host for boot entry auto-detection)
- `-y, --yes` — skip confirmation prompt
- `-b, --boot-entry ENTRY` — EFI boot entry (auto-detected from `efibootmgr` if omitted)
- `-t, --timeout SECONDS` — poll timeout (default: `1200` = 20 min)

Env vars: `REINSTALL_BOOT_ENTRY`, `REINSTALL_TIMEOUT` (flags take precedence).

EFI boot entry auto-detection: the script queries `efibootmgr` on the target host and looks for a `USB.*PART 1` entry (CDROM/ISO mode). Entry numbers are non-deterministic — they change per device and across reboots — so auto-detection is preferred over hardcoding. The firmware creates entries when a USB drive is plugged in during boot; manually created entries degrade to generic `VenHw` paths when the drive is removed.

`--bootnext` is one-shot: the firmware clears it after use, so if the install fails, next reboot goes back to the existing system.

## Planned Improvements
- YAML host config templating (`generate-preseed.sh` + `preseed.template`)
- Site-config integration for secrets and defaults
- `--host` flag for `build` entry point

## Debugging Tips
- `Alt+F2` on installer console gives a shell
- `cat /preseed.cfg` — verify preseed is in initrd
- `cat /proc/cmdline` — verify boot parameters
- `debconf-get <key>` — check if preseed values are loaded
- `grep <pattern> /var/log/syslog` — installer logs
- Add `DEBCONF_DEBUG=5` to boot params for verbose debconf logging
- Installer logs end up in `/var/log/installer/syslog` on installed system

## Key Lessons Learned
1. **Smart quotes kill scripts.** Copy-paste from web UIs introduces UTF-8 curly quotes and em dashes. Always verify with `cat -A`.
2. **Preseed params go before `---`** in boot command lines. After `---` is initrd territory.
3. **DVD installer doesn't mount media before preseed is needed.** Using `preseed/file=/cdrom/preseed.cfg` fails. Inject into initrd instead and use `preseed/file=/preseed.cfg`.
4. **Tasksel: use `tasksel tasksel/first multiselect standard` for baseline packages.** The owner is `tasksel`, not `d-i`. `pkgsel/run_tasksel` defaults to `true` — just don't set it to `false`. The standard task installs all required/important/standard priority packages (man-db, less, bash-completion, etc.). `pkgsel/include` runs independently after tasksel for extra packages.
5. **`priority=critical`** is essential for truly unattended installs — without it the installer asks medium/high priority questions even when preseeded.
6. **`mirror/country string manual`** is the correct value to skip country selection when providing explicit mirror hostname/directory.
7. **`dd` to USB: use `conv=fsync`, not `oflag=sync`.** `oflag=sync` reports impossibly fast speeds (~3.5 GB/s) because the kernel block layer absorbs the writes without actually flushing to the physical device. `conv=fsync` calls `fsync()` after all writes, ensuring data is flushed before dd exits. Real USB 3.0 write speed is ~20-115 MB/s.
8. **USB write caching bug on father.** The Linux kernel marks USB devices as "write through", which means all flush/sync operations (`conv=fsync`, `oflag=direct`, `sync`, `drop_caches`, `blockdev --flushbufs`, `sg_sync`) become no-ops — writes stay in page cache and never reach the physical device. The only reliable fix is rebooting father before writing to USB. Symptoms: impossibly fast dd speeds, or writing `/dev/random` to USB and it still boots the old image.
9. **Graphical installer uses a separate initrd.** `install.amd/gtk/initrd.gz` is the graphical installer's initrd. Preseed must be injected into both `install.amd/initrd.gz` (text) and `install.amd/gtk/initrd.gz` (graphical) for both install paths to work unattended.
10. **Use `partman/early_command`, not `preseed/early_command`, for disk selection.** Disks may not be visible when `preseed/early_command` runs. `partman/early_command` fires just before the partitioner when all block devices are available. Use `list-devices disk` and `list-devices usb-partition` (d-i native utilities) instead of `lsblk` (not available in the installer). Also set `grub-installer/bootdev` alongside `partman-auto/disk`.
11. **The d-i environment is BusyBox ash, not bash.** No bashisms (`[[ ]]`, arrays, `${var//}`, process substitution). Use POSIX shell only. `debconf-set`/`debconf-get` are the d-i utilities for reading/writing debconf values.
12. **GRUB `timeout_style=hidden` hides the menu.** With `timeout=0` the menu never shows. With a non-zero timeout, `timeout_style=hidden` hides the menu but still waits (press Shift/Esc to reveal). Use `timeout=0` + `timeout_style=hidden` + `default=0` for instant silent boot to the first entry.
13. **cpio append doesn't override earlier files in initrd.** Appending a new cpio archive with the same filename to an initrd only adds a second copy — the installer reads the first occurrence. Replacing files inside the graphical initrd (e.g., logo_debian.png) would require full unpack/repack, which is fragile. Stick to initrd append for adding new files only.
14. **Partman confirmation "No" loops.** At the partition confirmation prompt, selecting "No" re-displays the same prompt in a loop. There is no graceful exit — this is standard partman behavior. The prompt is a safety net; the expected answer is "Yes" to proceed.
15. **`efibootmgr --bootnext` enables remote reinstall.** Sets the next boot device without changing the permanent boot order. The firmware clears BootNext after one use. Requires the USB to be plugged in so the firmware has a boot entry for it. The `reinstall` script auto-detects the correct entry by querying `efibootmgr` for `USB.*PART 1`. Fresh installs generate new SSH host keys — clear the old key with `ssh-keygen -R` before reconnecting.
16. **Installed system GRUB defaults to 5s timeout.** The installer's GRUB config (timeout=0, hidden) only applies to the installer boot, not the installed system. Use late_command to set `GRUB_TIMEOUT=0` and append `GRUB_TIMEOUT_STYLE=hidden` in `/etc/default/grub`, then run `update-grub`.
17. **EFI boot entry numbers are non-deterministic.** Entry numbers change per-device and across reboots. Never hardcode them — auto-detect at runtime by querying `efibootmgr` for the expected label pattern (e.g., `USB.*PART 1`). Manually created entries (via `efibootmgr --create`) degrade to generic `VenHw` paths when the drive is removed; firmware-detected entries (created during POST) are more reliable.
18. **Stale EFI entries persist until reboot.** After removing a USB drive, its EFI boot entry remains in NVRAM until the next reboot. Cross-check with `lsblk` for actual removable disk presence before trusting an EFI entry.
19. **Poll loops must sleep on SSH failure.** When polling for a host to come back after reinstall, an SSH connection failure should still sleep before retrying. Without the sleep, the loop spins thousands of times per minute. Use `|| { sleep "$POLL_INTERVAL"; continue; }` pattern.
20. **Uptime gate for fresh install detection.** After reinstall, wait for SSH to return AND verify uptime < 5 minutes. This prevents false positives from the old system coming back briefly before the installer takes over.
21. **`cdrom-detect/eject true` breaks USB after install.** The installer's CD eject leaves the USB drive in a degraded state (detected but 0B size). A warm reboot doesn't recover it — only a power cycle or physical reseat does. This breaks back-to-back reinstalls because the firmware can't read the drive to create EFI boot entries, and `lsblk` shows no valid removable disk. Fix: set `cdrom-detect/eject boolean false`.
