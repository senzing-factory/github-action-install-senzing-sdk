#!/usr/bin/env bash
set -eo pipefail

############################################
# configure-vars
# GLOBALS:
#   SENZING_INSTALL_VERSION
#     one of: production-v<X>, staging-v<X>
#             X.Y.Z, X.Y.Z-ABCDE
############################################
configure-vars() {

  # senzing apt repository packages
  PROD_REPO=https://senzing-production-apt.s3.amazonaws.com
  STAGING_REPO=https://senzing-staging-apt.s3.amazonaws.com
  # v4 and above
  PROD_REPO_V4_AND_ABOVE="$PROD_REPO/senzingrepo_2.0.1-1_all.deb"
  STAGING_REPO_V4_AND_ABOVE="$STAGING_REPO/senzingstagingrepo_2.0.1-1_all.deb"

  # semantic versions
  REGEX_SEM_VER="^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$"
  # semantic version with build number
  REGEX_SEM_VER_BUILD_NUM="^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)-([0-9]){5}$"

  # Phase 1: Determine repository
  if [ -n "$SENZINGSDK_REPOSITORY_PATH" ] && [ -n "$SENZINGSDK_REPOSITORY_PACKAGE" ]; then

    echo "[INFO] install $PACKAGES_TO_INSTALL from supplied repository"
    INSTALL_REPO="$SENZINGSDK_REPOSITORY_PATH/$SENZINGSDK_REPOSITORY_PACKAGE"

  elif [[ "$SENZING_INSTALL_VERSION" =~ ^production-v[0-9]+$ ]]; then

    echo "[INFO] install $PACKAGES_TO_INSTALL from production"
    INSTALL_REPO="$PROD_REPO_V4_AND_ABOVE"

  elif [[ "$SENZING_INSTALL_VERSION" =~ ^staging-v[0-9]+$ ]]; then

    echo "[INFO] install $PACKAGES_TO_INSTALL from staging"
    INSTALL_REPO="$STAGING_REPO_V4_AND_ABOVE"

  elif [[ $SENZING_INSTALL_VERSION =~ $REGEX_SEM_VER ]] || [[ $SENZING_INSTALL_VERSION =~ $REGEX_SEM_VER_BUILD_NUM ]]; then

    REPO="${SENZINGSDK_REPOSITORY:-staging}"
    echo "[INFO] install $PACKAGES_TO_INSTALL version $SENZING_INSTALL_VERSION from $REPO"
    if [[ "$REPO" == "production" ]]; then
      INSTALL_REPO="$PROD_REPO_V4_AND_ABOVE"
    else
      INSTALL_REPO="$STAGING_REPO_V4_AND_ABOVE"
    fi

  else
    echo "[ERROR] $PACKAGES_TO_INSTALL install version $SENZING_INSTALL_VERSION is unsupported"
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

  # Phase 3: Determine packages to install
  if [[ $SENZING_INSTALL_VERSION =~ $REGEX_SEM_VER ]]; then
    pin-packages-to-version "$SENZING_INSTALL_VERSION*"
  elif [[ $SENZING_INSTALL_VERSION =~ $REGEX_SEM_VER_BUILD_NUM ]]; then
    pin-packages-to-version "$SENZING_INSTALL_VERSION"
  else
    SENZING_PACKAGES="$PACKAGES_TO_INSTALL"
  fi

}

############################################
# pin-packages-to-version
# Appends version constraint to each package
# name, excluding senzingdata-v* packages.
# ARGS:
#   $1 - version string to pin to
# GLOBALS:
#   PACKAGES_TO_INSTALL
############################################
pin-packages-to-version() {

  local version_pin="$1"
  local updated_packages=""
  IFS=" " read -r -a packages <<< "$PACKAGES_TO_INSTALL"
  for package in "${packages[@]}"
  do
    if [[ ! $package == *"senzingdata-v"* ]]; then
      updated_packages+="$package=$version_pin "
    else
      updated_packages+="$package "
    fi
  done
  SENZING_PACKAGES="$updated_packages"

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
# restrict-major-version
#
# restrict the major version for all found
# senzing packages to avoid dependency
# conflicts
#
# GLOBALS:
#   MAJOR_VERSION
############################################
restrict-major-version() {

  senzing_packages=$(apt list | grep senzing | cut -d '/' -f 1 | grep -v "data" | grep -v "staging" | grep -v "repo") || true
  echo "[INFO] senzing packages: $senzing_packages"

  for package in $senzing_packages
  do
    preferences_file="/etc/apt/preferences.d/$package"
    echo "[INFO] restrict $package major version to: $MAJOR_VERSION"

    echo "Package: $package" | sudo tee -a "$preferences_file"
    echo "Pin: version $MAJOR_VERSION.*" | sudo tee -a "$preferences_file"
    echo "Pin-Priority: 999" | sudo tee -a "$preferences_file"
  done

  echo "[INFO] sudo apt update -qq  > /dev/null"
  sudo apt update -qq  > /dev/null

}

############################################
# install-senzing-repository
# GLOBALS:
#   INSTALL_REPO
#     APT Repository Package URL
############################################
install-senzing-repository() {

  echo "[INFO] wget -qO /tmp/senzingrepo.deb INSTALL_REPO_REDACTED"
  wget -qO /tmp/senzingrepo.deb "$INSTALL_REPO"
  echo "[INFO] sudo apt-get -y -qq install /tmp/senzingrepo.deb > /dev/null"
  sudo apt-get -yqq install /tmp/senzingrepo.deb  > /dev/null
  echo "[INFO] sudo apt-get -qq update > /dev/null"
  sudo apt-get update > /dev/null
  rm /tmp/senzingrepo.deb

}

############################################
# install-senzingsdk
# GLOBALS:
#   SENZING_PACKAGES
#     full package name used for install
############################################
install-senzingsdk() {

  restrict-major-version
  echo "[INFO] sudo apt list | grep senzing | grep -v repo"
  sudo apt list | grep senzing | grep -v repo
  echo "[INFO] sudo --preserve-env apt-get -y -qq install $SENZING_PACKAGES > /dev/null"
  # shellcheck disable=SC2086
  sudo --preserve-env apt-get -y -qq install $SENZING_PACKAGES > /dev/null

}

############################################
# verify-installation
############################################
verify-installation() {

  echo "[INFO] sudo apt list --installed | grep senzing | grep -v repo"
  sudo apt list --installed | grep senzing | grep -v repo

  echo "[INFO] verify senzing installation"
  if [ ! -f "/opt/senzing/er/szBuildVersion.json" ]; then
    echo "[ERROR] /opt/senzing/er/szBuildVersion.json not found."
    exit 1
  else
    echo "[INFO] cat /opt/senzing/er/szBuildVersion.json"
    cat /opt/senzing/er/szBuildVersion.json
  fi

}

############################################
# Main
############################################

echo "[INFO] senzing version to install is: $SENZING_INSTALL_VERSION"
configure-vars
install-senzing-repository
install-senzingsdk
verify-installation
