# github-action-install-senzing-sdk

## Synopsis

A GitHub Action for installing the Senzing SDK **V4 or higher**.

## Overview

The GitHub Action performs a [system install] of the Senzing SDK.
The GitHub Action works where the [RUNNER_OS]
GitHub variable is `Linux`, `macOS`, or `Windows`.

## Usage

1. An example `.github/workflows/install-senzing-example.yaml` file
   which installs the latest released Senzing SDK:

   ```yaml
   name: install senzing example

   on: [push]

   jobs:
     build:
       runs-on: ubuntu-latest
       steps:
         - name: Install Senzing SDK
           uses: senzing-factory/github-action-install-senzing-sdk@v5
           with:
             senzingsdk-version: production-v4
   ```

1. An example `.github/workflows/install-senzing-example.yaml` file
   which installs the latest build of a specific semantic version:

   ```yaml
   name: install senzing example

   on: [push]

   jobs:
     build:
       runs-on: ubuntu-latest
       steps:
         - name: Install Senzing SDK
           uses: senzing-factory/github-action-install-senzing-sdk@v5
           with:
             senzingsdk-version: 4.2.2
   ```

1. An example `.github/workflows/install-senzing-example.yaml` file
   which installs a specific Senzing SDK build (Linux only):

   ```yaml
   name: install senzing example

   on: [push]

   jobs:
     build:
       runs-on: ubuntu-latest
       steps:
         - name: Install Senzing SDK
           uses: senzing-factory/github-action-install-senzing-sdk@v5
           with:
             senzingsdk-version: 4.0.0-12345
   ```

1. An example `.github/workflows/install-senzing-example.yaml` file
   which installs senzingsdk-runtime and senzingsdk-setup with a
   specific Senzing SDK semantic version:

   ```yaml
   name: install senzing example

   on: [push]

   jobs:
     build:
       runs-on: ubuntu-latest
       steps:
         - name: Install Senzing SDK
           uses: senzing-factory/github-action-install-senzing-sdk@v5
           with:
             packages-to-install: "senzingsdk-runtime senzingsdk-setup"
             senzingsdk-version: 4.0.0
   ```

1. An example `.github/workflows/install-senzing-example.yaml` file
   which installs from a specific semantic version from production
   instead of the default staging:

   ```yaml
   name: install senzing example

   on: [push]

   jobs:
     build:
       runs-on: ubuntu-latest
       steps:
         - name: Install Senzing SDK
           uses: senzing-factory/github-action-install-senzing-sdk@v5
           with:
             senzingsdk-version: 4.2.2
             senzingsdk-repository: production
   ```

1. An example installing the latest staging build on macOS via the
   private Homebrew tap. The default `github.token` only authenticates
   against the calling repo; cross-org callers must pass a PAT with
   read access to `senzing-factory/homebrew-senzingsdk-staging`:

   ```yaml
   name: install senzing example

   on: [push]

   jobs:
     build:
       runs-on: macos-latest
       steps:
         - name: Install Senzing SDK
           uses: senzing-factory/github-action-install-senzing-sdk@v5
           with:
             senzingsdk-version: staging-v4
             senzingsdk-token: ${{ secrets.SENZINGSDK_STAGING_TOKEN }}
   ```

### Inputs

#### senzingsdk-version (required)

`senzingsdk-version` values can include the following:

- `production-v<MAJOR_VERSION>`
  - Ex. `production-v4`
  - This will install the latest version of the respective major version from _production_.
- `staging-v<MAJOR_VERSION>`
  - Ex. `staging-v4`
  - This will install the latest version of the respective major version from _staging_.
- `X.Y.Z`
  - Ex. `4.2.2`
  - This will install the latest build of the respective semantic version.
  - Defaults to _staging_. Use `senzingsdk-repository` to override.
- `X.Y.Z-ABCDE` (Linux only)
  - Ex. `4.0.0-12345`
  - This will install the exact version supplied.
  - Defaults to _staging_. Use `senzingsdk-repository` to override.
- `X.Y.Z.ABCDE` (macOS and Windows only)
  - Ex. `4.0.0.12345`
  - This will install the exact version supplied.
  - Defaults to _staging_. Use `senzingsdk-repository` to override.

