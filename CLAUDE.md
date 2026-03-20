# bare-metal

Automated Debian 13 (Trixie) installation via preseed ISO remastering. Day 0 of the homestak user journey: bare hardware to Debian in a single boot.

## Ecosystem Context

This repo is part of the homestak polyrepo workspace. For project architecture,
development lifecycle, sprint/release process, and cross-repo conventions, see:

- `~/homestak/dev/meta/CLAUDE.md` — primary reference
- `docs/lifecycle/` in meta — 7-phase development process
- `docs/CLAUDE-GUIDELINES.md` in meta — documentation standards

When working in a scoped session (this repo only), follow the same sprint/release
process defined in meta. Use `/session save` before context compaction and
`/session resume` to restore state in new sessions.

### Agent Boundaries

This agent operates within the following constraints:

- Opens PRs via `homestak-bot`; never merges without human approval
- Runs lint and validation tools only; never executes infrastructure operations
- Never runs `./build` or `./reinstall`; ISO creation and physical media writes are human-initiated

## Quick Reference

| Command | Description |
|---------|-------------|
| `./build` | Remaster ISO with preseed |
| `./build --dry-run` | Show config without building |
| `./build --usb /dev/sdX` | Build and write to USB |
| `./build --partman auto` | Fully unattended (no partition prompt) |
| `./reinstall <host>` | Remote reinstall via EFI boot-next |
| `./reinstall <host> --dry-run` | Preview without acting |
| `make test` | Run 33 bats tests |
| `make lint` | Shellcheck on all scripts |

## Project Structure

```
bare-metal/
├── build                   # Entry point — remaster ISO
├── reinstall               # Remote reinstall via efibootmgr --bootnext
├── preseed.cfg             # Preseed template (CHANGEME placeholders)
├── .secrets                # Password hashes + user identity (gitignored)
├── keys/                   # SSH public keys (gitignored)
├── lib/
│   ├── remaster.sh         # ISO extraction and rebuild (xorriso)
│   ├── inject-preseed.sh   # Secrets substitution + initrd injection
│   ├── patch-bootloader.sh # Boot config patching (GRUB + isolinux)
│   └── splash.png          # Custom boot splash (640x480)
├── iso/                    # Source + output ISOs (gitignored)
├── test/
│   ├── build.bats          # 20 tests
│   └── reinstall.bats      # 13 tests
└── tools/
    └── preseed-extraction.sh  # Reverse-engineer a running install
```

## Architecture

### Build Pipeline

```
Source ISO → extract_iso → inject_preseed → patch_bootloader → rebuild_iso → [dd to USB]
                              ↑                    ↑
                         .secrets              boot params:
                         keys/*.pub            auto=true priority=critical
                         preseed.cfg           ipv6.disable=1 preseed/file=/preseed.cfg
```

1. **extract_iso** — xorriso extract + replace splash (`lib/remaster.sh`)
2. **inject_preseed** — substitute secrets, apply partman mode, build authorized_keys, cpio+gzip append into both initrds (`lib/inject-preseed.sh`)
3. **patch_bootloader** — sed on grub.cfg, txt.cfg, gtk.cfg, isolinux.cfg (`lib/patch-bootloader.sh`)
4. **rebuild_iso** — xorriso mkisofs hybrid MBR+EFI (`lib/remaster.sh`)

### Security Model

