#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
cd "$repo_root"

workflow=.github/workflows/nix.yml

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_grep() {
  local pattern=$1
  local file=$2
  grep -Eq -- "$pattern" "$file" || fail "missing pattern '$pattern' in $file"
}

# CI container builds must consume the committed flake.lock. Lock input refreshes
# should be explicit pull requests, not side effects of GitHub Actions builds.
require_grep 'profile: \[ minimal, yocto, yocto-scarthgap, yocto-scarthgap-kas52, yocto-kirkstone, yocto-kirkstone-kas52 \]' "$workflow"
require_grep 'VERSION=\$\(nix eval --no-write-lock-file --raw \.#lib\.version\)' "$workflow"
require_grep 'FLAKE_VERSION=\$\(nix eval --no-write-lock-file --raw \.#lib\.version\)' "$workflow"
require_grep 'nix build --no-write-lock-file \.#\$\{\{ matrix\.profile \}\}' "$workflow"
require_grep 'git diff --exit-code -- flake\.lock' "$workflow"
require_grep 'explicit PRs instead of letting container builds mutate flake\.lock' "$workflow"
require_grep "if: github\.ref_type == 'tag'" "$workflow"
require_grep 'docker push "\$IMAGE"' "$workflow"

if grep -Eq 'nix (eval|build)([[:space:]][^-]|[[:space:]]--raw|[[:space:]]+\.#)' "$workflow"; then
  fail 'found nix eval/build invocation without leading --no-write-lock-file'
fi

node - <<'NODE'
const fs = require('fs');
const workflow = fs.readFileSync('.github/workflows/nix.yml', 'utf8');
const profiles = ['minimal', 'yocto', 'yocto-scarthgap', 'yocto-scarthgap-kas52', 'yocto-kirkstone', 'yocto-kirkstone-kas52'];
for (const profile of profiles) {
  if (!workflow.includes(profile)) {
    throw new Error(`missing matrix profile ${profile}`);
  }
}
const nixLines = workflow.split(/\n/).map((line, i) => [i + 1, line.trim()])
  .filter(([, line]) => /(^|\$\()nix (eval|build)\b/.test(line));
if (nixLines.length !== 3) {
  throw new Error(`expected 3 nix eval/build lines, found ${nixLines.length}`);
}
for (const [lineNo, line] of nixLines) {
  if (!/(^|\$\()nix (eval|build) --no-write-lock-file\b/.test(line)) {
    throw new Error(`line ${lineNo} is not lockfile-safe: ${line}`);
  }
}
for (const needle of [
  "if: github.ref_type == 'tag'",
  'IMAGE=ghcr.io/${{ github.repository }}:$TAG',
  'IMAGE=ghcr.io/${{ github.repository }}:${{ matrix.profile }}',
]) {
  if (!workflow.includes(needle)) {
    throw new Error(`missing release behavior marker: ${needle}`);
  }
}
NODE

echo "YXENV-ISS-20260804-174814-001 checks passed"
