#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
publisher="$repo_root/publisher/publish_vivo.py"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/publish-local.sh PATH/TO/OUTPUT.ttl --dry-run
  ./scripts/publish-local.sh PATH/TO/OUTPUT.ttl [--visibility public|logged-in|private]

Run this command from the fonda-vivo-run-publisher repository root.
The dry run validates the TTL without contacting VIVO. A real publication
prompts for the non-admin VIVO publisher email and password without storing
them on disk.

--visibility sets who may see the run page in VIVO: public, logged-in
(logged-in VIVO users only) or private (only the person who ran it). Without
it, RUN_VISIBILITY is used; without both, a new run is public and a run
published again keeps the choice made on its VIVO page.
EOF
}

if [[ ${1:-} == "--help" || ${1:-} == "-h" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 2
fi

ttl_file=$1
shift
mode=""
visibility="${RUN_VISIBILITY:-}"
while (($#)); do
  case "$1" in
    --dry-run) mode="--dry-run" ;;
    --visibility)
      if (($# < 2)); then
        printf 'ERROR: --visibility requires public, logged-in or private\n' >&2
        exit 2
      fi
      visibility="$2"
      shift
      ;;
    *)
      printf 'ERROR: unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done
if [[ ! -r "$ttl_file" ]]; then
  printf 'ERROR: TTL file is not readable: %s\n' "$ttl_file" >&2
  exit 1
fi
if [[ ! -r "$publisher" ]]; then
  printf 'ERROR: publisher was not found: %s\n' "$publisher" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  printf 'ERROR: python3 is required.\n' >&2
  exit 1
fi

if [[ "$mode" == "--dry-run" ]]; then
  python3 "$publisher" "$ttl_file" --dry-run --visibility "$visibility"
  exit 0
fi

printf 'VIVO publisher email: ' >&2
IFS= read -r vivo_email
printf 'VIVO publisher password: ' >&2
IFS= read -r -s vivo_password
printf '\n' >&2
trap 'unset vivo_email vivo_password' EXIT

if [[ "$vivo_email" != *@* ]]; then
  printf 'ERROR: enter the complete VIVO account email address.\n' >&2
  exit 1
fi
if [[ -z "$vivo_password" ]]; then
  printf 'ERROR: the VIVO password cannot be empty.\n' >&2
  exit 1
fi

python3 "$publisher" "$ttl_file" \
  --visibility "$visibility" \
  --email-file <(printf '%s\n' "$vivo_email") \
  --password-file <(printf '%s\n' "$vivo_password")