Secrets are never committed to git:
- **preseed.cfg** contains `CHANGEME_*` placeholders (committed)
- **.secrets** provides password hashes and user identity at build time (gitignored)
- **keys/*.pub** — SSH public keys injected into initrd (gitignored)

### Partman Modes

- `--partman confirm` (default): removes auto-confirm lines so installer prompts before partitioning
- `--partman auto`: keeps lines intact for fully unattended installs
- Note: `partman/confirm boolean false` does NOT work — it answers "No" which loops (lesson #14)

### Remote Reinstall

`./reinstall <host>` performs: SSH preflight, auto-detect USB boot entry via `efibootmgr`, set `--bootnext` (one-shot), reboot, poll for SSH + uptime < 5min, verify fresh install.

## Preseed Reference

Boot parameters (go BEFORE `---` separator):
```
auto=true priority=critical ipv6.disable=1 preseed/file=/preseed.cfg --- quiet
```

Key preseed sections: localization, keyboard, network, partman (dynamic disk selection via `early_command`), mirror, clock, partitioning (atomic: EFI + swap + root), account setup (CHANGEME placeholders), packages (standard task + extras), GRUB, late_command (SSH, sudo, authorized_keys, IPv6 disable, instant boot).

## Debugging Tips

- `Alt+F2` on installer console gives a shell
- `cat /preseed.cfg` — verify preseed is in initrd
- `cat /proc/cmdline` — verify boot parameters
- `debconf-get <key>` — check preseed values
- `DEBCONF_DEBUG=5` in boot params for verbose logging
- Installer logs: `/var/log/installer/syslog` on installed system

## Lessons Learned

1. **Smart quotes kill scripts.** Copy-paste from web UIs introduces UTF-8 curly quotes. Verify with `cat -A`.
2. **Preseed params go before `---`** in boot command lines. After `---` is initrd territory.
3. **DVD installer doesn't mount media before preseed is needed.** Inject into initrd, use `preseed/file=/preseed.cfg`.
4. **Tasksel: use `tasksel tasksel/first multiselect standard`** for baseline packages. Owner is `tasksel`, not `d-i`.
5. **`priority=critical`** is essential for unattended installs — without it, medium/high questions still prompt.
6. **`mirror/country string manual`** skips country selection when providing explicit mirror hostname.
7. **`dd` to USB: use `conv=fsync`, not `oflag=sync`.** `oflag=sync` is a no-op at the block layer.
8. **USB write caching bug.** Kernel marks USB as "write through" — all sync ops become no-ops. Reboot before writing to USB.
9. **Graphical installer uses a separate initrd.** Must inject into both `install.amd/initrd.gz` and `install.amd/gtk/initrd.gz`.
10. **Use `partman/early_command`** for disk selection — disks may not be visible during `preseed/early_command`. Use `list-devices` (d-i native), not `lsblk`.
11. **d-i environment is BusyBox ash, not bash.** No bashisms. Use POSIX shell only.
12. **GRUB `timeout_style=hidden`** hides menu. With `timeout=0` + `default=0` = instant silent boot.
13. **cpio append doesn't override earlier files.** Installer reads first occurrence. Use append for new files only.
14. **Partman confirmation "No" loops.** Selecting "No" re-displays the prompt. Remove the lines entirely to require confirmation.
15. **`efibootmgr --bootnext` enables remote reinstall.** One-shot, firmware clears after use. Fresh installs change SSH host keys.
16. **Installed GRUB defaults to 5s timeout.** Use late_command to set `GRUB_TIMEOUT=0` + `GRUB_TIMEOUT_STYLE=hidden`.
17. **EFI boot entry numbers are non-deterministic.** Auto-detect at runtime, never hardcode.
18. **Stale EFI entries persist until reboot.** Cross-check with `lsblk` for actual USB presence.
19. **Poll loops must sleep on SSH failure.** Use `|| { sleep "$POLL_INTERVAL"; continue; }` pattern.
20. **Uptime gate for fresh install detection.** Verify uptime < 5 minutes to avoid false positives.
21. **`cdrom-detect/eject true` breaks USB after install.** Leaves drive in degraded state. Use `cdrom-detect/eject boolean false`.

## Planned Improvements

- YAML host config templating (`generate-preseed.sh` + `preseed.template`)
- Config integration for secrets and defaults
- `--host` flag for build entry point

## Related Projects

| Repo | Role |
|------|------|
| [bootstrap](https://github.com/homestak/bootstrap) | Day 1: Debian to homestak platform |
| [config](https://github.com/homestak/config) | Site-specific configuration and secrets |
| [meta](https://github.com/homestak-dev/meta) | Release automation, lifecycle docs |

## License

Apache 2.0
