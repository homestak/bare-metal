# Changelog

## [Unreleased]

## v0.56 - 2026-03-09

No changes.

## v0.55 - 2026-03-08

### Added
- ISO remaster tooling for Debian 13 with preseed injection
- Remote reinstall via `efibootmgr --bootnext` (no physical access needed)
- Custom Homestak boot splash
- Dynamic disk selection via `partman/early_command` (smallest non-USB disk)
- Secrets substitution from `.secrets` at build time
- SSH public key injection from `keys/*.pub` directory
- Partman modes: `confirm` (safe, prompts) and `auto` (fully unattended)
- 33 bats tests (20 build, 13 reinstall)
- Preseed extraction utility for reverse-engineering installs
