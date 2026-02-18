#!/usr/bin/env bash
set -euo pipefail

# Configuration
PACKAGE_FILE="package.nix"
FLAKE_ATTR="gemini-cli"
NPM_PACKAGE="@google/gemini-cli"
FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

echo "Checking for latest Gemini CLI version..."
LATEST_VERSION=$(npm view "$NPM_PACKAGE" version)
CURRENT_VERSION=$(grep 'version =' "$PACKAGE_FILE" | cut -d '"' -f 2)

if [ "$LATEST_VERSION" == "$CURRENT_VERSION" ]; then
  echo "Already at latest version: $CURRENT_VERSION"
  exit 0
fi

echo "Updating $FLAKE_ATTR from $CURRENT_VERSION to $LATEST_VERSION..."

# 1. Update the version number
sed -i "s/version = \".*\"/version = \"$LATEST_VERSION\"/" "$PACKAGE_FILE"

# 2. Invalidate hashes to force Nix to re-calculate them
# We replace the existing hashes with a fake one so the build fails and tells us the real one.
sed -i "s/hash = \".*\"/hash = \"$FAKE_HASH\"/" "$PACKAGE_FILE"
sed -i "s/npmDepsHash = \".*\"/npmDepsHash = \"$FAKE_HASH\"/" "$PACKAGE_FILE"

# 3. Fetch the new Source Hash
echo "Fetching new source hash via Nix build..."
# This is expected to fail. We capture the output to find the "got:" hash.
OUTPUT=$(nix build .#$FLAKE_ATTR 2>&1 || true)
NEW_SRC_HASH=$(echo "$OUTPUT" | grep "got:" | head -n1 | cut -d ':' -f 2 | xargs)

if [[ -z "$NEW_SRC_HASH" || "$NEW_SRC_HASH" != sha256-* ]]; then
    echo "Failed to extract source hash. Build output:"
    echo "$OUTPUT"
    exit 1
fi

echo "Found source hash: $NEW_SRC_HASH"
# Update ONLY the source hash (key is "hash =")
sed -i "s|hash = \"$FAKE_HASH\"|hash = \"$NEW_SRC_HASH\"|" "$PACKAGE_FILE"

# 4. Fetch the new NPM Deps Hash
echo "Fetching new npmDepsHash via Nix build..."
# Run build again. It will verify source (now correct), but fail on npmDeps.
OUTPUT=$(nix build .#$FLAKE_ATTR 2>&1 || true)
NEW_DEPS_HASH=$(echo "$OUTPUT" | grep "got:" | head -n1 | cut -d ':' -f 2 | xargs)

if [[ -z "$NEW_DEPS_HASH" || "$NEW_DEPS_HASH" != sha256-* ]]; then
    echo "Failed to extract npm deps hash. Build output:"
    echo "$OUTPUT"
    exit 1
fi

echo "Found npm hash: $NEW_DEPS_HASH"
# Update the deps hash (key is "npmDepsHash =")
sed -i "s|npmDepsHash = \"$FAKE_HASH\"|npmDepsHash = \"$NEW_DEPS_HASH\"|" "$PACKAGE_FILE"

# 5. Final Verification
echo "Verifying successful build..."
nix build .#$FLAKE_ATTR
echo "Updated $PACKAGE_FILE to version $LATEST_VERSION successfully."
