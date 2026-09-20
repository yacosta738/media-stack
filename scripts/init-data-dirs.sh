#!/usr/bin/env bash
set -Eeuo pipefail

DATA_DIR="${DATA_ROOT:-./data}"

for kind in movies tv animes music; do
  mkdir -p "${DATA_DIR}/torrents/${kind}" "${DATA_DIR}/${kind}"
done

printf 'Initialized media layout under %s\n' "$DATA_DIR"
