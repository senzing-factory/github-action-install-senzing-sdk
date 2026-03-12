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
           uses: senzing-factory/github-action-install-senzing-sdk@v4
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
           uses: senzing-factory/github-action-install-senzing-sdk@v4
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
           uses: senzing-factory/github-action-install-senzing-sdk@v4
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
           uses: senzing-factory/github-action-install-senzing-sdk@v4
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
           uses: senzing-factory/github-action-install-senzing-sdk@v4
           with:
             senzingsdk-version: 4.2.2
             senzingsdk-repository: production
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

[RUNNER_OS]: https://docs.github.com/en/actions/learn-github-actions/variables#default-environment-variables
[system install]: https://github.com/senzing-garage/knowledge-base/blob/main/WHATIS/senzing-system-installation.md
