#!/usr/bin/env bash
set -euo pipefail

server_root="${1:-.}"
spell_root="$server_root/data/scripts"

if [[ ! -d "$spell_root" ]]; then
  echo "ERROR: Canary data/scripts not found under: $server_root" >&2
  exit 1
fi

check_pair() {
  local id="$1"
  local words="$2"
  local name="$3"
  local files
  local found=0
  files="$(rg -l -F "spell:id(${id})" "$spell_root" || true)"
  while IFS= read -r file; do
    if [[ -n "$file" ]] && rg -q -F "spell:words(\"${words}\")" "$file"; then
      found=1
      break
    fi
  done <<< "$files"
  if [[ "$found" -ne 1 ]]; then
    echo "ERROR: missing ${name}: ID ${id}, words '${words}'" >&2
    return 1
  fi
  echo "OK: ${name} (${id}, ${words})"
}

check_pair 299 "utito dru" "Elemental Synthesis"
check_pair 300 "utura sio" "Shared Conservation"
check_pair 301 "uteta flam" "Master of Flames"
check_pair 302 "uteta vis" "Master of Thunder"
check_pair 303 "uteta mort" "Master of Decay"
check_pair 304 "utori hur" "Divine Defiance"
check_pair 305 "exevo fur frigo" "Forked Glacier"

echo "Server spell prerequisites are present."
