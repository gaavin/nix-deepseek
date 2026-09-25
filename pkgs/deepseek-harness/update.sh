#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash curl jq nodejs nix
# Bump @deepseek-ai/dsh and regenerate the vendored lockfile and hashes.
#
#   ./pkgs/deepseek-harness/update.sh            # follow the `latest` dist-tag
#   ./pkgs/deepseek-harness/update.sh 0.1.7-rc.2 # pin an explicit version
#
# The published tarball has no package-lock.json, so one is generated here from
# the tarball's own package.json (runtime deps only) and committed alongside the
# derivation. Regenerating it is mandatory on every version bump.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
registry="https://registry.npmjs.org/@deepseek-ai/dsh"

version="${1:-$(curl -fsSL "$registry" | jq -r '."dist-tags".latest')}"
echo "==> @deepseek-ai/dsh $version"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

curl -fsSL -o "$work/dsh.tgz" "$registry/-/dsh-$version.tgz"
tar xzf "$work/dsh.tgz" -C "$work"

echo "==> generating package-lock.json"
jq 'del(.devDependencies)' "$work/package/package.json" > "$work/package/package.json.new"
mv "$work/package/package.json.new" "$work/package/package.json"
( cd "$work/package" && npm install --package-lock-only --omit=dev --ignore-scripts --silent )
cp "$work/package/package-lock.json" "$here/package-lock.json"

echo "==> hashing tarball"
src_hash="$(nix store prefetch-file --json --unpack --name dsh-source "$registry/-/dsh-$version.tgz" | jq -r .hash)"

fake="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
sed -i \
  -e "s|^  version = \".*\";|  version = \"$version\";|" \
  -e "s|^    hash = \"sha256-[^\"]*\";|    hash = \"$src_hash\";|" \
  -e "s|^  npmDepsHash = \"sha256-[^\"]*\";|  npmDepsHash = \"$fake\";|" \
  "$here/default.nix"

echo "==> resolving npmDepsHash (the first build is expected to fail)"
got="$(nix build "path:$here/../..#deepseek-harness" --no-link 2>&1 | awk '/got: */ { print $2 }' | tail -1)"
if [ -n "$got" ]; then
  sed -i "s|npmDepsHash = \"sha256-[^\"]*\";|npmDepsHash = \"$got\";|" "$here/default.nix"
fi

echo "==> building"
nix build "path:$here/../..#deepseek-harness" --no-link -L
echo "==> done: $version"
