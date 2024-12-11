# github-action-install-senzing-sdk

## Synopsis

A GitHub Action for installing the Senzing SDK **V4 or higher**.

## Overview

The GitHub Action performs a [system install] of the Senzing ADK.
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
           uses: senzing-factory/github-action-install-senzing-sdk@v1
           with:
             senzingsdk-version: production-v4
   ```

1. An example `.github/workflows/install-senzing-example.yaml` file
   which installs a specific Senzing SDK version:

   ```yaml
   name: install senzing example

   on: [push]

   jobs:
     build:
       runs-on: ubuntu-latest
       steps:
         - name: Install Senzing SDK
           uses: senzing-factory/github-action-install-senzing-sdk@v1
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
           uses: senzing-factory/github-action-install-senzing-sdk@v1
           with:
             packages-to-install: "senzingsdk-runtime senzingsdk-setup"
             senzingsdk-version: 4.0.0
   ```

### package(s)-to-install

`package(s)-to-install` values can include the following:

- Version >= 4.0:
  - `senzingsdk-poc`
  - `senzingsdk-runtime`
  - `senzingsdk-setup`
  - `senzingsdk-tools`

### senzingsdk-version

`senzingsdk-version` values can include the following:

- `production-v<MAJOR_VERSION>`
  - Ex. `production-v4`
  - This will install the latest version of the respective major version from _production_.
- `staging-v<MAJOR_VERSION>`
  - Ex. `staging-v4`
  - This will install the latest version of the respective major version from _staging_.
- `X.Y.Z`
  - Ex. `4.0.0`
  - This will install the latest build of the respective semantic version from _production_.
- `X.Y.Z-ABCDE`
  - Ex. `4.0.0-12345`
  - This will install the exact version supplied from _production_.

[RUNNER_OS]: https://docs.github.com/en/actions/learn-github-actions/variables#default-environment-variables
[system install]: https://github.com/senzing-garage/knowledge-base/blob/main/WHATIS/senzing-system-installation.md
