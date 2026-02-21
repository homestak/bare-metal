#!/usr/bin/env bats

setup() {
    BUILD="$BATS_TEST_DIRNAME/../build"
}

# --- Help -------------------------------------------------------------------

@test "--help shows usage" {
    run "$BUILD" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"--dry-run"* ]]
}

@test "-h shows usage" {
    run "$BUILD" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

# --- Unknown options --------------------------------------------------------

@test "unknown option fails with error" {
    run "$BUILD" --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option: --bogus"* ]]
    [[ "$output" == *"--help"* ]]
}

# --- Dry run ----------------------------------------------------------------

@test "--dry-run shows config without building" {
    run "$BUILD" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Dry run"* ]]
    [[ "$output" == *"Source ISO:"* ]]
    [[ "$output" == *"Preseed:"* ]]
    [[ "$output" == *"Output ISO:"* ]]
}

@test "--dry-run reflects --usb flag" {
    run "$BUILD" --dry-run --usb /dev/sda
    [ "$status" -eq 0 ]
    [[ "$output" == *"USB device:  /dev/sda"* ]]
}

@test "--dry-run reflects --quiet flag" {
    run "$BUILD" --dry-run --quiet
    [ "$status" -eq 0 ]
    [[ "$output" == *"Quiet:       true"* ]]
}

@test "--dry-run reflects --yes flag" {
    run "$BUILD" --dry-run --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"Yes:         true"* ]]
}

@test "--dry-run reflects --no-write flag" {
    run "$BUILD" --dry-run --no-write
    [ "$status" -eq 0 ]
    [[ "$output" == *"No write:    true"* ]]
}

@test "--dry-run reflects --source-iso flag" {
    run "$BUILD" --dry-run --source-iso /tmp/custom.iso
    [ "$status" -eq 0 ]
    [[ "$output" == *"Source ISO:  /tmp/custom.iso"* ]]
}

@test "--dry-run reflects --preseed flag" {
    run "$BUILD" --dry-run --preseed /tmp/custom.cfg
    [ "$status" -eq 0 ]
    [[ "$output" == *"Preseed:     /tmp/custom.cfg"* ]]
}

@test "--dry-run reflects --output-iso flag" {
    run "$BUILD" --dry-run --output-iso /tmp/out.iso
    [ "$status" -eq 0 ]
    [[ "$output" == *"Output ISO:  /tmp/out.iso"* ]]
}

@test "env vars work as defaults" {
    USB_DEVICE=/dev/sdb run "$BUILD" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"USB device:  /dev/sdb"* ]]
}

@test "flags override env vars" {
    USB_DEVICE=/dev/sdb run "$BUILD" --dry-run --usb /dev/sdc
    [ "$status" -eq 0 ]
    [[ "$output" == *"USB device:  /dev/sdc"* ]]
}

@test "short flags work" {
    run "$BUILD" -n -u /dev/sda -s /tmp/src.iso -p /tmp/ps.cfg -o /tmp/out.iso
    [ "$status" -eq 0 ]
    [[ "$output" == *"Source ISO:  /tmp/src.iso"* ]]
    [[ "$output" == *"Preseed:     /tmp/ps.cfg"* ]]
    [[ "$output" == *"Output ISO:  /tmp/out.iso"* ]]
    [[ "$output" == *"USB device:  /dev/sda"* ]]
}

# --- Preflight errors -------------------------------------------------------

@test "missing source ISO fails" {
    run "$BUILD" --source-iso /tmp/nonexistent.iso
    [ "$status" -eq 1 ]
    [[ "$output" == *"Source ISO not found"* ]]
}

@test "missing preseed file fails" {
    run "$BUILD" --preseed /tmp/nonexistent.cfg
    [ "$status" -eq 1 ]
    [[ "$output" == *"Preseed file not found"* ]]
}
