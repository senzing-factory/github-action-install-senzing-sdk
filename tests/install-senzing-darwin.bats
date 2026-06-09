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
  # Reset env between tests. Every test sets SENZING_INSTALL_VERSION
  # explicitly today, but clearing it here keeps future tests honest.
  unset SENZING_INSTALL_VERSION
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

@test "auto-detect: floating staging-v4 -> homebrew" {
  SENZING_INSTALL_VERSION="staging-v4"
  determine-installer >/dev/null 2>&1
  [ "$DARWIN_INSTALLER" = "homebrew" ]
}

@test "auto-detect: floating production-v4 -> homebrew" {
  SENZING_INSTALL_VERSION="production-v4"
  determine-installer >/dev/null 2>&1
  [ "$DARWIN_INSTALLER" = "homebrew" ]
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

# ---------------------------------------------------------------------------
# is-modern-build-format: 4.3.2 is the cutoff for .pkg-only builds
# ---------------------------------------------------------------------------

@test "is-modern-build-format: 4.3.2 -> modern" { is-modern-build-format "4.3.2"; }
@test "is-modern-build-format: 4.3.2.26159 -> modern" { is-modern-build-format "4.3.2.26159"; }
@test "is-modern-build-format: 4.3.3 -> modern" { is-modern-build-format "4.3.3"; }
@test "is-modern-build-format: 4.4.0 -> modern" { is-modern-build-format "4.4.0"; }
@test "is-modern-build-format: 5.0.0 -> modern" { is-modern-build-format "5.0.0"; }

@test "is-modern-build-format: 4.3.1 -> legacy" { ! is-modern-build-format "4.3.1"; }
@test "is-modern-build-format: 4.3.1.99999 -> legacy" { ! is-modern-build-format "4.3.1.99999"; }
@test "is-modern-build-format: 4.3.0 -> legacy" { ! is-modern-build-format "4.3.0"; }
@test "is-modern-build-format: 4.2.4 -> legacy" { ! is-modern-build-format "4.2.4"; }
@test "is-modern-build-format: 3.10.3 -> legacy" { ! is-modern-build-format "3.10.3"; }

# ---------------------------------------------------------------------------
# determine-build-for-version: URL extension follows the threshold
# ---------------------------------------------------------------------------

@test "determine-build-for-version: 4.3.2.26159 -> .pkg URL" {
  SENZING_INSTALL_VERSION="4.3.2.26159"
  SENZINGSDK_URL="https://example.com/"
  determine-build-for-version
  [ "$SENZINGSDK_BUILD_URL" = "https://example.com/senzingsdk_4.3.2.26159.pkg" ]
}

@test "determine-build-for-version: 4.3.1.99999 -> .dmg URL" {
  SENZING_INSTALL_VERSION="4.3.1.99999"
  SENZINGSDK_URL="https://example.com/"
  determine-build-for-version
  [ "$SENZINGSDK_BUILD_URL" = "https://example.com/senzingsdk_4.3.1.99999.dmg" ]
}

@test "determine-build-for-version: 4.2.4.26098 -> .dmg URL" {
  SENZING_INSTALL_VERSION="4.2.4.26098"
  SENZINGSDK_URL="https://example.com/"
  determine-build-for-version
  [ "$SENZINGSDK_BUILD_URL" = "https://example.com/senzingsdk_4.2.4.26098.dmg" ]
}

@test "determine-build-for-version: 5.0.0.12345 -> .pkg URL" {
  SENZING_INSTALL_VERSION="5.0.0.12345"
  SENZINGSDK_URL="https://example.com/"
  determine-build-for-version
  [ "$SENZINGSDK_BUILD_URL" = "https://example.com/senzingsdk_5.0.0.12345.pkg" ]
}
