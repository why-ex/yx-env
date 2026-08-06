#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
cd "$repo_root"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

if command -v nix >/dev/null 2>&1; then
  version=$(nix eval --raw .#lib.version)
else
  version=$(awk -F'"' '/yxEnvVer[[:space:]]*=/ { print $2; found=1; exit } END { if (!found) exit 1 }' flake.nix) \
    || fail "unable to find yxEnvVer in flake.nix"
fi

version_re=${version//./\\.}

maintained_docs=(
  README.md
  docs/images.md
  REQUIREMENTS.md
)
coord_requirements=(
  .pi-en/coordination/requirements/WHYEX-FRQ-20260725-140553-004.yaml
  .pi-en/coordination/requirements/WHYEX-QRQ-20260725-140553-045.yaml
)

image_tag_pattern="(ghcr\\.io/why-ex/)?yx-env:${version_re}-[A-Za-z0-9_.-]+"
if grep -nE -- "$image_tag_pattern" "${maintained_docs[@]}" "${coord_requirements[@]}"; then
  fail "found hardcoded current yx-env image tag outside flake.nix"
fi

# Requirement text should describe invariants instead of duplicating the
# concrete current release number. flake.nix remains the source of that value.
plain_version_pattern="(^|[^A-Za-z0-9_.-])${version_re}([^A-Za-z0-9_.-]|$)"
if grep -nE -- "$plain_version_pattern" REQUIREMENTS.md "${coord_requirements[@]}"; then
  fail "found hardcoded current version in requirement text"
fi

grep -Fq 'YXENV_VERSION="$(nix eval --raw .#lib.version)"' README.md \
  || fail "README.md does not derive YXENV_VERSION from .#lib.version"
grep -Fq '"yx-env:${YXENV_VERSION}-yocto"' README.md \
  || fail "README.md does not use the derived local yocto tag"

grep -Fq 'ghcr.io/why-ex/yx-env:<version>-<profile>' docs/images.md \
  || fail "docs/images.md does not document symbolic version/profile tag shape"
grep -Fq 'ghcr.io/why-ex/yx-env:<version>-yocto-scarthgap-kas52' docs/images.md \
  || fail "docs/images.md does not use symbolic GHCR version examples"
grep -Fq 'YXENV_VERSION="$(nix eval --raw .#lib.version)"' docs/images.md \
  || fail "docs/images.md local image example does not derive YXENV_VERSION"
grep -Fq '"yx-env:${YXENV_VERSION}-yocto-scarthgap-kas52"' docs/images.md \
  || fail "docs/images.md does not use the derived local image tag"

grep -Fq 'YXENV_VERSION="$(nix eval --raw .#lib.version)"' REQUIREMENTS.md \
  || fail "REQUIREMENTS.md container smoke test does not derive YXENV_VERSION"
grep -Fq '"yx-env:${YXENV_VERSION}-minimal"' REQUIREMENTS.md \
  || fail "REQUIREMENTS.md does not use the derived minimal image tag"
grep -Fq 'The expected value MUST match the version assigned to `yxEnvVer` in' REQUIREMENTS.md \
  || fail "REQUIREMENTS.md does not describe the version invariant"

grep -Fq "yxEnvVer = \"${version}\";" flake.nix \
  || fail "flake.nix does not contain the version reported by .#lib.version"

echo "YXENV-ISS-20260806-192651-001 checks passed"
