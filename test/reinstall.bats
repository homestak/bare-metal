#!/usr/bin/env bats

setup() {
    REINSTALL="$BATS_TEST_DIRNAME/../reinstall"
}

# --- Help -------------------------------------------------------------------

@test "--help shows usage" {
    run "$REINSTALL" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"--dry-run"* ]]
}

@test "-h shows usage" {
    run "$REINSTALL" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

# --- Unknown options --------------------------------------------------------

@test "unknown option fails with error" {
    run "$REINSTALL" --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option: --bogus"* ]]
    [[ "$output" == *"--help"* ]]
}

# --- Missing hostname -------------------------------------------------------

@test "missing hostname fails with error" {
    run "$REINSTALL" --dry-run
    [ "$status" -eq 1 ]
    [[ "$output" == *"hostname required"* ]]
}

# --- Dry run ----------------------------------------------------------------

@test "--dry-run shows config" {
    run "$REINSTALL" myhost --dry-run --boot-entry 0005
    [ "$status" -eq 0 ]
    [[ "$output" == *"Dry run"* ]]
    [[ "$output" == *"Host:        myhost"* ]]
    [[ "$output" == *"Boot entry:  0005"* ]]
    [[ "$output" == *"Timeout:"* ]]
}

@test "--dry-run reflects --boot-entry flag" {
    run "$REINSTALL" mother --dry-run --boot-entry 000B
    [ "$status" -eq 0 ]
    [[ "$output" == *"Boot entry:  000B"* ]]
}

@test "--dry-run reflects --timeout flag" {
    run "$REINSTALL" mother --dry-run --timeout 600
    [ "$status" -eq 0 ]
    [[ "$output" == *"Timeout:     600s"* ]]
}

@test "--dry-run reflects --yes flag" {
    run "$REINSTALL" mother --dry-run --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"Yes:         true"* ]]
}

@test "env vars work as defaults" {
    REINSTALL_BOOT_ENTRY=000B run "$REINSTALL" mother --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Boot entry:  000B"* ]]
}

@test "flags override env vars" {
    REINSTALL_BOOT_ENTRY=000B run "$REINSTALL" mother --dry-run --boot-entry 000C
    [ "$status" -eq 0 ]
    [[ "$output" == *"Boot entry:  000C"* ]]
}

@test "short flags work" {
    run "$REINSTALL" mother -n -y -b 000B -t 600
    [ "$status" -eq 0 ]
    [[ "$output" == *"Boot entry:  000B"* ]]
    [[ "$output" == *"Timeout:     600s"* ]]
    [[ "$output" == *"Yes:         true"* ]]
}

@test "hostname captured as positional arg" {
    run "$REINSTALL" myhost --dry-run -b 0005
    [ "$status" -eq 0 ]
    [[ "$output" == *"Host:        myhost"* ]]
}

@test "hostname works between flags" {
    run "$REINSTALL" -n myhost -y -b 0005
    [ "$status" -eq 0 ]
    [[ "$output" == *"Host:        myhost"* ]]
    [[ "$output" == *"Yes:         true"* ]]
}
