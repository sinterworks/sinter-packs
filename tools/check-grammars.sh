#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 The Sinter Authors

set -eu
tool=check-grammars.sh
. "$(dirname -- "$0")/lib.sh"

usage() {
  cat <<'USAGE'
Usage: tools/check-grammars.sh -t CRATE PACK_ROOT...

Check each grammar of each pack against its descriptor and against the
tree-sitter whose source is in the folder CRATE:

  - the file grammars/NAME.wasm exists, and its SHA-256 is the sha256
    of the descriptor;
  - each name that the file imports is a name that tree-sitter gives a
    grammar;
  - each WebAssembly feature that the file uses is a feature of the
    standard library of tree-sitter. A file with no target_features
    section passes this check; only the load of the grammar checks its
    features then;
  - the file exports tree_sitter_NAME, and its ABI version is in the
    range that tree-sitter loads.

Exit codes: 0 when every check passes, 1 when a check fails, 2 when the
command line is wrong, 3 when a command or a file that the tool needs is
missing.
USAGE
}

crate=
while getopts ht: option; do
  case $option in
    h) usage; exit 0 ;;
    t) crate=$OPTARG ;;
    *) usage_error "the option is not known" ;;
  esac
done
shift $((OPTIND - 1))
[ -n "$crate" ] || usage_error "give the folder of the tree-sitter crate with -t"
[ "$#" -ge 1 ] || usage_error "give at least one pack folder"
make_temp_dir

"$tools_dir/tree-sitter-limits.sh" "$crate" >"$temp_dir/limits" || exit 3
ts_version=$(awk -F '\t' '$1 == "version" { print $2 }' "$temp_dir/limits")
abi_low=$(awk -F '\t' '$1 == "abi" { print $2 }' "$temp_dir/limits")
abi_high=$(awk -F '\t' '$1 == "abi" { print $3 }' "$temp_dir/limits")
awk -F '\t' '$1 == "import" { print $2 }' "$temp_dir/limits" >"$temp_dir/imports"
awk -F '\t' '$1 == "feature" { print $2 }' "$temp_dir/limits" >"$temp_dir/features"

check_grammar() {
  pack=$1
  grammar=$2
  descriptor=$3
  label="$pack: the grammar $grammar"
  before=$problems
  file=$pack/grammars/$grammar.wasm
  if [ ! -f "$file" ] || [ -L "$file" ]; then
    problem "$label has no file grammars/$grammar.wasm"
    return
  fi
  expected=$(descriptor_grammar_value "$descriptor" "$grammar" sha256) || expected=
  if ! is_hex "$expected" 64; then
    problem "$label has no sha256 of 64 lowercase hex digits in the descriptor"
    return
  fi
  actual=$(sha256_of "$file")
  if [ "$actual" != "$expected" ]; then
    problem "$label has the SHA-256 $actual, and the descriptor gives $expected"
  fi
  if ! wasm_info "$file" "$grammar" >"$temp_dir/info" 2>"$temp_dir/error"; then
    problem "$label cannot be read: $(head -n 1 "$temp_dir/error")"
    return
  fi
  awk -F '\t' '$1 == "import" { print $3 }' "$temp_dir/info" | sort -u >"$temp_dir/used"
  comm -23 "$temp_dir/used" "$temp_dir/imports" >"$temp_dir/unknown"
  while IFS= read -r name; do
    problem "$label imports $name, which tree-sitter $ts_version does not give a grammar"
  done <"$temp_dir/unknown"
  awk -F '\t' '$1 == "feature" && ($2 == "+" || $2 == "=") { print $3 }' "$temp_dir/info" |
    sort -u >"$temp_dir/wanted"
  if ! grep -q '^feature' "$temp_dir/info"; then
    printf '%s has no target_features section, so only its load checks its WebAssembly features.\n' "$label"
  fi
  comm -23 "$temp_dir/wanted" "$temp_dir/features" >"$temp_dir/unknown"
  while IFS= read -r name; do
    problem "$label uses the WebAssembly feature $name, which the standard library of tree-sitter $ts_version does not use"
  done <"$temp_dir/unknown"
  abi=$(awk -F '\t' '$1 == "abi" { print $2 }' "$temp_dir/info")
  if [ "$abi" -lt "$abi_low" ] || [ "$abi" -gt "$abi_high" ]; then
    problem "$label has the ABI version $abi, and tree-sitter $ts_version loads the versions $abi_low to $abi_high"
  fi
  if [ "$problems" -eq "$before" ]; then
    printf '%s passes: ABI version %s, %s imports, %s features.\n' "$label" "$abi" \
      "$(awk 'END { print NR }' "$temp_dir/used")" "$(awk 'END { print NR }' "$temp_dir/wanted")"
  fi
}

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
  if [ ! -s "$temp_dir/grammars" ]; then
    problem "$pack: the descriptor names no grammar"
    continue
  fi
  sort "$temp_dir/grammars" | uniq -d >"$temp_dir/twice"
  while IFS= read -r grammar; do
    problem "$pack: the descriptor names the grammar $grammar twice"
  done <"$temp_dir/twice"
  while IFS= read -r grammar; do
    if ! matches "$grammar" '[a-z][a-z0-9_]*'; then
      problem "$pack: the descriptor names a grammar $grammar, which is not a name of a grammar"
      continue
    fi
    check_grammar "$pack" "$grammar" "$descriptor"
  done <"$temp_dir/grammars"
done
finish
