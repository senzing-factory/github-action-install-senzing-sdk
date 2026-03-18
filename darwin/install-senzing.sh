#!/usr/bin/env bash
set -eo pipefail

# Clean up temp files on exit
trap 'rm -f /tmp/staging-versions /tmp/senzingsdk.dmg' EXIT

############################################
# configure-vars
# GLOBALS:
#   SENZING_INSTALL_VERSION
#     one of: production-v<X>, staging-v<X>
#             X.Y.Z, X.Y.Z.ABCDE
############################################
configure-vars() {

  PRODUCTION_URI="s3://senzing-production-osx/"
  PRODUCTION_URL="https://senzing-production-osx.s3.amazonaws.com/"
  STAGING_URI="s3://senzing-staging-osx/"
  STAGING_URL="https://senzing-staging-osx.s3.amazonaws.com/"

  # Phase 1: Determine repository
  if [ -n "$SENZINGSDK_REPOSITORY_PATH" ]; then

    echo "[INFO] install senzingsdk from supplied repository"
    SENZINGSDK_URI="s3://$SENZINGSDK_REPOSITORY_PATH/"
    SENZINGSDK_URL="https://$SENZINGSDK_REPOSITORY_PATH.s3.amazonaws.com/"

  elif [[ "$SENZING_INSTALL_VERSION" =~ ^production-v[0-9]+$ ]]; then

    echo "[INFO] install senzingsdk from production"
    SENZINGSDK_URI="$PRODUCTION_URI"
    SENZINGSDK_URL="$PRODUCTION_URL"

  elif [[ "$SENZING_INSTALL_VERSION" =~ ^staging-v[0-9]+$ ]]; then

    echo "[INFO] install senzingsdk from staging"
    SENZINGSDK_URI="$STAGING_URI"
    SENZINGSDK_URL="$STAGING_URL"

  elif [[ "$SENZING_INSTALL_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then

    REPO="${SENZINGSDK_REPOSITORY:-staging}"
    echo "[INFO] install senzingsdk version $SENZING_INSTALL_VERSION from $REPO"
    if [[ "$REPO" == "production" ]]; then
      SENZINGSDK_URI="$PRODUCTION_URI"
      SENZINGSDK_URL="$PRODUCTION_URL"
    else
      SENZINGSDK_URI="$STAGING_URI"
      SENZINGSDK_URL="$STAGING_URL"
    fi

  else
    echo "[ERROR] senzingsdk install version $SENZING_INSTALL_VERSION is unsupported"
    exit 1
  fi

  # Phase 2: Determine major version
  if [[ "$SENZING_INSTALL_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    MAJOR_VERSION="${SENZING_INSTALL_VERSION%%.*}"
  else
    MAJOR_VERSION=$(echo "$SENZING_INSTALL_VERSION" | grep -Eo '[0-9]+$')
  fi
  export MAJOR_VERSION
  echo "[INFO] major version is: $MAJOR_VERSION"
  is-major-version-greater-than-3

  # Phase 3: Determine artifact to download
  if [[ "$SENZING_INSTALL_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]{5}$ ]]; then
    determine-dmg-for-version
  elif [[ "$SENZING_INSTALL_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    determine-latest-dmg-for-semver
  else
    determine-latest-dmg-for-major-version
  fi

}

############################################
# is-major-version-greater-than-3
# GLOBALS:
#   MAJOR_VERSION
############################################
is-major-version-greater-than-3() {

  if [[ $MAJOR_VERSION -gt 3 ]]; then
    return 0
  else
    echo "[ERROR] this action only supports senzing major versions 4 and higher"
    echo "[ERROR] please refer to https://github.com/senzing-factory/github-action-install-senzing-api"
    echo "[ERROR] for installing senzing versions 3 and lower"
    exit 1
  fi

}

############################################
# determine-latest-dmg-for-major-version
# GLOBALS:
#   MAJOR_VERSION
#   SENZINGSDK_URI
#   SENZINGSDK_URL
############################################
determine-latest-dmg-for-major-version() {

  aws s3 ls "$SENZINGSDK_URI" --recursive --no-sign-request | grep -o -E '[^ ]+\.dmg$' > /tmp/staging-versions
  latest_staging_version=$(grep "_${MAJOR_VERSION}" /tmp/staging-versions | sort -r | head -n 1) || true
  rm -f /tmp/staging-versions
  if [ -z "$latest_staging_version" ]; then
    echo "[ERROR] no DMG found for major version $MAJOR_VERSION"
    exit 1
  fi
  echo "[INFO] latest version for major version $MAJOR_VERSION is: $latest_staging_version"

  SENZINGSDK_DMG_URL="$SENZINGSDK_URL$latest_staging_version"

}

############################################
# determine-latest-dmg-for-semver
# GLOBALS:
#   SENZING_INSTALL_VERSION
#   SENZINGSDK_URI
#   SENZINGSDK_URL
############################################
determine-latest-dmg-for-semver() {

  aws s3 ls "$SENZINGSDK_URI" --recursive --no-sign-request | grep -o -E '[^ ]+\.dmg$' > /tmp/staging-versions
  latest_semver_version=$(grep "_${SENZING_INSTALL_VERSION}\." /tmp/staging-versions | sort -r | head -n 1) || true
  rm -f /tmp/staging-versions
  if [ -z "$latest_semver_version" ]; then
    echo "[ERROR] no DMG found for version $SENZING_INSTALL_VERSION"
    exit 1
  fi
  echo "[INFO] latest build for $SENZING_INSTALL_VERSION is: $latest_semver_version"

  SENZINGSDK_DMG_URL="$SENZINGSDK_URL$latest_semver_version"

}

############################################
# determine-dmg-for-version
# GLOBALS:
#   SENZING_INSTALL_VERSION
#   SENZINGSDK_URL
############################################
determine-dmg-for-version() {

  SENZINGSDK_DMG_URL="$SENZINGSDK_URL"senzingsdk_"$SENZING_INSTALL_VERSION".dmg

}

############################################
# download-dmg
# GLOBALS:
#   SENZINGSDK_DMG_URL
############################################
download-dmg() {

  echo "[INFO] curl --fail --output /tmp/senzingsdk.dmg SENZINGSDK_DMG_URL_REDACTED"
  curl --fail --output /tmp/senzingsdk.dmg "$SENZINGSDK_DMG_URL"

}

############################################
# install-openssl
# Temporary workaround: SDK DMG no longer
# bundles OpenSSL 3 (will ship as a Homebrew
# dependency once the brew install path is
# ready). Remove when switching to brew
# install --cask senzing-sdk.
############################################
install-openssl() {

  local version
  version=$(grep -o '"VERSION": "[^"]*"' "$HOME"/senzing/er/szBuildVersion.json | cut -d'"' -f4)
  local major minor _patch
  IFS='.' read -r major minor _patch <<< "$version"

  if [[ "$major" -gt 4 ]] || { [[ "$major" -eq 4 ]] && [[ "$minor" -ge 3 ]]; }; then
    echo "[INFO] SDK version $version requires OpenSSL 3, installing via Homebrew (temporary workaround)"
    brew install openssl@3
  else
    echo "[INFO] SDK version $version bundles OpenSSL, skipping Homebrew install"
  fi

}

############################################
# install-senzing
############################################
install-senzing() {

  ls -tlc /tmp/
  hdiutil attach /tmp/senzingsdk.dmg
  sudo mkdir -p "$HOME"/senzing
  sudo cp -R /Volumes/SenzingSDK/senzing/* "$HOME"/senzing/
  hdiutil detach /Volumes/SenzingSDK

}

############################################
# verify-installation
############################################
verify-installation() {

  echo "[INFO] verify senzing installation"
  if [ ! -f "$HOME"/senzing/er/szBuildVersion.json ]; then
    echo "[ERROR] $HOME/senzing/er/szBuildVersion.json not found."
    exit 1
  else
    echo "[INFO] cat $HOME/senzing/er/szBuildVersion.json"
    cat "$HOME"/senzing/er/szBuildVersion.json
  fi

}

############################################
# Main
############################################

configure-vars
download-dmg
install-senzing
install-openssl
verify-installation
