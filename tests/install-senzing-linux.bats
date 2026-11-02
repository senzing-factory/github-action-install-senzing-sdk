#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# Static checks on linux/install-senzing.sh.
#
# Unlike darwin/install-senzing.sh, this script is NOT gated on direct
# execution -- sourcing it runs configure-vars, installs a repository and
# calls apt. So its functions cannot be exercised in isolation, and these
# assert the SHAPE of the file instead.
#
# That is not a lesser test here: the defect these guard against (#68) is a
# property of how the command is written, and it reproduces only on a runner
# image that `ubuntu-latest` resolves to intermittently. A test that depends
# on the image cannot be relied on to run at all.

SCRIPT="${BATS_TEST_DIRNAME}/../linux/install-senzing.sh"

@test "the install command names SENZING_ACCEPT_EULA explicitly" {
  run grep -c 'sudo SENZING_ACCEPT_EULA="\$SENZING_ACCEPT_EULA"' "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "no bare --preserve-env anywhere in the script" {
  # Ubuntu 26.04's sudo-rs ignores it and logs that it has done so, which
  # silently drops the EULA acceptance and makes apt wait for input. #68.
  # Comment lines are excluded deliberately -- the comment above the fixed
  # command names the flag in order to explain why it is not used.
  run grep -c "^[^#]*--preserve-env\([^=]\|$\)" "$SCRIPT"
  [ "$output" -eq 0 ]
}

@test "the install runs with a non-interactive apt frontend" {
  # Belt and braces: if any variable the package script wants is ever missing
  # again, apt must fail rather than wait for a terminal that is not there.
  run grep -c 'DEBIAN_FRONTEND=noninteractive' "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "the script still installs the packages it was asked for" {
  run grep -c 'apt-get -y -qq install \$SENZING_PACKAGES' "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "the install refuses to start without SENZING_ACCEPT_EULA" {
  # A hang with an empty log is the defect; an immediate named error is the
  # fix. The guard must sit BEFORE the apt call, or it guards nothing.
  guard=$(grep -n 'SENZING_ACCEPT_EULA:?' "$SCRIPT" | cut -d: -f1)
  apt=$(grep -n 'apt-get -y -qq install \$SENZING_PACKAGES' "$SCRIPT" | tail -1 | cut -d: -f1)
  [ -n "$guard" ]
  [ -n "$apt" ]
  [ "$guard" -lt "$apt" ]
}
