#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
cd "$repo_root"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_grep() {
  local pattern=$1
  local file=$2
  grep -Eq -- "$pattern" "$file" || fail "missing pattern '$pattern' in $file"
}

require_grep 'nixpkgs-kas52\.url = "github:nixos/nixpkgs/[0-9a-f]{40}"' flake.nix
require_grep 'outputs = \{ self, nixpkgs, nixpkgs-kas52, pi-en \}:' flake.nix
require_grep 'kas52Pkgs = import nixpkgs-kas52 \{ inherit system config; \};' flake.nix
require_grep 'yocto-scarthgap-kas52 = import ./profiles/yocto-scarthgap-kas52\.nix \{ inherit pkgs kas52Pkgs; \};' flake.nix
require_grep 'yocto-kirkstone-kas52 = import ./profiles/yocto-kirkstone-kas52\.nix \{ inherit pkgs kas52Pkgs; \};' flake.nix

node - <<'NODE'
const fs = require('fs');
const lock = JSON.parse(fs.readFileSync('flake.lock', 'utf8'));
const input = lock.nodes.root.inputs['nixpkgs-kas52'];
if (input !== 'nixpkgs-kas52') {
  throw new Error('root input nixpkgs-kas52 is not wired in flake.lock');
}
const node = lock.nodes['nixpkgs-kas52'];
if (!node || node.locked.type !== 'github' || node.locked.repo !== 'nixpkgs') {
  throw new Error('nixpkgs-kas52 lock node is missing or not a nixpkgs GitHub input');
}
if (!/^[0-9a-f]{40}$/.test(node.locked.rev) || !node.locked.narHash) {
  throw new Error('nixpkgs-kas52 lock node is not pinned by rev and narHash');
}
NODE

require_grep 'expectedVersion = "5\.2";' profiles/kas-5_2.nix
require_grep 'assert lib\.assertMsg \(actualVersion == expectedVersion\)' profiles/kas-5_2.nix
require_grep 'pkgs = kas52Pkgs;' profiles/pkgs-yocto-scarthgap-kas52.nix
require_grep 'pkgs = kas52Pkgs;' profiles/pkgs-yocto-kirkstone-kas52.nix

if grep -R 'import ./kas-5_2.nix { inherit pkgs; }' profiles/*kas52*.nix; then
  fail 'kas52 profiles still import kas-5_2.nix from main pkgs'
fi

nix_bin=${NIX_BIN:-}
if [[ -z "$nix_bin" ]] && command -v nix >/dev/null 2>&1; then
  nix_bin=$(command -v nix)
fi
if [[ -z "$nix_bin" ]]; then
  nix_bin=$(find /nix/store -maxdepth 3 -type f -path '*/bin/nix' 2>/dev/null | sort -Vr | head -n 1 || true)
fi

if [[ -n "$nix_bin" ]]; then
  nix_args=(--extra-experimental-features 'nix-command flakes')
  "$nix_bin" "${nix_args[@]}" eval --raw .#packages.x86_64-linux.yocto-kirkstone-kas52.name >/dev/null
  "$nix_bin" "${nix_args[@]}" eval --impure --raw --expr "let f = builtins.getFlake \"path:$repo_root\"; in (import ./profiles/kas-5_2.nix { pkgs = f.inputs.nixpkgs-kas52.legacyPackages.x86_64-linux; }).version" | grep -qx '5.2'
fi

echo "YXENV-ISS-20260804-174813-001 checks passed"
