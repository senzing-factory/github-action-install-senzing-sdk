#!/usr/bin/env bash
set -e

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

  if [ -z "$SENZING_INSTALL_VERSION" ] && [ -n "$SENZINGSDK_REPOSITORY_PATH" ] && [ -n "$SENZINGSDK_REPOSITORY_PACKAGE" ]; then

    echo "[INFO] install $PACKAGES_TO_INSTALL from supplied repository"
    MAJOR_VERSION=4
    export MAJOR_VERSION
    INSTALL_REPO="$SENZINGSDK_REPOSITORY_PATH/$SENZINGSDK_REPOSITORY_PACKAGE"
    SENZING_PACKAGES="$PACKAGES_TO_INSTALL"

  elif [[ $SENZING_INSTALL_VERSION =~ "production" ]]; then

    echo "[INFO] install $PACKAGES_TO_INSTALL from production"
    get-generic-major-version
    is-major-version-greater-than-3
    INSTALL_REPO="$PROD_REPO_V4_AND_ABOVE"
    SENZING_PACKAGES="$PACKAGES_TO_INSTALL"

  elif [[ $SENZING_INSTALL_VERSION =~ "staging" ]]; then

    echo "[INFO] install $PACKAGES_TO_INSTALL from staging"
    get-generic-major-version
    is-major-version-greater-than-3
    INSTALL_REPO="$STAGING_REPO_V4_AND_ABOVE"
    SENZING_PACKAGES="$PACKAGES_TO_INSTALL"

  elif [[ $SENZING_INSTALL_VERSION =~ $REGEX_SEM_VER ]]; then
  
    echo "[INFO] install $PACKAGES_TO_INSTALL semantic version"
    get-semantic-major-version
    is-major-version-greater-than-3
    INSTALL_REPO="$PROD_REPO_V4_AND_ABOVE"
    IFS=" " read -r -a packages <<< "$PACKAGES_TO_INSTALL"
    for package in "${packages[@]}"
    do
      if [[ ! $package == *"senzingdata-v"* ]]; then
        updated_packages+="$package=$SENZING_INSTALL_VERSION* "
      else
        updated_packages+="$package "
      fi
    done
    SENZING_PACKAGES="$updated_packages"

  elif [[ $SENZING_INSTALL_VERSION =~ $REGEX_SEM_VER_BUILD_NUM ]]; then

    echo "[INFO] install $PACKAGES_TO_INSTALL semantic version with build number"
    get-semantic-major-version
    is-major-version-greater-than-3
    REPO="${SENZINGSDK_REPOSITORY:-staging}"
    echo "[INFO] install senzingsdk version $SENZING_INSTALL_VERSION from $REPO"
    if [[ "$REPO" == "production" ]]; then
      INSTALL_REPO="$PROD_REPO_V4_AND_ABOVE"
    elif [[ "$REPO" == "staging" ]]; then
      INSTALL_REPO="$STAGING_REPO_V4_AND_ABOVE"
    fi
    IFS=" " read -r -a packages <<< "$PACKAGES_TO_INSTALL"
    for package in "${packages[@]}"
    do
      if [[ ! $package == *"senzingdata-v"* ]]; then
        updated_packages+="$package=$SENZING_INSTALL_VERSION "
      else
        updated_packages+="$package "
      fi
    done
    SENZING_PACKAGES="$updated_packages"

  else
    echo "[ERROR] $PACKAGES_TO_INSTALL install version $SENZING_INSTALL_VERSION is unsupported"
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
# get-semantic-major-version
# GLOBALS:
#   SENZING_INSTALL_VERSION
#     one of: X.Y.Z, X.Y.Z-ABCDE
#     production-v<X> and staging-v<X> 
#     does not apply here
############################################
get-semantic-major-version(){

  MAJOR_VERSION=${SENZING_INSTALL_VERSION%%.*}
  echo "[INFO] major version is: $MAJOR_VERSION"
  export MAJOR_VERSION

}

############################################
# is-major-version-greater-than-3
# GLOBALS:
#   MAJOR_VERSION
#     set prior to this call via either
#     get-generic-major-version or
#     get-semantic-major-version
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
#     set prior to this call via either
#     get-generic-major-version or
#     get-semantic-major-version
############################################
restrict-major-version() {

  senzing_packages=$(apt list | grep senzing | cut -d '/' -f 1 | grep -v "data" | grep -v "staging" | grep -v "repo")
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
# GLOBALS:
#   MAJOR_VERSION
#     set prior to this call via either
#     get-generic-major-version or
#     get-semantic-major-version
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