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

reject_grep() {
  local pattern=$1
  local file=$2
  if grep -Eq -- "$pattern" "$file"; then
    fail "found deprecated pattern '$pattern' in $file"
  fi
}

require_grep 'uses: actions/checkout@v5' "$workflow"
require_grep 'uses: docker/login-action@v4' "$workflow"
reject_grep 'uses: actions/checkout@v4' "$workflow"
reject_grep 'uses: docker/login-action@v3' "$workflow"

node - <<'NODE'
const fs = require('fs');
const workflow = fs.readFileSync('.github/workflows/nix.yml', 'utf8');

const expectedMarkers = [
  'profile: [ minimal, yocto, yocto-scarthgap, yocto-scarthgap-kas52, yocto-kirkstone, yocto-kirkstone-kas52 ]',
  'nix build --no-write-lock-file .#${{ matrix.profile }}',
  "if: github.ref_type == 'tag'",
  'registry: ghcr.io',
  'username: ${{ github.actor }}',
  'password: ${{ secrets.GITHUB_TOKEN }}',
  'IMAGE=ghcr.io/${{ github.repository }}:$TAG',
  'IMAGE=ghcr.io/${{ github.repository }}:${{ matrix.profile }}',
];
for (const marker of expectedMarkers) {
  if (!workflow.includes(marker)) {
    throw new Error(`missing preserved workflow marker: ${marker}`);
  }
}

const deprecatedRefs = ['actions/checkout@v4', 'docker/login-action@v3'];
for (const ref of deprecatedRefs) {
  if (workflow.includes(ref)) {
    throw new Error(`deprecated action reference remains: ${ref}`);
  }
}

const expectedRefs = ['actions/checkout@v5', 'docker/login-action@v4'];
for (const ref of expectedRefs) {
  const count = workflow.split(ref).length - 1;
  if (count !== 1) {
    throw new Error(`expected exactly one ${ref} reference, found ${count}`);
  }
}
NODE

echo "YXENV-ISS-20260806-183628-001 checks passed"
