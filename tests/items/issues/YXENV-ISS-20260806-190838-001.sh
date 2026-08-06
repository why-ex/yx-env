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

require_grep '^on:$' "$workflow"
require_grep '^  push:$' "$workflow"
require_grep '^    branches: \[ "\*\*" \]$' "$workflow"
require_grep '^    tags: \[ "v\*" \]$' "$workflow"
require_grep '^  pull_request:$' "$workflow"
require_grep '^  workflow_dispatch:$' "$workflow"

node - <<'NODE'
const fs = require('fs');
const workflow = fs.readFileSync('.github/workflows/nix.yml', 'utf8');

const lines = workflow.split(/\r?\n/);
const onIndex = lines.indexOf('on:');
if (onIndex === -1) {
  throw new Error('missing top-level on: block');
}
const laterTopLevel = lines.findIndex((line, index) => index > onIndex && /^[A-Za-z0-9_-]+:/.test(line));
const onBlock = lines.slice(onIndex + 1, laterTopLevel === -1 ? undefined : laterTopLevel);
const triggerLines = onBlock.filter(line => /^  [A-Za-z0-9_-]+:$/.test(line));
const triggers = triggerLines.map(line => line.trim().slice(0, -1));
for (const trigger of ['push', 'pull_request', 'workflow_dispatch']) {
  if (!triggers.includes(trigger)) {
    throw new Error(`missing top-level on.${trigger} trigger`);
  }
}

const dispatchIndex = onBlock.indexOf('  workflow_dispatch:');
if (dispatchIndex === -1) {
  throw new Error('workflow_dispatch is not a top-level on trigger');
}
const nextTrigger = onBlock.findIndex((line, index) => index > dispatchIndex && /^  [A-Za-z0-9_-]+:$/.test(line));
const dispatchBody = onBlock.slice(dispatchIndex + 1, nextTrigger === -1 ? undefined : nextTrigger);
if (dispatchBody.some(line => line.trim() !== '')) {
  throw new Error('workflow_dispatch should remain input-free');
}

const requiredMarkers = [
  'profile: [ minimal, yocto, yocto-scarthgap, yocto-scarthgap-kas52, yocto-kirkstone, yocto-kirkstone-kas52 ]',
  'nix eval --no-write-lock-file --raw .#lib.version',
  'nix build --no-write-lock-file .#${{ matrix.profile }}',
  'git diff --exit-code -- flake.lock',
  'uses: docker/login-action@v4',
  'registry: ghcr.io',
  'username: ${{ github.actor }}',
  'password: ${{ secrets.GITHUB_TOKEN }}',
  "if: github.ref_type == 'tag'",
  'IMAGE=ghcr.io/${{ github.repository }}:$TAG',
  'IMAGE=ghcr.io/${{ github.repository }}:${{ matrix.profile }}',
];
for (const marker of requiredMarkers) {
  if (!workflow.includes(marker)) {
    throw new Error(`missing preserved workflow marker: ${marker}`);
  }
}

const tagOnlyGuardCount = workflow.split("if: github.ref_type == 'tag'").length - 1;
if (tagOnlyGuardCount !== 3) {
  throw new Error(`expected three tag-only guards, found ${tagOnlyGuardCount}`);
}

for (const stepName of ['Verify tag matches flake version', 'Tag and push image', 'Tag latest (only for releases)']) {
  const stepIndex = workflow.indexOf(`- name: ${stepName}`);
  if (stepIndex === -1) {
    throw new Error(`missing step: ${stepName}`);
  }
  const following = workflow.slice(stepIndex, stepIndex + 200);
  if (!following.includes("if: github.ref_type == 'tag'")) {
    throw new Error(`${stepName} is not guarded as tag-only`);
  }
}
NODE

echo "YXENV-ISS-20260806-190838-001 checks passed"
