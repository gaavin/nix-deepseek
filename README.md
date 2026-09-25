<div align="center">

# nix-deepseek

**DeepSeek Harness on NixOS** — DeepSeek's plugin-based AI agent harness (`dsh`), packaged from npm with its plugin tree closed over.

[![NixOS](https://img.shields.io/badge/NixOS-unstable-informational?logo=NixOS)](https://nixos.org)
[![Flake](https://img.shields.io/badge/Flake-enabled-success)](https://nixos.wiki/wiki/Flakes)

</div>

[DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) is DeepSeek's open-source agent harness, built on [Cordis](https://github.com/deepseek-ai/deepseek-harness), in which *everything is a plugin* — models, tools, skills, sessions, sandboxes, storage, loops, scheduling and the UI. This flake packages the `@deepseek-ai/dsh` CLI and its whole plugin dependency tree for `x86_64-linux` and `aarch64-linux`, so you can install it declaratively with flakes and Home Manager instead of `npx`-ing it at runtime.

A DeepSeek API key is required to actually talk to a model.

> DeepSeek Harness is an upstream **developer preview**, published under `-rc` npm tags. Its plugins and APIs are still moving.

## Quick Start

```bash
nix run github:gaavin/nix-deepseek -- --help
nix run github:gaavin/nix-deepseek -- web           # browser UI on 127.0.0.1:3080
```

Requires `x86_64-linux` or `aarch64-linux`, and flakes.

## Install with Home Manager

### 1. Add to flake inputs

```nix
{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-deepseek.url = "github:gaavin/nix-deepseek";
    nix-deepseek.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, nix-deepseek, ... }:
    {
      nixosConfigurations.YOUR_CONFIGURATION = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux"; # or aarch64-linux
        modules = [
          ./configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.YOUR_USERNAME = import ./home.nix;
              sharedModules = [
                nix-deepseek.homeModules.deepseek-harness
              ];
            };
          }
        ];
      };
    };
}
```

### 2. Enable in `home.nix`

```nix
{
  programs.deepseek-harness.enable = true;
}
```

### 3. Build & launch

```bash
nix flake update nix-deepseek
sudo nixos-rebuild switch --flake .#YOUR_CONFIGURATION
export DEEPSEEK_API_KEY=sk-…
dsh web
```

## Profiles

`dsh` does not have subcommands so much as **profiles** — an ordered stack of plugin-bundle patch layers, materialized under `$DSH_HOME` (default `~/.dsh`) the first time you name one. `web` and `headless` ship as templates.

| Command | Purpose |
|---------|---------|
| `dsh web` | Boot the browser UI (`http://127.0.0.1:3080`) |
| `dsh --profile headless "…"` | Answer one task, print the result, exit |
| `dsh --profile NAME --from-default-profile web` | Fork a shipped template into your own profile |
| `dsh --profile NAME --dump-config` | Print the composed plugin tree and exit |
| `dsh plugin --profile NAME add PKG` | Add a plugin to a profile (shells out to pnpm) |
| `dsh --version` | Show installed version |

## Paths

```
~/.dsh/
  profiles/<name>/
    cordis.yml         Composed plugin stack for the profile
    cordis.patch.yml    Your overrides on top of it
    package.json        Profile plugin manifest (pnpm workspace)
```

`DSH_HOME` relocates all of it.

## Notes on the packaging

- Built with `buildNpmPackage` from the **npm tarball**, not the GitHub monorepo — upstream ships `@deepseek-ai/dsh` as a thin CLI whose ~70 plugins are ordinary npm dependencies.
- Upstream publishes no lockfile, so `pkgs/deepseek-harness/package-lock.json` is generated and vendored. It **must** be regenerated on every version bump — use `./pkgs/deepseek-harness/update.sh`.
- `devDependencies` are stripped before `npm ci`; they pull in the entire monorepo test surface.
- Only `node-pty` is rebuilt (`npmRebuildFlags`). A bare `npm rebuild` runs every dependency's install script, and koffi's and `@google/genai`'s want the network.
- The prebuilt ELF payloads that sharp, koffi, node-pty and `@vscode/ripgrep` ship are fixed up with `autoPatchelfHook`.
- `dsh` is wrapped with `pnpm` (used by `dsh plugin`) and `ripgrep` on `PATH`.

## Updating

```bash
./pkgs/deepseek-harness/update.sh            # follow the npm `latest` dist-tag
./pkgs/deepseek-harness/update.sh 0.1.7-rc.2 # or pin a version
```

This refetches the tarball, regenerates the vendored lockfile, rewrites both hashes in `pkgs/deepseek-harness/default.nix`, and builds.

Upstream also publishes `next` and `alpha` dist-tags ahead of `latest`:

```bash
curl -fsSL https://registry.npmjs.org/@deepseek-ai/dsh | jq '."dist-tags"'
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `AUTH: Authentication Fails` | `export DEEPSEEK_API_KEY=sk-…` |
| `profile "tui" does not exist` | Only `web` and `headless` ship as templates; fork one with `--from-default-profile web` |
| A profile is wedged after a version bump | Remove `~/.dsh/profiles/<name>/` and let it re-materialize |
| `dsh plugin add` fails offline | It shells out to pnpm and fetches from the registry — plugins added this way live in `~/.dsh`, outside the Nix store, and are not reproducible |
| Start fresh | Remove `~/.dsh/` |

## Advanced

Package only:

```nix
home.packages = [
  inputs.nix-deepseek.packages.${pkgs.stdenv.hostPlatform.system}.deepseek-harness
];
```

```bash
nix build github:gaavin/nix-deepseek
nix build github:gaavin/nix-deepseek#deepseek-harness
```

There is also an overlay, which adds `pkgs.deepseek-harness`:

```nix
nixpkgs.overlays = [ inputs.nix-deepseek.overlays.default ];
```

## Credits

- [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness) — the harness itself (MIT)
- [DeepSeek Harness docs](https://deepseek.com/harness/en/) — official developer preview docs
