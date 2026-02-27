{
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  jq,
  pkg-config,
  clang_20,
  libsecret,
}:
buildNpmPackage (finalAttrs: {
  pname = "gemini-cli";
  version = "0.30.1";

  src = fetchFromGitHub {
    owner = "google-gemini";
    repo = "gemini-cli";
    rev = "v${finalAttrs.version}";
    hash = "sha256-+8jy5+knmLKxbDUCfK6HQps3dY9b6GffrGytdLawHqk=";
  };

  npmDepsHash = "sha256-bQHJaVOLZFokShj1qcQH/aULqQ4BmszT0qLi325LkUA=";

  nativeBuildInputs = [
    jq
    pkg-config
  ]
  ++ lib.optionals stdenv.isDarwin [ clang_20 ]; # clang_21 breaks @vscode/vsce's optionalDependencies keytar

  buildInputs = [
    libsecret
  ];

  preConfigure = ''
    mkdir -p packages/cli/src/generated packages/core/src/generated
    echo "export const GIT_COMMIT_INFO = '${finalAttrs.src.rev}';" > packages/cli/src/generated/git-commit.ts
    echo "export const CLI_VERSION = '${finalAttrs.version}';" >> packages/cli/src/generated/git-commit.ts
    cp packages/cli/src/generated/git-commit.ts packages/core/src/generated/git-commit.ts
  '';

  postPatch = ''
    # Disable auto-update and notifications by forcing the check to fail early.
    # We patch 'enableAutoUpdateNotification' because it is checked first, and 
    # being the longer variable name, it avoids substring replacement collisions.
    substituteInPlace packages/cli/src/utils/handleAutoUpdate.ts \
      --replace-fail "settings.merged.general.enableAutoUpdateNotification" "false"

    # Remove node-pty dependency from package.json
    ${jq}/bin/jq 'del(.optionalDependencies."node-pty")' package.json > package.json.tmp && mv package.json.tmp package.json

    # Remove node-pty dependency from packages/core/package.json
    ${jq}/bin/jq 'del(.optionalDependencies."node-pty")' packages/core/package.json > packages/core/package.json.tmp && mv packages/core/package.json.tmp packages/core/package.json

    # Add a minimal build script that only builds the packages needed for the CLI,
    # skipping workspaces (vscode-ide-companion, etc.) not required at runtime.
    # The devtools workspace must be built before cli because cli imports its types.
    if [ -d packages/devtools ]; then
      ${jq}/bin/jq '.scripts["build:nix"] = "npm run build --workspace @google/gemini-cli-devtools && npm run build --workspace @google/gemini-cli-core && npm run build --workspace @google/gemini-cli"' package.json > package.json.tmp && mv package.json.tmp package.json
    else
      ${jq}/bin/jq '.scripts["build:nix"] = "npm run build --workspace @google/gemini-cli-core && npm run build --workspace @google/gemini-cli"' package.json > package.json.tmp && mv package.json.tmp package.json
    fi
  '';

  npmBuildScript = "build:nix";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/{bin,share/gemini-cli}

    npm prune --omit=dev

    # Resolve all workspace symlinks to real copies before installing.
    # This handles any current or future packages/ subdirectory without
    # needing to hardcode names. maxdepth 2 covers both unscoped
    # (node_modules/foo) and scoped (node_modules/@scope/foo) packages.
    find node_modules -maxdepth 2 -type l | while read -r link; do
      resolved=$(realpath "$link" 2>/dev/null || true)
      if [[ "$resolved" == "$(pwd)/packages/"* ]] && [[ -d "$resolved" ]]; then
        rm "$link"
        cp -r "$resolved" "$link"
      fi
    done

    cp -r node_modules $out/share/gemini-cli/

    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-core/dist/docs/CONTRIBUTING.md

    ln -s $out/share/gemini-cli/node_modules/@google/gemini-cli/dist/index.js $out/bin/gemini
    chmod +x "$out/bin/gemini"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Gemini CLI - AI assistant in your terminal";
    homepage = "https://github.com/google-gemini/gemini-cli";
    license = licenses.asl20;
    platforms = platforms.all;
    mainProgram = "gemini";
  };
})
