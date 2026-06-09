#!/usr/bin/env bats

# `run !` was added in bats 1.5.0; declaring the minimum keeps bats
# from emitting a "BW02" warning at runtime.
bats_require_minimum_version 1.5.0

# Unit tests for windows/install-senzing.sh dispatch logic.
# Source-loads the script (main() is gated on direct execution) so
# individual functions can be tested in isolation without needing
# scoop, 7z, or AWS.

setup() {
  set +e
  # shellcheck disable=SC1091
  source "${BATS_TEST_DIRNAME}/../windows/install-senzing.sh"
  # Reset env between tests. Every test sets SENZING_INSTALL_VERSION
  # explicitly today, but clearing it here keeps future tests honest.
  unset SENZING_INSTALL_VERSION
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

# ---------------------------------------------------------------------------
# is-modern-build-format: 4.3.2 is the cutoff for .msi-only builds
# ---------------------------------------------------------------------------

@test "is-modern-build-format: 4.3.2 -> modern" { is-modern-build-format "4.3.2"; }
@test "is-modern-build-format: 4.3.2.26159 -> modern" { is-modern-build-format "4.3.2.26159"; }
@test "is-modern-build-format: 4.3.3 -> modern" { is-modern-build-format "4.3.3"; }
@test "is-modern-build-format: 4.4.0 -> modern" { is-modern-build-format "4.4.0"; }
@test "is-modern-build-format: 5.0.0 -> modern" { is-modern-build-format "5.0.0"; }

@test "is-modern-build-format: 4.3.1 -> legacy" { run ! is-modern-build-format "4.3.1"; }
@test "is-modern-build-format: 4.3.1.99999 -> legacy" { run ! is-modern-build-format "4.3.1.99999"; }
@test "is-modern-build-format: 4.3.0 -> legacy" { run ! is-modern-build-format "4.3.0"; }
@test "is-modern-build-format: 4.2.4 -> legacy" { run ! is-modern-build-format "4.2.4"; }
@test "is-modern-build-format: 3.10.3 -> legacy" { run ! is-modern-build-format "3.10.3"; }

# ---------------------------------------------------------------------------
# determine-build-for-version: URL extension follows the threshold
# ---------------------------------------------------------------------------

@test "determine-build-for-version: 4.3.2.26159 -> .msi URL" {
  SENZING_INSTALL_VERSION="4.3.2.26159"
  SENZINGSDK_URL="https://example.com/"
  determine-build-for-version
  [ "$SENZINGSDK_BUILD_URL" = "https://example.com/SenzingSDK_4.3.2.26159.msi" ]
}

@test "determine-build-for-version: 4.3.1.99999 -> .zip URL" {
  SENZING_INSTALL_VERSION="4.3.1.99999"
  SENZINGSDK_URL="https://example.com/"
  determine-build-for-version
  [ "$SENZINGSDK_BUILD_URL" = "https://example.com/SenzingSDK_4.3.1.99999.zip" ]
}

@test "determine-build-for-version: 4.2.4.26098 -> .zip URL" {
  SENZING_INSTALL_VERSION="4.2.4.26098"
  SENZINGSDK_URL="https://example.com/"
  determine-build-for-version
  [ "$SENZINGSDK_BUILD_URL" = "https://example.com/SenzingSDK_4.2.4.26098.zip" ]
}

@test "determine-build-for-version: 5.0.0.12345 -> .msi URL" {
  SENZING_INSTALL_VERSION="5.0.0.12345"
  SENZINGSDK_URL="https://example.com/"
  determine-build-for-version
  [ "$SENZINGSDK_BUILD_URL" = "https://example.com/SenzingSDK_5.0.0.12345.msi" ]
}

# ---------------------------------------------------------------------------
# determine-scoop-version: 4-part build skips S3 lookup; filename and pin
# version are derived from the version + threshold.
# ---------------------------------------------------------------------------

@test "determine-scoop-version: 4-part 4.3.2.26159 -> .msi filename" {
  SENZING_INSTALL_VERSION="4.3.2.26159"
  determine-scoop-version >/dev/null 2>&1
  [ "$SCOOP_PIN_VERSION" = "4.3.2.26159" ]
  [ "$SCOOP_PIN_FILENAME" = "SenzingSDK_4.3.2.26159.msi" ]
}

@test "determine-scoop-version: 4-part 4.3.1.99999 -> .zip filename" {
  SENZING_INSTALL_VERSION="4.3.1.99999"
  determine-scoop-version >/dev/null 2>&1
  [ "$SCOOP_PIN_VERSION" = "4.3.1.99999" ]
  [ "$SCOOP_PIN_FILENAME" = "SenzingSDK_4.3.1.99999.zip" ]
}

@test "determine-scoop-version: floating staging-v4 -> empty pin" {
  SENZING_INSTALL_VERSION="staging-v4"
  determine-scoop-version >/dev/null 2>&1
  [ -z "$SCOOP_PIN_VERSION" ]
  [ -z "$SCOOP_PIN_FILENAME" ]
}
