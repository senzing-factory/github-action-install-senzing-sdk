#!/usr/bin/env bash
set -e

############################################
# configure-vars
# GLOBALS:
#   SENZING_INSTALL_VERSION
#     one of: production-v<X>, staging-v<X>
############################################
configure-vars() {

  if [[ $SENZING_INSTALL_VERSION =~ "production" ]]; then

    echo "[INFO] install senzingsdk from production"
    get-generic-major-version
    is-major-version-greater-than-3
    SENZINGSDK_URI="s3://public-read-access/Windows_SDK/"
    SENZINGSDK_URL="https://public-read-access.s3.amazonaws.com/Windows_SDK"

  elif [ -z "$SENZING_INSTALL_VERSION" ] && [ -n "$SENZINGSDK_REPOSITORY_PATH" ]; then

    echo "[INFO] install senzingsdk from supplied repository"
    MAJOR_VERSION=4
    export MAJOR_VERSION
    SENZINGSDK_URI="s3://$SENZINGSDK_REPOSITORY_PATH/"
    SENZINGSDK_URL="https://$SENZINGSDK_REPOSITORY_PATH.s3.amazonaws.com/"

  elif [[ $SENZING_INSTALL_VERSION =~ "staging" ]]; then

    echo "[INFO] install senzingsdk from staging"
    get-generic-major-version
    is-major-version-greater-than-3
    SENZINGSDK_URI="s3://public-read-access/staging/"
    SENZINGSDK_URL="https://public-read-access.s3.amazonaws.com/staging"

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
# determine-latest-zip-for-major-version
# GLOBALS:
#   SENZING_INSTALL_VERSION
#     one of: production-v<X>, staging-v<X>
#   SENZINGSDK_URI
############################################
determine-latest-zip-for-major-version() {

  aws s3 ls "$SENZINGSDK_URI" --recursive --no-sign-request --region us-east-1 | grep -o -E '[^ ]+.zip$' > /tmp/staging-versions
  latest_staging_version=$(< /tmp/staging-versions grep "_$MAJOR_VERSION" | sort -r | head -n 1)
  rm /tmp/staging-versions
  echo "[INFO] latest staging version is: $latest_staging_version"

  SENZINGSDK_ZIP_URL="$SENZINGSDK_URL$latest_staging_version"

}

############################################
# download-zip
# GLOBALS:
#   SENZINGSDK_ZIP_URL
############################################
download-zip() {

  echo "[INFO] curl --output senzingsdk.zip SENZINGSDK_ZIP_URL_REDACTED"
  curl --output senzingsdk.zip "$SENZINGSDK_ZIP_URL"

}


############################################
# install-senzingsdk
############################################
install-senzingsdk() {

  7z x -y -o"$HOME" senzingsdk.zip 

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

  echo "[INFO] verify senzingsdk installation"
  if [ ! -f "$HOME/Senzing/er/szBuildVersion.json" ]; then
    echo "[ERROR] $HOME/Senzing/er/szBuildVersion.json not found."
    exit 1
  else
    echo "[INFO] cat $HOME/Senzing/er/szBuildVersion.json"
    cat "$HOME/Senzing/er/szBuildVersion.json"
  fi

}

############################################
# Main
############################################

configure-vars
determine-latest-zip-for-major-version
download-zip
install-senzingsdk
verify-installation
