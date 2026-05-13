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
#   SENZINGSDK_REPOSITORY (optional)
#   SENZINGSDK_REPOSITORY_PATH (optional)
#   DARWIN_INSTALLER (optional: native, homebrew)
#   SENZINGSDK_TOKEN (optional, required for homebrew + staging)
############################################
configure-vars() {

  PRODUCTION_URI="s3://senzing-production-osx/"
  PRODUCTION_URL="https://senzing-production-osx.s3.amazonaws.com/"
  STAGING_URI="s3://senzing-staging-osx/"
  STAGING_URL="https://senzing-staging-osx.s3.amazonaws.com/"

  PRODUCTION_TAP="Senzing/senzingsdk"
  PRODUCTION_CASK="senzingsdk"
  STAGING_TAP="senzing-factory/senzingsdk-staging"
  STAGING_TAP_REPO="senzing-factory/homebrew-senzingsdk-staging"
  STAGING_CASK="senzingsdk-staging"

  # Phase 1: Determine repository
  if [ -n "$SENZINGSDK_REPOSITORY_PATH" ]; then

    echo "[INFO] install senzingsdk from supplied repository"
    SENZINGSDK_URI="s3://$SENZINGSDK_REPOSITORY_PATH/"
    SENZINGSDK_URL="https://$SENZINGSDK_REPOSITORY_PATH.s3.amazonaws.com/"
    REPO_KIND="custom"

  elif [[ "$SENZING_INSTALL_VERSION" =~ ^production-v[0-9]+$ ]]; then

    echo "[INFO] install senzingsdk from production"
    SENZINGSDK_URI="$PRODUCTION_URI"
    SENZINGSDK_URL="$PRODUCTION_URL"
    REPO_KIND="production"

  elif [[ "$SENZING_INSTALL_VERSION" =~ ^staging-v[0-9]+$ ]]; then

    echo "[INFO] install senzingsdk from staging"
    SENZINGSDK_URI="$STAGING_URI"
    SENZINGSDK_URL="$STAGING_URL"
    REPO_KIND="staging"

  elif [[ "$SENZING_INSTALL_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then

    REPO="${SENZINGSDK_REPOSITORY:-staging}"
    echo "[INFO] install senzingsdk version $SENZING_INSTALL_VERSION from $REPO"
    if [[ "$REPO" == "production" ]]; then
      SENZINGSDK_URI="$PRODUCTION_URI"
      SENZINGSDK_URL="$PRODUCTION_URL"
      REPO_KIND="production"
    else
      SENZINGSDK_URI="$STAGING_URI"
      SENZINGSDK_URL="$STAGING_URL"
      REPO_KIND="staging"
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

  # Phase 3: Determine installer (native vs homebrew)
  determine-installer

  # Phase 4: Determine artifact / pin version
  if [[ "$DARWIN_INSTALLER" == "native" ]]; then
    if [[ "$SENZING_INSTALL_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]{5}$ ]]; then
      determine-dmg-for-version
    elif [[ "$SENZING_INSTALL_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      determine-latest-dmg-for-semver
    else
      determine-latest-dmg-for-major-version
    fi
  else
    determine-homebrew-version
  fi

}

############################################
# determine-installer
# GLOBALS:
#   DARWIN_INSTALLER (input/output)
#   SENZING_INSTALL_VERSION
#   SENZINGSDK_REPOSITORY_PATH
############################################
determine-installer() {

  if [[ -n "$DARWIN_INSTALLER" && "$DARWIN_INSTALLER" != "homebrew" && "$DARWIN_INSTALLER" != "native" ]]; then
    echo "[ERROR] invalid darwin-installer '$DARWIN_INSTALLER'; must be 'homebrew' or 'native'"
    exit 1
  fi

  local detected
  if [[ "$SENZING_INSTALL_VERSION" =~ ^([0-9]+)\.([0-9]+)\.[0-9]+ ]]; then
    local major="${BASH_REMATCH[1]}"
    local minor="${BASH_REMATCH[2]}"
    if [[ "$major" -gt 4 ]] || { [[ "$major" -eq 4 ]] && [[ "$minor" -ge 3 ]]; }; then
      detected="homebrew"
    else
      detected="native"
    fi
  else
    # Floating tag (staging-vN / production-vN). 4.3.0 is now live on
    # the prod Homebrew tap, so float defaults to homebrew. Callers
    # who need the legacy DMG flow can opt out via darwin-installer=native.
    detected="homebrew"
  fi

  if [[ -z "$DARWIN_INSTALLER" ]]; then
    DARWIN_INSTALLER="$detected"
    echo "[INFO] auto-detected darwin-installer: $DARWIN_INSTALLER"
  elif [[ "$DARWIN_INSTALLER" == "homebrew" && "$detected" == "native" && "$SENZING_INSTALL_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    echo "::warning::darwin-installer=homebrew requested but version $SENZING_INSTALL_VERSION is pre-4.3.0; homebrew install is supported for SDK 4.3.0+ only, falling back to native"
    DARWIN_INSTALLER="native"
  else
    echo "[INFO] darwin-installer: $DARWIN_INSTALLER"
  fi

  if [[ "$DARWIN_INSTALLER" == "homebrew" && -n "$SENZINGSDK_REPOSITORY_PATH" ]]; then
    echo "[ERROR] senzingsdk-repository-path is not supported with darwin-installer=homebrew; use darwin-installer=native"
    exit 1
  fi

  export DARWIN_INSTALLER

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
# list-latest-dmg
# Lists $SENZINGSDK_URI on S3 and returns the
# latest DMG (lexicographic sort) whose name
# contains the supplied filter pattern.
# ARGS:
#   $1 - filter pattern passed to grep
# GLOBALS:
#   SENZINGSDK_URI
# OUTPUTS:
#   echoes the S3 key (may include subdir
#   prefix) to stdout, or empty if no match
############################################
list-latest-dmg() {

  local pattern="$1"
  # `|| true` only on the two greps: a "no match" (exit 1) is a
  # legitimate empty result that callers handle. Errors from
  # `aws s3 ls` (network, credentials) propagate via pipefail.
  aws s3 ls "$SENZINGSDK_URI" --recursive --no-sign-request \
    | { grep -o -E '[^ ]+\.dmg$' || true; } \
    | { grep "$pattern" || true; } \
    | sort -r \
    | head -n 1

}

############################################
# determine-latest-dmg-for-major-version
# GLOBALS:
#   MAJOR_VERSION
#   SENZINGSDK_URL
############################################
determine-latest-dmg-for-major-version() {

  local latest
  latest=$(list-latest-dmg "_${MAJOR_VERSION}")
  if [ -z "$latest" ]; then
    echo "[ERROR] no DMG found for major version $MAJOR_VERSION"
    exit 1
  fi
  echo "[INFO] latest version for major version $MAJOR_VERSION is: $latest"

  SENZINGSDK_DMG_URL="$SENZINGSDK_URL$latest"

}

############################################
# determine-latest-dmg-for-semver
# GLOBALS:
#   SENZING_INSTALL_VERSION
#   SENZINGSDK_URL
############################################
determine-latest-dmg-for-semver() {

  local latest
  latest=$(list-latest-dmg "_${SENZING_INSTALL_VERSION}\.")
  if [ -z "$latest" ]; then
    echo "[ERROR] no DMG found for version $SENZING_INSTALL_VERSION"
    exit 1
  fi
  echo "[INFO] latest build for $SENZING_INSTALL_VERSION is: $latest"

  SENZINGSDK_DMG_URL="$SENZINGSDK_URL$latest"

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
# determine-homebrew-version
# GLOBALS:
#   SENZING_INSTALL_VERSION
#   HOMEBREW_PIN_VERSION (output)
#     empty for floating tags (cask resolves latest itself)
#     X.Y.Z.BUILD otherwise (exported via HOMEBREW_SENZING_SDK_VERSION)
############################################
determine-homebrew-version() {

  if [[ "$SENZING_INSTALL_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]{5}$ ]]; then
    HOMEBREW_PIN_VERSION="$SENZING_INSTALL_VERSION"
    echo "[INFO] pinning homebrew install to $HOMEBREW_PIN_VERSION"
  elif [[ "$SENZING_INSTALL_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    local latest filename
    latest=$(list-latest-dmg "_${SENZING_INSTALL_VERSION}\.")
    if [ -z "$latest" ]; then
      echo "[ERROR] no build found for semantic version $SENZING_INSTALL_VERSION"
      exit 1
    fi
    # Tolerate subdir prefixes from `aws s3 ls --recursive`: strip
    # everything up to the basename, then peel off the prefix/suffix
    # via parameter expansion (no sed regex required).
    filename="${latest##*/}"
    HOMEBREW_PIN_VERSION="${filename#senzingsdk_}"
    HOMEBREW_PIN_VERSION="${HOMEBREW_PIN_VERSION%.dmg}"
    echo "[INFO] resolved $SENZING_INSTALL_VERSION to homebrew pin version $HOMEBREW_PIN_VERSION"
  else
    HOMEBREW_PIN_VERSION=""
    echo "[INFO] no homebrew pin version; cask will resolve latest"
  fi

}

############################################
# install-via-homebrew
# GLOBALS:
#   REPO_KIND
#   HOMEBREW_PIN_VERSION
#   SENZINGSDK_TOKEN
############################################
install-via-homebrew() {

  local cask
  case "$REPO_KIND" in
    production)
      cask="$PRODUCTION_CASK"
      echo "[INFO] brew tap $PRODUCTION_TAP"
      brew tap "$PRODUCTION_TAP"
      ;;
    staging)
      cask="$STAGING_CASK"
      if [ -z "$SENZINGSDK_TOKEN" ]; then
        echo "[ERROR] senzingsdk-token is required for homebrew installs from the staging tap (private repo $STAGING_TAP_REPO)"
        exit 1
      fi
      echo "[INFO] brew tap $STAGING_TAP (with token)"
      brew tap "$STAGING_TAP" "https://x-access-token:${SENZINGSDK_TOKEN}@github.com/${STAGING_TAP_REPO}.git"
      # Strip the token from the tap's stored remote URL so it doesn't
      # persist on disk past the tap step. The subsequent cask install
      # reads the formula from the local clone and downloads the .dmg
      # from public S3, so no further GitHub auth is needed.
      local tap_dir
      tap_dir="$(brew --repo "$STAGING_TAP")"
      if [ -d "$tap_dir/.git" ]; then
        git -C "$tap_dir" remote set-url origin "https://github.com/${STAGING_TAP_REPO}.git"
      fi
      ;;
    *)
      echo "[ERROR] unsupported repository '$REPO_KIND' for homebrew install"
      exit 1
      ;;
  esac

  export HOMEBREW_SENZING_ACCEPT_EULA="i_accept_the_senzing_eula"
  if [ -n "$HOMEBREW_PIN_VERSION" ]; then
    export HOMEBREW_SENZING_SDK_VERSION="$HOMEBREW_PIN_VERSION"
    echo "[INFO] brew install --cask $cask (pinned to $HOMEBREW_PIN_VERSION)"
  else
    echo "[INFO] brew install --cask $cask (latest)"
  fi
  brew install --cask "$cask"

  link-homebrew-prefix
  publish-homebrew-env

}

############################################
# link-homebrew-prefix
# Symlink $HOME/senzing -> $(brew --prefix)/opt/senzing so that
# verify-installation and downstream consumers expecting the
# native install path keep working.
############################################
link-homebrew-prefix() {

  local brew_prefix brew_senzing
  brew_prefix="$(brew --prefix)"
  brew_senzing="$brew_prefix/opt/senzing"

  if [ ! -d "$brew_senzing" ]; then
    echo "[ERROR] expected homebrew install target $brew_senzing not found"
    exit 1
  fi

  if [ -e "$HOME/senzing" ] || [ -L "$HOME/senzing" ]; then
    rm -rf "$HOME/senzing"
  fi
  ln -s "$brew_senzing" "$HOME/senzing"
  echo "[INFO] symlinked $HOME/senzing -> $brew_senzing"

}

############################################
# publish-homebrew-env
# Forward SDK env vars to subsequent workflow steps.
# libSz.dylib loads @rpath/libssl.3.dylib and @rpath/libcrypto.3.dylib
# at runtime; the cask's `depends_on openssl@3` installs them but
# libSz's rpath doesn't include Homebrew's openssl@3 prefix. Add it to
# DYLD_LIBRARY_PATH so consumers don't have to wire it up themselves.
############################################
publish-homebrew-env() {

  local senzing_root="$HOME/senzing/er"
  local openssl_lib
  openssl_lib="$(brew --prefix openssl@3)/lib"
  {
    echo "SENZING_ROOT=$senzing_root"
    echo "DYLD_LIBRARY_PATH=${senzing_root}/lib:${openssl_lib}${DYLD_LIBRARY_PATH:+:${DYLD_LIBRARY_PATH}}"
  } >> "${GITHUB_ENV:-/dev/null}"
  # PATH additions belong in $GITHUB_PATH (one dir per line). Writing
  # PATH=... to $GITHUB_ENV would freeze a snapshot of $PATH and clobber
  # any modifications other steps (or the runner) make in between.
  echo "${senzing_root}/bin" >> "${GITHUB_PATH:-/dev/null}"

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
# Temporary workaround for native installs: SDK
# DMG no longer bundles OpenSSL 3. The Homebrew
# cask declares openssl@3 as a formula
# dependency, so this is only needed on the
# native path.
############################################
install-openssl() {

  local version
  version=$(grep -o '"VERSION": "[^"]*"' "$HOME"/senzing/er/szBuildVersion.json | cut -d'"' -f4)
  local major minor _patch
  IFS='.' read -r major minor _patch <<< "$version"

  if [[ "$major" -gt 4 ]] || { [[ "$major" -eq 4 ]] && [[ "$minor" -ge 3 ]]; }; then
    echo "[INFO] SDK version $version requires OpenSSL 3, installing via Homebrew (temporary workaround)"
    brew install openssl@3
    local openssl_lib
    openssl_lib="$(brew --prefix openssl@3)/lib"
    echo "[INFO] adding $openssl_lib to DYLD_LIBRARY_PATH"
    echo "DYLD_LIBRARY_PATH=${openssl_lib}${DYLD_LIBRARY_PATH:+:${DYLD_LIBRARY_PATH}}" >> "$GITHUB_ENV"
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
main() {

  configure-vars

  if [[ "$DARWIN_INSTALLER" == "homebrew" ]]; then
    install-via-homebrew
  else
    download-dmg
    install-senzing
    install-openssl
  fi

  verify-installation

}

# Only run main when executed directly; allows the script to be sourced
# from tests (e.g. bats) to exercise individual functions.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