#### packages-to-install (Linux only)

`packages-to-install` values can include the following:

- `senzingsdk-poc`
- `senzingsdk-runtime` (default)
- `senzingsdk-setup`
- `senzingsdk-tools`

#### senzingsdk-repository

Override the repository for semantic version installs. Values: `staging` (default) or `production`.

#### senzingsdk-repository-path

Optional S3 repository override for senzing packages outside of staging and production. Requires `senzingsdk-version`.

#### senzingsdk-repository-package (Linux only)

Optional repository package override for senzing packages outside of staging and production.

#### darwin-installer (macOS only)

Select the install backend for macOS.

- `homebrew` — install via Homebrew tap (`Senzing/senzingsdk` for production, `senzing-factory/senzingsdk-staging` for staging). Supports SDK 4.3.0 and higher only. The cask still pulls the `.dmg` from S3 — the difference is that brew manages the install, dependencies (openssl@3, sqlite), and lifecycle.
- `native` — direct `.dmg` download + `hdiutil` + `cp` (the v4 macOS behavior). Required for SDK versions earlier than 4.3.0.
- (empty, default) — auto-detect: `homebrew` for pinned versions ≥ 4.3.0; `native` for pinned versions below 4.3.0 and for floating tags (`staging-v4`, `production-v4`). The floating-tag default is `native` until 4.3.0 is live in both Homebrew taps.

If `homebrew` is requested with a pre-4.3.0 pinned version, the script warns and falls back to `native`.

#### senzingsdk-token (macOS only)

GitHub token used to clone the private staging Homebrew tap (`senzing-factory/homebrew-senzingsdk-staging`) when installing via `homebrew` from staging. Defaults to `${{ github.token }}`.

The default `github.token` only has access to the workflow's own repo, so callers in other orgs must supply a token with read access to the staging tap, or staging homebrew installs will fail. The recommended pattern is a short-lived GitHub App token (see below).

### Authenticating the staging Homebrew tap

The staging tap is a private repository. Long-lived PATs work but are discouraged. Use a GitHub App scoped to read `homebrew-senzingsdk-staging` and mint a short-lived (~1 hour) token per workflow run.

Three Apps are maintained, one per org so cross-org workflows can each authenticate against the staging tap without sharing credentials:

| Org | App | App ID variable | Private key secret |
|---|---|---|---|
| `senzing-factory` | senzing-factory staging tap reader | `SENZINGSDK_STAGING_APP_ID` | `SENZINGSDK_STAGING_APP_KEY` |
| `senzing-garage`  | senzing-garage staging tap reader  | `SENZINGSDK_STAGING_APP_ID` | `SENZINGSDK_STAGING_APP_KEY` |
| `senzing`         | senzing staging tap reader         | `SENZINGSDK_STAGING_APP_ID` | `SENZINGSDK_STAGING_APP_KEY` |

Each App is installed in its org with `Contents: read` on `senzing-factory/homebrew-senzingsdk-staging`. Callers add the App ID as an org-level variable and the private key as an org-level secret, then mint a token at job time:

```yaml
jobs:
  install:
    runs-on: macos-latest
    steps:
      - uses: actions/create-github-app-token@v2
        id: staging-tap-token
        with:
          app-id:        ${{ vars.SENZINGSDK_STAGING_APP_ID }}
          private-key:   ${{ secrets.SENZINGSDK_STAGING_APP_KEY }}
          owner:         senzing-factory
          repositories:  homebrew-senzingsdk-staging

      - uses: senzing-factory/github-action-install-senzing-sdk@v5
        with:
          senzingsdk-version: staging-v4
          darwin-installer:   homebrew
          senzingsdk-token:   ${{ steps.staging-tap-token.outputs.token }}
```

Only mint a token for jobs that actually need the staging tap (i.e., `darwin-installer: homebrew` against a staging version). Production homebrew installs and all native installs do not require a token.

[RUNNER_OS]: https://docs.github.com/en/actions/learn-github-actions/variables#default-environment-variables
[system install]: https://github.com/senzing-garage/knowledge-base/blob/main/WHATIS/senzing-system-installation.md
