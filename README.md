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
   against the calling repository; cross-org callers must pass a PAT with
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

- `homebrew` — install via Homebrew tap (`Senzing/senzingsdk` for production, `senzing-factory/senzingsdk-staging` for staging). Supports SDK 4.3.0 and higher only. The cask still pulls the `.dmg` from S3 — the difference is that Homebrew manages the install, dependencies (`openssl@3`, SQLite), and lifecycle.
- `native` — direct `.dmg` download + `hdiutil` + `cp` (the v4 macOS behavior). Required for SDK versions earlier than 4.3.0.
- (empty, default) — auto-detect: `homebrew` for pinned versions ≥ 4.3.0; `native` for pinned versions below 4.3.0 and for floating tags (`staging-v4`, `production-v4`). The floating-tag default is `native` until 4.3.0 is live in both Homebrew taps.

If `homebrew` is requested with a pre-4.3.0 pinned version, the script warns and falls back to `native`.

#### senzingsdk-token (macOS only)

GitHub token used to clone the private staging Homebrew tap when installing via `homebrew` from staging. Defaults to `${{ github.token }}`.

The default `github.token` only has access to the workflow's own repository. To install from the staging tap you must supply a token with read access to it; without one the staging Homebrew install will fail. Two common approaches:

- **GitHub App token (recommended).** Register a GitHub App with `Contents: Read` on the staging tap repository, install it on the org that owns the tap, then mint a short-lived token at job time using [`actions/create-github-app-token`](https://github.com/actions/create-github-app-token). Tokens expire automatically (~1 hour), are scoped to the repositories you specify, and are auditable.
- **Personal access token.** A fine-grained PAT with `Contents: Read` on the staging tap, stored as a repository or org secret. Simpler to set up, but long-lived and tied to a user account.

Either way, pass the resulting token to `senzingsdk-token`. Token minting is only needed for jobs that actually hit the staging tap (i.e., `darwin-installer: homebrew` against a staging version). Production Homebrew installs and all native installs do not require a token.

Example using a GitHub App token:

```yaml
jobs:
  install:
    runs-on: macos-latest
    steps:
      - uses: actions/create-github-app-token@v2
        id: staging-tap-token
        with:
          app-id: ${{ vars.STAGING_TAP_APP_ID }} # or client-id value
          private-key: ${{ secrets.STAGING_TAP_APP_KEY }}
          owner: <org-that-owns-the-staging-tap>
          repositories: <staging-tap-repo>

      - uses: senzing-factory/github-action-install-senzing-sdk@v5
        with:
          senzingsdk-version: staging-v4
          darwin-installer: homebrew
          senzingsdk-token: ${{ steps.staging-tap-token.outputs.token }}
```

Example using a PAT:

```yaml
- uses: senzing-factory/github-action-install-senzing-sdk@v5
  with:
    senzingsdk-version: staging-v4
    darwin-installer: homebrew
    senzingsdk-token: ${{ secrets.STAGING_TAP_PAT }}
```

[RUNNER_OS]: https://docs.github.com/en/actions/learn-github-actions/variables#default-environment-variables
[system install]: https://github.com/senzing-garage/knowledge-base/blob/main/WHATIS/senzing-system-installation.md
