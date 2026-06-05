#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: run-kas-smoke.sh <scarthgap|kirkstone|path-to-kas.yml> [dump|checkout|parse]

Modes:
  dump      Run 'kas dump' only. This validates kas/config parsing without checkout.
  checkout  Run 'kas dump' and 'kas checkout'.
  parse     Run checkout and then 'kas shell -c bitbake -p'. No image is built.

Run from a disposable workspace; kas checkout creates source directories there.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

release_or_file="${1:-scarthgap}"
mode="${2:-dump}"

case "$release_or_file" in
  scarthgap|kirkstone)
    smoke_name="$release_or_file"
    kas_file="$script_dir/kas/${release_or_file}.yml"
    ;;
  *)
    if [[ -f "$release_or_file" ]]; then
      smoke_name="custom"
      kas_file="$release_or_file"
    else
      echo "Unknown smoke config: $release_or_file" >&2
      usage >&2
      exit 2
    fi
    ;;
esac

case "$mode" in
  dump|checkout|parse) ;;
  *)
    echo "Unknown smoke mode: $mode" >&2
    usage >&2
    exit 2
    ;;
esac

if ! command -v kas >/dev/null 2>&1; then
  echo "kas is not available. Enter a kas profile such as yocto-scarthgap-kas52." >&2
  exit 127
fi

if [[ "${YXENV:-}" != "1" ]]; then
  echo "warning: YXENV=1 is not set; this does not look like a yx-env shell/container" >&2
fi

dump_file="${TMPDIR:-/tmp}/yx-env-kas-smoke-${smoke_name}.dump.yml"

echo "[yx-env smoke] kas file: $kas_file"
echo "[yx-env smoke] mode: $mode"
echo "+ kas dump $kas_file > $dump_file"
kas dump "$kas_file" > "$dump_file"
echo "[yx-env smoke] wrote expanded config: $dump_file"

if [[ "$mode" == "dump" ]]; then
  exit 0
fi

echo "+ kas checkout $kas_file"
kas checkout "$kas_file"

if [[ "$mode" == "checkout" ]]; then
  exit 0
fi

echo "+ kas shell $kas_file -c 'bitbake -p'"
kas shell "$kas_file" -c 'bitbake -p'
