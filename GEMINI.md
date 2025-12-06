# Gemini CLI Nix Package

## Project Overview

This repository provides a Nix package for the [Gemini CLI](https://github.com/google-gemini/gemini-cli), Google's AI assistant in the terminal. It is structured as a Nix Flake and offers two variants of the package:

1.  **Stable (`gemini-cli`):** The latest stable release from npm.
2.  **Preview (`gemini-cli-preview`):** The latest preview release from the npm `preview` tag.

The packaging logic fetches the pre-built npm tarball and installs it with a bundled Node.js runtime (v22), ensuring consistent execution regardless of the user's environment. It wraps the binary to manage environment variables like `NODE_PATH` and prevents the CLI from attempting self-updates, delegating version management to Nix.

## Key Files

*   **`flake.nix`**: The entry point for the Nix Flake. It defines the outputs (`packages`, `apps`, `devShells`) and the overlay. It exposes `gemini-cli` (default) and `gemini-cli-preview`.
*   **`package.nix`**: The Nix derivation for the stable `gemini-cli` package. It handles fetching the npm tarball, installing dependencies (implicitly via the bundled Node.js), and creating the wrapper script.
*   **`package-preview.nix`**: Similar to `package.nix`, but specifically for the `gemini-cli-preview` package, tracking the preview release channel.
*   **`scripts/update-version.sh`**: A Bash script that checks npm for the latest stable version, calculates the new SHA256 hash using `nix-prefetch-url`, and updates `package.nix`.
*   **`scripts/update-preview-version.sh`**: Similar to the stable update script, but tracks the `preview` dist-tag on npm and updates `package-preview.nix`.
*   **`.github/workflows/`**: Contains GitHub Actions workflows for:
    *   Building and testing the package on PRs and main commits.
    *   Running the update scripts on a schedule to automatically create PRs for new versions.

## Building and Running

### Build

To build the packages locally:

```bash
# Build the stable version
nix build .#gemini-cli

# Build the preview version
nix build .#gemini-cli-preview
```

This will create a `result` symlink containing the built package.

### Run

To run the CLI directly without installing:

```bash
# Run the stable version
nix run .

# Run the preview version
nix run .#gemini-cli-preview
```

### Install

To install into your Nix profile:

```bash
nix profile install .#gemini-cli
# or
nix profile install .#gemini-cli-preview
```

## Development & Maintenance

### Automated Updates

The project is designed to be self-updating. GitHub Actions run hourly to check for new versions on npm. If a new version is found, the workflows use the scripts in `scripts/` to update the version and hash in the `.nix` files and open a Pull Request.

### Manual Updates

You can manually trigger an update locally:

```bash
# Update stable version
./scripts/update-version.sh

# Update preview version
./scripts/update-preview-version.sh
```

### Wrapper Logic

The `installPhase` in the `.nix` files creates a wrapper script for the `gemini` binary. This wrapper:
1.  Sets `NODE_PATH` to find the installed modules.
2.  Disables the internal auto-updater (`DISABLE_AUTOUPDATER=1`).
3.  Intercepts `npm` commands used by the CLI for self-updates to ensure they don't conflict with the Nix installation.
4.  Executes the CLI using the bundled Node.js runtime.
