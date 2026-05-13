#!/usr/bin/env bats

# Unit tests for darwin/install-senzing.sh dispatch logic.
# Source-loads the script (main() is gated on direct execution) so
# individual functions can be tested in isolation without needing
# brew, hdiutil, or AWS.

setup() {
  # Sourcing with set -e tripped on the trap; disable it for tests.
  set +e
  # shellcheck disable=SC1091
  source "${BATS_TEST_DIRNAME}/../darwin/install-senzing.sh"
  # Reset env between tests.
  unset DARWIN_INSTALLER
  unset SENZINGSDK_REPOSITORY
  unset SENZINGSDK_REPOSITORY_PATH
  unset SENZINGSDK_TOKEN
}

# ---------------------------------------------------------------------------
# determine-installer: auto-detect rules
# ---------------------------------------------------------------------------

@test "auto-detect: pinned 4.2.1 -> native" {
  SENZING_INSTALL_VERSION="4.2.1"
  determine-installer >/dev/null 2>&1
  [ "$DARWIN_INSTALLER" = "native" ]
}

@test "auto-detect: pinned 4.2.4.26098 -> native" {
  SENZING_INSTALL_VERSION="4.2.4.26098"
  determine-installer >/dev/null 2>&1
  [ "$DARWIN_INSTALLER" = "native" ]
}

@test "auto-detect: pinned 4.3.0 -> homebrew" {
  SENZING_INSTALL_VERSION="4.3.0"
  determine-installer >/dev/null 2>&1
  [ "$DARWIN_INSTALLER" = "homebrew" ]
}

@test "auto-detect: pinned 4.3.1.99999 -> homebrew" {
  SENZING_INSTALL_VERSION="4.3.1.99999"
  determine-installer >/dev/null 2>&1
  [ "$DARWIN_INSTALLER" = "homebrew" ]
}

@test "auto-detect: pinned 5.0.0 -> homebrew" {
  SENZING_INSTALL_VERSION="5.0.0"
  determine-installer >/dev/null 2>&1
  [ "$DARWIN_INSTALLER" = "homebrew" ]
}

@test "auto-detect: floating staging-v4 -> native (transition default)" {
  SENZING_INSTALL_VERSION="staging-v4"
  determine-installer >/dev/null 2>&1
  [ "$DARWIN_INSTALLER" = "native" ]
}

@test "auto-detect: floating production-v4 -> native (transition default)" {
  SENZING_INSTALL_VERSION="production-v4"
  determine-installer >/dev/null 2>&1
  [ "$DARWIN_INSTALLER" = "native" ]
}

# ---------------------------------------------------------------------------
# determine-installer: explicit override
# ---------------------------------------------------------------------------

@test "explicit homebrew on 4.3.0 stays homebrew" {
  SENZING_INSTALL_VERSION="4.3.0"
  DARWIN_INSTALLER="homebrew"
  determine-installer >/dev/null 2>&1
  [ "$DARWIN_INSTALLER" = "homebrew" ]
}

@test "explicit native on 4.3.0 stays native" {
  SENZING_INSTALL_VERSION="4.3.0"
  DARWIN_INSTALLER="native"
  determine-installer >/dev/null 2>&1
  [ "$DARWIN_INSTALLER" = "native" ]
}

@test "explicit homebrew on floating staging-v4 stays homebrew" {
  SENZING_INSTALL_VERSION="staging-v4"
  DARWIN_INSTALLER="homebrew"
  determine-installer >/dev/null 2>&1
  [ "$DARWIN_INSTALLER" = "homebrew" ]
}

# ---------------------------------------------------------------------------
# determine-installer: pre-4.3.0 + homebrew -> warn + fallback
# ---------------------------------------------------------------------------

@test "explicit homebrew on 4.2.1 warns and falls back to native" {
  SENZING_INSTALL_VERSION="4.2.1"
  DARWIN_INSTALLER="homebrew"
  determine-installer >"${BATS_TEST_TMPDIR}/out" 2>&1
  grep -q "falling back to native" "${BATS_TEST_TMPDIR}/out"
  [ "$DARWIN_INSTALLER" = "native" ]
}

@test "explicit homebrew on 4.0.0 warns and falls back" {
  SENZING_INSTALL_VERSION="4.0.0"
  DARWIN_INSTALLER="homebrew"
  determine-installer >"${BATS_TEST_TMPDIR}/out" 2>&1
  grep -q "pre-4.3.0" "${BATS_TEST_TMPDIR}/out"
  [ "$DARWIN_INSTALLER" = "native" ]
}

# ---------------------------------------------------------------------------
# determine-installer: invalid input
# ---------------------------------------------------------------------------

@test "invalid darwin-installer value errors" {
  SENZING_INSTALL_VERSION="4.3.0"
  DARWIN_INSTALLER="invalid"
  run determine-installer
  [ "$status" -ne 0 ]
  [[ "$output" =~ "must be 'homebrew' or 'native'" ]]
}

@test "homebrew + senzingsdk-repository-path is rejected" {
  SENZING_INSTALL_VERSION="4.3.0"
  DARWIN_INSTALLER="homebrew"
  SENZINGSDK_REPOSITORY_PATH="my-bucket"
  run determine-installer
  [ "$status" -ne 0 ]
  [[ "$output" =~ "senzingsdk-repository-path is not supported" ]]
}

@test "native + senzingsdk-repository-path is allowed" {
  SENZING_INSTALL_VERSION="4.3.0"
  DARWIN_INSTALLER="native"
  SENZINGSDK_REPOSITORY_PATH="my-bucket"
  determine-installer >/dev/null 2>&1
  [ "$DARWIN_INSTALLER" = "native" ]
}
