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
  pname = "gemini-cli-preview";
  version = "0.29.0-preview.3";

  src = fetchFromGitHub {
    owner = "google-gemini";
    repo = "gemini-cli";
    rev = "v${finalAttrs.version}";
    hash = "sha256-xmFU5itxGyhcLDAT3kOPrSR4U1TU6m/l4X7NBL0o7+U=";
  };

  npmDepsHash = "sha256-+WoqXoI3KgGBCAfqVZ0tF4jG/ew/i3rhq4c8wd146Nw=";

  nativeBuildInputs = [
    jq
    pkg-config
  ]
  ++ lib.optionals stdenv.isDarwin [ clang_20 ]; # clang_21 breaks @vscode/vsce's optionalDependencies keytar

  buildInputs = [
    libsecret
  ];

  preConfigure = ''
    mkdir -p packages/generated
    echo "export const GIT_COMMIT_INFO = { commitHash: '${finalAttrs.src.rev}' };" > packages/generated/git-commit.ts
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
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/{bin,share/gemini-cli}

    npm prune --omit=dev
    cp -r node_modules $out/share/gemini-cli/

    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-core
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-a2a-server
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-test-utils
    rm -f $out/share/gemini-cli/node_modules/gemini-cli-vscode-ide-companion
    cp -r packages/cli $out/share/gemini-cli/node_modules/@google/gemini-cli
    cp -r packages/core $out/share/gemini-cli/node_modules/@google/gemini-cli-core
    cp -r packages/a2a-server $out/share/gemini-cli/node_modules/@google/gemini-cli-a2a-server

    # Remove the broken symlink that points to the deleted /build directory
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-core/dist/docs/CONTRIBUTING.md

    ln -s $out/share/gemini-cli/node_modules/@google/gemini-cli/dist/index.js $out/bin/gemini-preview
    chmod +x "$out/bin/gemini-preview"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Gemini CLI (Preview) - AI assistant in your terminal";
    homepage = "https://github.com/google-gemini/gemini-cli";
    license = licenses.asl20;
    platforms = platforms.all;
    mainProgram = "gemini-preview";
  };
})
