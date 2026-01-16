#!/usr/bin/env bash
set -e

############################################
# configure-vars
# GLOBALS:
#   SENZING_INSTALL_VERSION
#     one of: production-v<X>, staging-v<X>
############################################
configure-vars() {

  PRODUCTION_URI="s3://senzing-production-osx/"
  PRODUCTION_URL="https://senzing-production-osx.s3.amazonaws.com/"
  STAGING_URI="s3://senzing-staging-osx/"
  STAGING_URL="https://senzing-staging-osx.s3.amazonaws.com/"

  if [[ "$SENZING_INSTALL_VERSION" =~ "production" ]]; then

    echo "[INFO] install senzingsdk from production"
    get-generic-major-version
    is-major-version-greater-than-3
    SENZINGSDK_URI="$PRODUCTION_URI"
    SENZINGSDK_URL="$PRODUCTION_URL"
    determine-latest-dmg-for-major-version

  elif [ -z "$SENZING_INSTALL_VERSION" ] && [ -n "$SENZINGSDK_REPOSITORY_PATH" ]; then

    echo "[INFO] install senzingsdk from supplied repository"
    MAJOR_VERSION=4
    export MAJOR_VERSION
    SENZINGSDK_URI="s3://$SENZINGSDK_REPOSITORY_PATH/"
    SENZINGSDK_URL="https://$SENZINGSDK_REPOSITORY_PATH.s3.amazonaws.com/"
    determine-latest-dmg-for-major-version

  elif [[ "$SENZING_INSTALL_VERSION" =~ "staging" ]]; then

    echo "[INFO] install senzingsdk from staging"
    get-generic-major-version
    is-major-version-greater-than-3
    SENZINGSDK_URI="$STAGING_URI"
    SENZINGSDK_URL="$STAGING_URL"
    determine-latest-dmg-for-major-version

  elif [[ "$SENZING_INSTALL_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]{5}$ ]]; then

    REPO="${SENZINGSDK_REPOSITORY:-staging}"
    echo "[INFO] install senzingsdk version $SENZING_INSTALL_VERSION from $REPO"
    if [[ "$REPO" == "production" ]]; then
      SENZINGSDK_URI="$PRODUCTION_URI"
      SENZINGSDK_URL="$PRODUCTION_URL"
    elif [[ "$REPO" == "staging" ]]; then
      SENZINGSDK_URI="$STAGING_URI"
      SENZINGSDK_URL="$STAGING_URL"
    fi
    MAJOR_VERSION="${SENZING_INSTALL_VERSION:0:1}"
    export MAJOR_VERSION
    is-major-version-greater-than-3
    determine-dmg-for-version

  else
    echo "[ERROR] senzingsdk install version $SENZING_INSTALL_VERSION is unsupported"
    exit 1
  fi 

}

############################################
# get-generic-major-version
# GLOBALS:
#   SENZING_INSTALL_VERSION
#     one of: production-v<X>, staging-v<X>
#     semver does not apply here
############################################
get-generic-major-version(){

  MAJOR_VERSION=$(echo "$SENZING_INSTALL_VERSION" | grep -Eo '[0-9]+$')
  echo "[INFO] major version is: $MAJOR_VERSION"
  export MAJOR_VERSION

}

############################################
# is-major-version-greater-than-3
# GLOBALS:
#   MAJOR_VERSION
#     set prior to this call via
#     get-generic-major-version
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
#   SENZING_INSTALL_VERSION
#     one of: production-v<X>, staging-v<X>
#   SENZINGSDK_URI
############################################
determine-latest-dmg-for-major-version() {

  aws s3 ls "$SENZINGSDK_URI" --recursive --no-sign-request | grep -o -E '[^ ]+.dmg$' > /tmp/staging-versions
  latest_staging_version=$(< /tmp/staging-versions grep "_$MAJOR_VERSION" | sort -r | head -n 1)
  rm /tmp/staging-versions
  echo "[INFO] latest staging version is: $latest_staging_version"

  SENZINGSDK_DMG_URL="$SENZINGSDK_URL$latest_staging_version"

}

############################################
# determine-dmg-for-version
# GLOBALS:
#   SENZING_INSTALL_VERSION
#     one of: production-v<X>, staging-v<X>
#   SENZINGSDK_URI
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

  echo "[INFO] curl --output /tmp/senzingsdk.dmg SENZINGSDK_DMG_URL_REDACTED"
  curl --output /tmp/senzingsdk.dmg "$SENZINGSDK_DMG_URL"

}

############################################
# install-senzing
# GLOBALS:
#   MAJOR_VERSION
#     set prior to this call via either
#     get-generic-major-version or
#     get-semantic-major-version
############################################
install-senzing() {

  ls -tlc /tmp/
  hdiutil attach /tmp/senzingsdk.dmg
  sudo mkdir -p "$HOME"/senzing
  sudo cp -R /Volumes/SenzingSDK/senzing/* "$HOME"/senzing/

}

############################################
# verify-installation
# GLOBALS:
#   MAJOR_VERSION
#     set prior to this call via either
#     get-generic-major-version or
#     get-semantic-major-version
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
verify-installation
