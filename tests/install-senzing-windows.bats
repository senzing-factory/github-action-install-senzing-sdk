#!/usr/bin/env bats

# Unit tests for windows/install-senzing.sh dispatch logic.
# Source-loads the script (main() is gated on direct execution) so
# individual functions can be tested in isolation without needing
# scoop, 7z, or AWS.

setup() {
  set +e
  # shellcheck disable=SC1091
  source "${BATS_TEST_DIRNAME}/../windows/install-senzing.sh"
  # Reset env between tests.
  unset WINDOWS_INSTALLER
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
  [ "$WINDOWS_INSTALLER" = "native" ]
}

@test "auto-detect: pinned 4.2.4.26098 -> native" {
  SENZING_INSTALL_VERSION="4.2.4.26098"
  determine-installer >/dev/null 2>&1
  [ "$WINDOWS_INSTALLER" = "native" ]
}

@test "auto-detect: pinned 4.3.0 -> scoop" {
  SENZING_INSTALL_VERSION="4.3.0"
  determine-installer >/dev/null 2>&1
  [ "$WINDOWS_INSTALLER" = "scoop" ]
}

@test "auto-detect: pinned 4.3.1.99999 -> scoop" {
  SENZING_INSTALL_VERSION="4.3.1.99999"
  determine-installer >/dev/null 2>&1
  [ "$WINDOWS_INSTALLER" = "scoop" ]
}

@test "auto-detect: pinned 5.0.0 -> scoop" {
  SENZING_INSTALL_VERSION="5.0.0"
  determine-installer >/dev/null 2>&1
  [ "$WINDOWS_INSTALLER" = "scoop" ]
}

@test "auto-detect: floating staging-v4 -> scoop" {
  SENZING_INSTALL_VERSION="staging-v4"
  determine-installer >/dev/null 2>&1
  [ "$WINDOWS_INSTALLER" = "scoop" ]
}

@test "auto-detect: floating production-v4 -> scoop" {
  SENZING_INSTALL_VERSION="production-v4"
  determine-installer >/dev/null 2>&1
  [ "$WINDOWS_INSTALLER" = "scoop" ]
}

# ---------------------------------------------------------------------------
# determine-installer: explicit override
# ---------------------------------------------------------------------------

@test "explicit scoop on 4.3.0 stays scoop" {
  SENZING_INSTALL_VERSION="4.3.0"
  WINDOWS_INSTALLER="scoop"
  determine-installer >/dev/null 2>&1
  [ "$WINDOWS_INSTALLER" = "scoop" ]
}

@test "explicit native on 4.3.0 stays native" {
  SENZING_INSTALL_VERSION="4.3.0"
  WINDOWS_INSTALLER="native"
  determine-installer >/dev/null 2>&1
  [ "$WINDOWS_INSTALLER" = "native" ]
}

@test "explicit native on floating staging-v4 stays native" {
  SENZING_INSTALL_VERSION="staging-v4"
  WINDOWS_INSTALLER="native"
  determine-installer >/dev/null 2>&1
  [ "$WINDOWS_INSTALLER" = "native" ]
}

# ---------------------------------------------------------------------------
# determine-installer: pre-4.3.0 + scoop -> warn + fallback
# ---------------------------------------------------------------------------

@test "explicit scoop on 4.2.1 warns and falls back to native" {
  SENZING_INSTALL_VERSION="4.2.1"
  WINDOWS_INSTALLER="scoop"
  determine-installer >"${BATS_TEST_TMPDIR}/out" 2>&1
  grep -q "falling back to native" "${BATS_TEST_TMPDIR}/out"
  [ "$WINDOWS_INSTALLER" = "native" ]
}

@test "explicit scoop on 4.0.0 warns and falls back" {
  SENZING_INSTALL_VERSION="4.0.0"
  WINDOWS_INSTALLER="scoop"
  determine-installer >"${BATS_TEST_TMPDIR}/out" 2>&1
  grep -q "pre-4.3.0" "${BATS_TEST_TMPDIR}/out"
  [ "$WINDOWS_INSTALLER" = "native" ]
}

# ---------------------------------------------------------------------------
# determine-installer: invalid input
# ---------------------------------------------------------------------------

@test "invalid windows-installer value errors" {
  SENZING_INSTALL_VERSION="4.3.0"
  WINDOWS_INSTALLER="invalid"
  run determine-installer
  [ "$status" -ne 0 ]
  [[ "$output" =~ "must be 'scoop' or 'native'" ]]
}

@test "scoop + senzingsdk-repository-path is rejected" {
  SENZING_INSTALL_VERSION="4.3.0"
  WINDOWS_INSTALLER="scoop"
  SENZINGSDK_REPOSITORY_PATH="my-bucket"
  run determine-installer
  [ "$status" -ne 0 ]
  [[ "$output" =~ "senzingsdk-repository-path is not supported" ]]
}

@test "native + senzingsdk-repository-path is allowed" {
  SENZING_INSTALL_VERSION="4.3.0"
  WINDOWS_INSTALLER="native"
  SENZINGSDK_REPOSITORY_PATH="my-bucket"
  determine-installer >/dev/null 2>&1
  [ "$WINDOWS_INSTALLER" = "native" ]
}
