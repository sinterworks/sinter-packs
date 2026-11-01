#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 The Sinter Authors

set -eu
tool=check-queries.sh
. "$(dirname -- "$0")/lib.sh"

usage() {
  cat <<'USAGE'
Usage: tools/check-queries.sh -s SINTER PACK_ROOT...

Check that each query file queries/GRAMMAR/*.scm of each pack compiles
against its grammar. The tool runs SINTER parse --grammar with the file
grammars/GRAMMAR.wasm and --query with the query file, on an empty
sample file. Each folder under queries/ must have the name of a grammar
of the descriptor.

Exit codes: 0 when every query compiles, 1 when a check fails, 2 when
the command line is wrong, 3 when a command that the tool needs is
missing.
USAGE
}

sinter=
while getopts hs: option; do
  case $option in
    h) usage; exit 0 ;;
    s) sinter=$OPTARG ;;
    *) usage_error "the option is not known" ;;
  esac
done
shift $((OPTIND - 1))
[ -n "$sinter" ] || usage_error "give the sinter command with -s"
[ "$#" -ge 1 ] || usage_error "give at least one pack folder"
[ -x "$sinter" ] || command -v "$sinter" >/dev/null 2>&1 || fatal "$sinter is not a command"
make_temp_dir
sample=$temp_dir/sample
: >"$sample"

for pack in "$@"; do
  pack=${pack%/}
  descriptor=$temp_dir/descriptor
  if [ ! -f "$pack/pack.toml" ]; then
    problem "$pack has no descriptor pack.toml"
    continue
  fi
  if ! read_descriptor "$pack/pack.toml" "$descriptor" 2>"$temp_dir/error"; then
    problem "$pack: the descriptor cannot be read: $(head -n 1 "$temp_dir/error")"
    continue
  fi
  descriptor_grammars "$descriptor" >"$temp_dir/grammars"
  if [ -d "$pack/queries" ]; then
    find "$pack/queries/." ! -name . -prune -print >"$temp_dir/entries"
    while IFS= read -r entry; do
      name=${entry##*/}
      if ! grep -Fqx -- "$name" "$temp_dir/grammars"; then
        problem "$pack: queries/$name belongs to no grammar of the descriptor"
      fi
    done <"$temp_dir/entries"
  fi
  while IFS= read -r grammar; do
    matches "$grammar" '[a-z][a-z0-9_]*' || continue
    wasm=$pack/grammars/$grammar.wasm
    if [ ! -f "$wasm" ]; then
      problem "$pack: the grammar $grammar has no file grammars/$grammar.wasm"
      continue
    fi
    found=0
    for query in "$pack/queries/$grammar"/*.scm; do
      [ -f "$query" ] || continue
      found=1
      if "$sinter" parse --grammar "$wasm" --query "$query" "$sample" </dev/null >/dev/null 2>"$temp_dir/error"; then
        printf '%s: queries/%s/%s compiles.\n' "$pack" "$grammar" "${query##*/}"
      else
        problem "$pack: queries/$grammar/${query##*/} does not compile: $(head -n 1 "$temp_dir/error")"
      fi
    done
    if [ "$found" -eq 0 ]; then
      printf '%s: the grammar %s has no query file.\n' "$pack" "$grammar"
    fi
  done <"$temp_dir/grammars"
done
finish
