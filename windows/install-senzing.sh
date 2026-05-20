#!/usr/bin/env bash
set -eo pipefail

# Clean up temp files on exit
trap 'rm -f /tmp/staging-versions senzingsdk.zip /tmp/senzingsdk.json /tmp/senzingsdk-pinned.zip' EXIT

############################################
# configure-vars
# GLOBALS:
#   SENZING_INSTALL_VERSION
#     one of: production-v<X>, staging-v<X>
#             X.Y.Z, X.Y.Z.ABCDE
#   SENZINGSDK_REPOSITORY (optional)
#   SENZINGSDK_REPOSITORY_PATH (optional)
#   WINDOWS_INSTALLER (optional: native, scoop)
#   SENZINGSDK_TOKEN (optional, required for scoop + staging)
############################################
configure-vars() {

  PRODUCTION_URI="s3://senzing-production-win/"
  PRODUCTION_URL="https://senzing-production-win.s3.amazonaws.com/"
  STAGING_URI="s3://senzing-staging-win/"
  STAGING_URL="https://senzing-staging-win.s3.amazonaws.com/"

  PRODUCTION_BUCKET="Senzing/scoop-senzingsdk"
  STAGING_BUCKET="senzing-factory/scoop-senzingsdk-staging"

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

  # Phase 3: Determine installer (native vs scoop)
  determine-installer

  # Phase 4: Determine artifact / pin version
  if [[ "$WINDOWS_INSTALLER" == "native" ]]; then
    if [[ "$SENZING_INSTALL_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]{5}$ ]]; then
      determine-zip-for-version
    elif [[ "$SENZING_INSTALL_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      determine-latest-zip-for-semver
    else
      determine-latest-zip-for-major-version
    fi
  else
    determine-scoop-version
  fi

}

############################################
# determine-installer
# GLOBALS:
#   WINDOWS_INSTALLER (input/output)
#   SENZING_INSTALL_VERSION
#   SENZINGSDK_REPOSITORY_PATH
############################################
determine-installer() {

  if [[ -n "$WINDOWS_INSTALLER" && "$WINDOWS_INSTALLER" != "scoop" && "$WINDOWS_INSTALLER" != "native" ]]; then
    echo "[ERROR] invalid windows-installer '$WINDOWS_INSTALLER'; must be 'scoop' or 'native'"
    exit 1
  fi

  local detected
  if [[ "$SENZING_INSTALL_VERSION" =~ ^([0-9]+)\.([0-9]+)\.[0-9]+ ]]; then
    local major="${BASH_REMATCH[1]}"
    local minor="${BASH_REMATCH[2]}"
    if [[ "$major" -gt 4 ]] || { [[ "$major" -eq 4 ]] && [[ "$minor" -ge 3 ]]; }; then
      detected="scoop"
    else
      detected="native"
    fi
  else
    # Floating tag (staging-vN / production-vN). 4.3.0 is live on the
    # prod Scoop bucket; floating tags default to scoop. Callers who
    # need the legacy zip flow can opt out via windows-installer=native.
    detected="scoop"
  fi

  if [[ -z "$WINDOWS_INSTALLER" ]]; then
    WINDOWS_INSTALLER="$detected"
    echo "[INFO] auto-detected windows-installer: $WINDOWS_INSTALLER"
  elif [[ "$WINDOWS_INSTALLER" == "scoop" && "$detected" == "native" && "$SENZING_INSTALL_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    echo "::warning::windows-installer=scoop requested but version $SENZING_INSTALL_VERSION is pre-4.3.0; scoop install is supported for SDK 4.3.0+ only, falling back to native"
    WINDOWS_INSTALLER="native"
  else
    echo "[INFO] windows-installer: $WINDOWS_INSTALLER"
  fi

  if [[ "$WINDOWS_INSTALLER" == "scoop" && -n "$SENZINGSDK_REPOSITORY_PATH" ]]; then
    echo "[ERROR] senzingsdk-repository-path is not supported with windows-installer=scoop; use windows-installer=native"
    exit 1
  fi

  export WINDOWS_INSTALLER

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
# list-latest-zip
# Lists $SENZINGSDK_URI on S3 and returns the
# latest zip (lexicographic sort) whose name
# contains the supplied filter pattern.
# ARGS:
#   $1 - filter pattern passed to grep
# GLOBALS:
#   SENZINGSDK_URI
############################################
list-latest-zip() {

  local pattern="$1"
  # `|| true` only on the two greps: a "no match" (exit 1) is a
  # legitimate empty result that callers handle. Errors from
  # `aws s3 ls` (network, credentials) propagate via pipefail.
  aws s3 ls "$SENZINGSDK_URI" --recursive --no-sign-request --region us-east-1 \
    | { grep -o -E '[^ ]+\.zip$' || true; } \
    | { grep "$pattern" || true; } \
    | sort -r \
    | head -n 1

}

############################################
# determine-latest-zip-for-major-version
# GLOBALS:
#   MAJOR_VERSION
#   SENZINGSDK_URL
############################################
determine-latest-zip-for-major-version() {

  local latest
  latest=$(list-latest-zip "_${MAJOR_VERSION}")
  if [ -z "$latest" ]; then
    echo "[ERROR] no ZIP found for major version $MAJOR_VERSION"
    exit 1
  fi
  echo "[INFO] latest version for major version $MAJOR_VERSION is: $latest"

  SENZINGSDK_ZIP_URL="$SENZINGSDK_URL$latest"

}

############################################
# determine-latest-zip-for-semver
# GLOBALS:
#   SENZING_INSTALL_VERSION
#   SENZINGSDK_URL
############################################
determine-latest-zip-for-semver() {

  local latest
  latest=$(list-latest-zip "_${SENZING_INSTALL_VERSION}\.")
  if [ -z "$latest" ]; then
    echo "[ERROR] no ZIP found for version $SENZING_INSTALL_VERSION"
    exit 1
  fi
  echo "[INFO] latest build for $SENZING_INSTALL_VERSION is: $latest"

  SENZINGSDK_ZIP_URL="$SENZINGSDK_URL$latest"

}

############################################
# determine-zip-for-version
# GLOBALS:
#   SENZING_INSTALL_VERSION
#   SENZINGSDK_URL
############################################
determine-zip-for-version() {

  SENZINGSDK_ZIP_URL="$SENZINGSDK_URL"SenzingSDK_"$SENZING_INSTALL_VERSION".zip

}

############################################
# determine-scoop-version
# GLOBALS:
#   SENZING_INSTALL_VERSION
#   SCOOP_PIN_VERSION (output)
#     empty for floating tags (bucket manifest resolves latest)
#     X.Y.Z.BUILD otherwise (used to generate a pinned manifest)
############################################
determine-scoop-version() {

  if [[ "$SENZING_INSTALL_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]{5}$ ]]; then
    SCOOP_PIN_VERSION="$SENZING_INSTALL_VERSION"
    echo "[INFO] pinning scoop install to $SCOOP_PIN_VERSION"
  elif [[ "$SENZING_INSTALL_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    local latest filename
    latest=$(list-latest-zip "_${SENZING_INSTALL_VERSION}\.")
    if [ -z "$latest" ]; then
      echo "[ERROR] no build found for semantic version $SENZING_INSTALL_VERSION"
      exit 1
    fi
    filename="${latest##*/}"
    SCOOP_PIN_VERSION="${filename#SenzingSDK_}"
    SCOOP_PIN_VERSION="${SCOOP_PIN_VERSION%.zip}"
    if [[ ! "$SCOOP_PIN_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "[ERROR] could not parse build version from S3 filename '$filename' (expected SenzingSDK_X.Y.Z.BUILD.zip)"
      exit 1
    fi
    echo "[INFO] resolved $SENZING_INSTALL_VERSION to scoop pin version $SCOOP_PIN_VERSION"
  else
    SCOOP_PIN_VERSION=""
    echo "[INFO] no scoop pin version; bucket manifest will resolve latest"
  fi

}

############################################
# install-via-scoop
# GLOBALS:
#   REPO_KIND
#   SCOOP_PIN_VERSION
#   SENZINGSDK_TOKEN
#   SENZINGSDK_URL
############################################
install-via-scoop() {

  local bucket_repo
  case "$REPO_KIND" in
    production)
      bucket_repo="$PRODUCTION_BUCKET"
      ;;
    staging)
      bucket_repo="$STAGING_BUCKET"
      # NB: token check lives in install-scoop-floating. Pinned-version
      # installs (install-scoop-pinned) download from public S3 staging
      # and don't touch the private GitHub bucket, so they don't need
      # a token.
      ;;
    *)
      echo "[ERROR] unsupported repository '$REPO_KIND' for scoop install"
      exit 1
      ;;
  esac

  ensure-scoop-installed

  # Both buckets check EULA acceptance in their pre_install block but
  # use different env-var names (prod: SENZING_ACCEPT_EULA, staging:
  # SENZING_EULA_ACCEPTED). Set both once here so the install routines
  # don't have to repeat it.
  export SENZING_ACCEPT_EULA="I_ACCEPT_THE_SENZING_EULA"
  export SENZING_EULA_ACCEPTED="yes"

  if [ -n "$SCOOP_PIN_VERSION" ]; then
    install-scoop-pinned
  else
    install-scoop-floating "$bucket_repo"
  fi

  link-scoop-prefix
  publish-scoop-env

}

############################################
# ensure-scoop-installed
# Installs scoop if not already present and
# adds its shim dir to PATH for this script.
############################################
ensure-scoop-installed() {

  if command -v scoop >/dev/null 2>&1; then
    echo "[INFO] scoop already installed"
    return 0
  fi

  echo "[INFO] installing scoop"
  # NOTE: deliberately no -RunAsAdmin. That flag installs Scoop into
  # C:\ProgramData\scoop (system-wide), but every other path in this
  # script (buckets, shims, apps) assumes the per-user prefix at
  # $HOME/scoop. GitHub runners already run as admin, so omitting the
  # flag just selects the layout we expect.
  powershell -NoProfile -Command "Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass; iex \"& {\$(irm get.scoop.sh)}\""

  # Expose scoop on PATH for the rest of this bash script.
  local scoop_shims="$HOME/scoop/shims"
  if [ -d "$scoop_shims" ]; then
    export PATH="$scoop_shims:$PATH"
  fi

}

############################################
# install-scoop-floating
# Floating-tag install: clone the bucket at
# the requested ref, run `scoop install`.
# ARGS:
#   $1 - bucket repo path (e.g. Senzing/scoop-senzingsdk)
############################################
install-scoop-floating() {

  local bucket_repo="$1"
  local clone_url="https://github.com/${bucket_repo}.git"
  local bucket_dir="$HOME/scoop/buckets/senzingsdk"

  if [ -d "$bucket_dir" ]; then
    echo "[INFO] removing pre-existing scoop bucket at $bucket_dir"
    rm -rf "$bucket_dir"
  fi
  mkdir -p "$(dirname "$bucket_dir")"
  echo "[INFO] cloning $bucket_repo bucket"

  if [ "$REPO_KIND" = "staging" ]; then
    if [ -z "$SENZINGSDK_TOKEN" ]; then
      echo "[ERROR] senzingsdk-token is required for floating-tag scoop installs from the staging bucket (private repo $bucket_repo)"
      exit 1
    fi
    clone-with-token "$clone_url" "$bucket_dir"
  else
    git clone --depth 1 "$clone_url" "$bucket_dir"
  fi

  echo "[INFO] scoop install senzingsdk/senzingsdk"
  scoop install senzingsdk/senzingsdk

}

############################################
# clone-with-token
# Clone a private bucket with auth.
#
# GIT_ASKPASS is unreliable on the windows-latest runner: the git shim
# scoop bundles can't always exec a `/tmp/...` shell askpass (path-format
# mismatch + shebang invocation through the windows wrapper). When it
# fails, git silently drops to anonymous and the private bucket clone
# 404s. The cross-platform pattern that's actually reliable is
# `git config --global url.<auth>.insteadOf <public>` — git reads the
# rewrite from ~/.gitconfig at URL-parse time, no executable askpass
# needed. The cloned repo's remote URL is reset to the public form
# afterward so the embedded token doesn't persist in .git/config.
#
# ARGS:
#   $1 - public clone URL
#   $2 - destination directory
# GLOBALS:
#   SENZINGSDK_TOKEN
############################################
clone-with-token() {

  local url="$1"
  local dest="$2"
  local match_url="https://github.com/"
  local auth_url="https://x-access-token:${SENZINGSDK_TOKEN}@github.com/"
  local cleanup="git config --global --unset \"url.${auth_url}.insteadOf\" 2>/dev/null || true"

  # shellcheck disable=SC2064  # intentional: capture $cleanup expansion now
  trap "$cleanup" RETURN INT TERM

  git config --global "url.${auth_url}.insteadOf" "$match_url"
  local status=0
  git clone --depth 1 "$url" "$dest" || status=$?

  trap - INT TERM

  if [ "$status" -ne 0 ]; then
    # `exit` skips RETURN traps, so unset the insteadOf entry explicitly
    # before bailing — otherwise the auth URL stays in ~/.gitconfig.
    eval "$cleanup"
    echo "[ERROR] git clone failed (exit $status)"
    exit "$status"
  fi

  # Reset the cloned repo's remote to the public URL so the embedded
  # auth token isn't stored in .git/config on the runner's disk.
  ( cd "$dest" && git remote set-url origin "$url" ) || true

}

############################################
# install-scoop-pinned
# Pinned-version install: download the zip
# once, generate a manifest pointing at the
# local file (avoids a second download via
# the HTTPS URL), and `scoop install` it.
# GLOBALS:
#   SENZINGSDK_URL
#   SCOOP_PIN_VERSION
############################################
install-scoop-pinned() {

  local zip_url zip_path zip_sha zip_path_win
  zip_url="${SENZINGSDK_URL}SenzingSDK_${SCOOP_PIN_VERSION}.zip"
  zip_path="/tmp/senzingsdk-pinned.zip"

  echo "[INFO] downloading pinned zip"
  curl --fail --silent --show-error --output "$zip_path" "$zip_url"
  zip_sha=$(sha256sum "$zip_path" | awk '{print $1}')
  # Don't rm the zip here: the generated manifest points at it as a
  # file:// URL so scoop reuses the local copy. EXIT trap removes it.

  # Scoop runs as native PowerShell and doesn't understand MSYS2
  # virtual paths like /tmp/..., so convert to a Windows-native path
  # (forward slashes) before embedding in the file:// URL.
  zip_path_win=$(cygpath -m "$zip_path")

  # `extract_dir: senzing` mirrors the prod/staging bucket manifests
  # and matches the current SenzingSDK_X.Y.Z.BUILD.zip layout: every
  # path is rooted under a top-level `senzing/` directory. If the
  # archive's internal structure ever changes, this needs to be
  # updated in lockstep with the bucket manifests.
  #
  # The manifest filename must be `senzingsdk.json` — scoop derives
  # the installed app name from the basename, and link-scoop-prefix /
  # verify-installation both look up `~/scoop/apps/senzingsdk/current`.
  local manifest_path="/tmp/senzingsdk.json"
  cat > "$manifest_path" <<JSON
{
  "version": "${SCOOP_PIN_VERSION}",
  "description": "Senzing SDK for Windows (pinned by install action)",
  "homepage": "https://senzing.com/",
  "license": {
    "identifier": "Proprietary",
    "url": "https://senzing.com/software-license-agreement/"
  },
  "extract_dir": "senzing",
  "architecture": {
    "64bit": {
      "url": "file:///${zip_path_win}",
      "hash": "${zip_sha}"
    }
  },
  "env_add_path": "er\\\\lib",
  "env_set": {
    "SENZING_DIR": "\$dir\\\\er"
  }
}
JSON

  echo "[INFO] scoop install from pinned manifest at $manifest_path"
  # Scoop runs as PowerShell; pass it a Windows-native manifest path
  # so we don't rely on MSYS2 argument auto-conversion through its shim.
  scoop install "$(cygpath -m "$manifest_path")"

}

############################################
# link-scoop-prefix
# Symlink $HOME/Senzing -> scoop's senzingsdk
# current dir so verify-installation and any
# downstream consumers expecting the native
# install path keep working.
############################################
link-scoop-prefix() {

  local scoop_senzing="$HOME/scoop/apps/senzingsdk/current"

  if [ ! -d "$scoop_senzing" ]; then
    echo "[ERROR] expected scoop install target $scoop_senzing not found"
    exit 1
  fi

  if [ -e "$HOME/Senzing" ] || [ -L "$HOME/Senzing" ]; then
    rm -rf "$HOME/Senzing"
  fi
  ln -s "$scoop_senzing" "$HOME/Senzing"
  echo "[INFO] symlinked $HOME/Senzing -> $scoop_senzing"

}

############################################
# publish-scoop-env
# Forward SDK env vars to subsequent workflow
# steps via $GITHUB_ENV.
############################################
publish-scoop-env() {

  local senzing_root="$HOME/Senzing/er"
  # SENZING_ROOT for cross-platform consistency with the darwin path
  # (publish-homebrew-env exports the same name). The scoop manifest
  # additionally sets SENZING_DIR via its env_set block; we keep
  # SENZING_ROOT here as the install-action's canonical name.
  echo "SENZING_ROOT=$senzing_root" >> "${GITHUB_ENV:-/dev/null}"
  # PATH additions belong in $GITHUB_PATH (one dir per line). Writing
  # PATH=... to $GITHUB_ENV would freeze a snapshot of $PATH and clobber
  # any modifications other steps (or the runner) make in between.
  # Use a Windows-native path so non-MSYS2 tools in subsequent steps
  # don't have to interpret a POSIX-style path.
  cygpath -w "${senzing_root}/lib" >> "${GITHUB_PATH:-/dev/null}"

}

############################################
# download-zip
# GLOBALS:
#   SENZINGSDK_ZIP_URL
############################################
download-zip() {

  echo "[INFO] curl --fail --output senzingsdk.zip SENZINGSDK_ZIP_URL_REDACTED"
  curl --fail --output senzingsdk.zip "$SENZINGSDK_ZIP_URL"

}

############################################
# install-senzingsdk
############################################
install-senzingsdk() {

  7z x -y -o"$HOME" senzingsdk.zip
  rm -f senzingsdk.zip

}

############################################
# verify-installation
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
main() {

  configure-vars

  if [[ "$WINDOWS_INSTALLER" == "scoop" ]]; then
    install-via-scoop
  else
    download-zip
    install-senzingsdk
  fi

  verify-installation

}

# Only run main when executed directly; allows the script to be sourced
# from tests (e.g. bats) to exercise individual functions.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
