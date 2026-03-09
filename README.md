# Homestak Bare Metal

Automated Debian installation via preseed ISO remastering. Day 0 of the [homestak user journey](https://github.com/homestak-dev/meta/blob/master/docs/roadmap.md): bare hardware to Debian in a single boot.

## Quick Start

```bash
# Build a remastered ISO with your preseed configuration
./build

# Write to USB
./build --usb /dev/sdX

# Remote reinstall (no physical access needed)
./reinstall mother
```

## Requirements

- **xorriso** — ISO extraction and rebuild
- **cpio**, **gzip** — initrd injection
- **isolinux** — hybrid MBR boot (`isohdpfx.bin`)
- **shellcheck** — linting (dev)
- **bats** — testing (dev)

Install all: `make install-deps`

## Usage

### build

Remaster a Debian ISO with a baked-in preseed file for unattended installs.

```
./build [options]

Options:
  -h, --help              Show help
  -n, --dry-run           Show config without building
  -q, --quiet             Suppress xorriso output
  -u, --usb DEVICE        Write to USB after build
  -s, --source-iso PATH   Source ISO (default: iso/debian-13.3.0-amd64-netinst.iso)
  -p, --preseed PATH      Preseed file (default: preseed.cfg)
  -o, --output-iso PATH   Output ISO
  -y, --yes               Skip USB write confirmation
  --partman MODE          confirm (default, prompts before partitioning) or auto (unattended)
  --no-write              Build ISO but skip USB write
```

### reinstall

Remote reinstall via EFI boot-next. Sets the next boot device to the USB installer, reboots, and waits for the fresh system to come up.

```
./reinstall <hostname> [options]

Options:
  -h, --help              Show help
  -n, --dry-run           Show config without acting
  -y, --yes               Skip confirmation
  -b, --boot-entry ENTRY  EFI boot entry (auto-detected if omitted)
  -t, --timeout SECONDS   Poll timeout (default: 1200)
```

## Directory Structure

```
bare-metal/
├── build                   # Entry point — remaster ISO
├── reinstall               # Remote reinstall via efibootmgr
├── preseed.cfg             # Preseed template (CHANGEME placeholders)
├── .secrets                # Password hashes + user identity (gitignored)
├── keys/                   # SSH public keys (gitignored)
├── lib/
│   ├── remaster.sh         # ISO extraction and rebuild (xorriso)
│   ├── inject-preseed.sh   # Secrets substitution + initrd injection
│   ├── patch-bootloader.sh # Boot config patching (GRUB + isolinux)
│   └── splash.png          # Custom boot splash
├── iso/                    # Source + output ISOs (gitignored)
├── test/
│   ├── build.bats          # 20 tests
│   └── reinstall.bats      # 13 tests
└── tools/
    └── preseed-extraction.sh  # Reverse-engineer a running install
```

## Security Model

Secrets are never committed to git:

- **preseed.cfg** contains `CHANGEME_*` placeholders, committed as-is
- **.secrets** provides password hashes and user identity at build time (`inject-preseed.sh` substitutes via sed)
- **keys/*.pub** — SSH public keys injected into the initrd, installed to `~/.ssh/authorized_keys` via late_command

## Testing

```bash
make test    # Run 33 bats tests
make lint    # Shellcheck on all scripts
```

## Related Projects

| Repo | Role |
|------|------|
| [bootstrap](https://github.com/homestak/bootstrap) | Day 1: Debian to homestak platform |
| [config](https://github.com/homestak/config) | Site-specific configuration and secrets |
| [meta](https://github.com/homestak-dev/meta) | Release automation, lifecycle docs |

## License

Apache 2.0 — see [LICENSE](LICENSE).
