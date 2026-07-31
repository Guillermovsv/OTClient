#!/usr/bin/env bash

set -euo pipefail

package_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
client_dir="$PWD"
if (($# >= 1)); then
  client_dir="$1"
fi
source_dir="$package_dir/otclient"
timestamp="$(date -u '+%Y%m%dT%H%M%SZ')"
backup_dir="$client_dir/data/things/1525/backups/master-sorcerer-2026-07-30/$timestamp"

[[ -d "$client_dir/data/things/1525" ]] || {
  printf 'OTClient checkout not found: %s\n' "$client_dir" >&2
  exit 1
}

mkdir -p "$backup_dir"

copy_file() {
  local relative_path="$1"
  local source="$source_dir/$relative_path"
  local target="$client_dir/$relative_path"
  local backup="$backup_dir/$relative_path"
  [[ -f "$source" ]] || { printf 'Missing package file: %s\n' "$source" >&2; exit 1; }
  if [[ -f "$target" ]]; then
    mkdir -p "$(dirname "$backup")"
    cp "$target" "$backup"
  fi
  mkdir -p "$(dirname "$target")"
  cp "$source" "$target"
}

copy_file modules/game_stance_spell_visuals/game_stance_spell_visuals.lua
copy_file modules/game_stance_spell_visuals/game_stance_spell_visuals.otmod
copy_file modules/game_stances/game_stances.lua
copy_file modules/game_stances/game_stances.otmod
copy_file modules/client_options/data_options.lua
copy_file data/things/1525/appearances-custom01.dat
copy_file data/things/1525/catalog-content.json
copy_file data/things/1525/assets.json.sha256
copy_file data/things/1525/master-sorcerer-effect-mapping.json
for sheet in "$source_dir"/data/things/1525/sprites-master-sorcerer-*.bmp.lzma; do
  copy_file "data/things/1525/$(basename "$sheet")"
done

catalog_hash="$(shasum -a 256 "$client_dir/data/things/1525/catalog-content.json" | awk '{print $1}')"
expected_hash="$(awk '{print $1}' "$client_dir/data/things/1525/assets.json.sha256")"
[[ "$catalog_hash" == "$expected_hash" ]] || {
  printf 'Catalog hash mismatch: expected %s, got %s\n' "$expected_hash" "$catalog_hash" >&2
  exit 1
}

if command -v luac >/dev/null 2>&1; then
  luac -p \
    "$client_dir/modules/game_stance_spell_visuals/game_stance_spell_visuals.lua" \
    "$client_dir/modules/game_stances/game_stances.lua" \
    "$client_dir/modules/client_options/data_options.lua"
fi

printf 'Client update installed and verified.\n'
printf 'Backup: %s\n' "$backup_dir"
