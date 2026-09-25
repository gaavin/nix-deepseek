{
  lib,
  stdenv,
  buildNpmPackage,
  fetchzip,
  autoPatchelfHook,
  jq,
  makeWrapper,
  nodejs,
  pnpm,
  python3,
  ripgrep,
  versionCheckHook,
}:

buildNpmPackage (finalAttrs: {
  pname = "deepseek-harness";
  version = "0.1.5-rc.3";

  # Upstream publishes the harness as a thin `@deepseek-ai/dsh` CLI whose
  # plugins are all ordinary npm dependencies, so the registry tarball is the
  # source of truth rather than the GitHub monorepo.
  src = fetchzip {
    url = "https://registry.npmjs.org/@deepseek-ai/dsh/-/dsh-${finalAttrs.version}.tgz";
    hash = "sha256-dQHxFoYIcF+0Qnsk+qKoHxtIwzNfAogpUatA+lkFxsU=";
  };

  inherit nodejs;

  # The published tarball ships no lockfile, so one is vendored here (see
  # ./update.sh). It covers the runtime deps only; devDependencies pull in the
  # whole monorepo test surface, and are dropped from package.json so that
  # `npm ci` still sees a lockfile in sync with it.
  postPatch = ''
    jq 'del(.devDependencies)' package.json > package.json.new
    mv package.json.new package.json
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-1CbEeK4aGKRDWv74WHxy98GmSSO7B/y9bypeI8dVyx4=";

  # Nothing to compile: lib/*.js is already built in the tarball.
  dontNpmBuild = true;

  # A bare `npm rebuild` runs every dependency's install script, and several of
  # those (koffi, @google/genai) want to reach the network. node-pty is the only
  # one that matters, and it resolves from its own bundled prebuilds.
  npmRebuildFlags = [ "node-pty" ];

  nativeBuildInputs = [
    autoPatchelfHook
    jq
    makeWrapper
    python3
  ];

  buildInputs = [ stdenv.cc.cc.lib ];

  # sharp, koffi and node-pty ship prebuilt ELF payloads built against a
  # generic glibc; autoPatchelf fixes their interpreter and RPATH. The musl
  # variants sitting next to the glibc ones are never loaded here.
  autoPatchelfIgnoreMissingDeps = [ "libc.musl-*.so.1" ];

  # `dsh plugin` forwards to pnpm inside the profile directory, and the agent's
  # search tooling shells out to rg.
  postInstall = ''
    wrapProgram $out/bin/dsh \
      --prefix PATH : ${
        lib.makeBinPath [
          pnpm
          ripgrep
        ]
      }
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";
  doInstallCheck = true;

  meta = {
    description = "DeepSeek Harness (dsh) — DeepSeek's plugin-based AI agent harness";
    longDescription = ''
      DeepSeek Harness is DeepSeek's open-source agent harness, built on Cordis,
      in which every capability — models, tools, skills, sessions, sandboxes,
      storage, loops, scheduling and the UI — is a plugin. `dsh` boots a profile,
      an ordered stack of plugin-bundle patch layers; the shipped `web` and
      `headless` profiles are templates for your own.
    '';
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    changelog = "https://github.com/deepseek-ai/deepseek-harness/releases";
    license = lib.licenses.mit;
    mainProgram = "dsh";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
