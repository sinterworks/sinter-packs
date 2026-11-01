#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 The Sinter Authors

set -eu
tool=tree-sitter-limits.sh
. "$(dirname -- "$0")/lib.sh"

usage() {
  cat <<'USAGE'
Usage: tools/tree-sitter-limits.sh CRATE

Read the source of the Rust crate tree-sitter in the folder CRATE, and
print what that tree-sitter accepts in a grammar, one fact per line,
with tabs between the fields:

  version  V         the version of the crate
  import   NAME      a name that a grammar can import
  feature  NAME      a WebAssembly feature of the standard library
                     that tree-sitter gives a grammar
  abi      MIN MAX   the range of ABI versions that it loads

Exit codes: 0 when it prints the facts, 2 when the command line is
wrong, 3 when the folder does not hold the source that the tool reads.
USAGE
}

while getopts h option; do
  case $option in
    h) usage; exit 0 ;;
    *) usage_error "the option is not known" ;;
  esac
done
shift $((OPTIND - 1))
[ "$#" -eq 1 ] || usage_error "give one folder"
crate=$1
[ -d "$crate" ] || usage_error "$crate is not a folder"
src=$crate/src
store=$src/wasm_store.c
api=$crate/include/tree_sitter/api.h
[ -f "$store" ] || fatal "$crate holds no file src/wasm_store.c"
[ -f "$api" ] || fatal "$crate holds no file include/tree_sitter/api.h"
[ -f "$crate/Cargo.toml" ] || fatal "$crate holds no file Cargo.toml"
make_temp_dir

version=$(awk '
  /^\[package\]/ { package = 1; next }
  /^\[/ { package = 0 }
  package && /^version = "[^"]*"$/ { sub(/^version = "/, ""); sub(/"$/, ""); print; exit }
' "$crate/Cargo.toml")
[ -n "$version" ] || fatal "the file Cargo.toml in $crate gives no version of the package"
printf 'version\t%s\n' "$version"

list=$(awk '
  /STDLIB_SYMBOLS\[\] = \{/ { inside = 1; next }
  inside && /^\};/ { exit }
  inside && /#include "/ { sub(/^.*#include "/, ""); sub(/".*$/, ""); print; exit }
' "$store")
[ -n "$list" ] || fatal "the file src/wasm_store.c in $crate names no list of the standard library"
name=${list##*/}
find "$src" -type f -name "$name" >"$temp_dir/lists"
[ "$(awk 'END { print NR }' "$temp_dir/lists")" -eq 1 ] ||
  fatal "the source in $crate does not hold exactly one file $name"
list_file=$(cat "$temp_dir/lists")
awk '
  /^[ \t]*"[A-Za-z_][A-Za-z0-9_]*",?[ \t]*$/ { sub(/^[ \t]*"/, ""); sub(/".*$/, ""); print; next }
  /^[ \t]*$/ { next }
  { bad = 1 }
  END { exit bad }
' "$list_file" >"$temp_dir/symbols" ||
  fatal "the file $name in $crate is not a list of names"
[ -s "$temp_dir/symbols" ] || fatal "the file $name in $crate lists no name"

awk '
  /^static bool ts_wasm_store__provide_builtin_import\(/ { inside = 1; next }
  inside && /^}/ { exit }
  inside {
    line = $0
    while (match(line, /name_eq\(import_name, "[A-Za-z_][A-Za-z0-9_]*"\)/)) {
      found = substr(line, RSTART, RLENGTH)
      sub(/^name_eq\(import_name, "/, "", found)
      sub(/"\)$/, "", found)
      print found
      line = substr(line, RSTART + RLENGTH)
    }
  }
' "$store" >"$temp_dir/builtins"
[ -s "$temp_dir/builtins" ] ||
  fatal "the file src/wasm_store.c in $crate names no import that tree-sitter gives"
sort -u "$temp_dir/symbols" "$temp_dir/builtins" | while IFS= read -r symbol; do
  printf 'import\t%s\n' "$symbol"
done

grep -rl 'STDLIB_WASM\[\] = {' "$src" >"$temp_dir/headers" || true
[ "$(awk 'END { print NR }' "$temp_dir/headers")" -eq 1 ] ||
  fatal "the source in $crate does not hold exactly one standard library module"
header=$(cat "$temp_dir/headers")
WASM_FILE=$header WASM_MODE=header awk -f "$tools_dir/wasm.awk" <"$header" >"$temp_dir/stdlib" ||
  fatal "the standard library module in $crate cannot be read"
awk -F '\t' '$1 == "feature" && ($2 == "+" || $2 == "=") { print "feature\t" $3 }' "$temp_dir/stdlib" | sort -u

define() {
  awk -v name="$1" '$1 == "#define" && $2 == name && $3 ~ /^[0-9]+$/ { print $3; exit }' "$api"
}
low=$(define TREE_SITTER_MIN_COMPATIBLE_LANGUAGE_VERSION)
high=$(define TREE_SITTER_LANGUAGE_VERSION)
[ -n "$low" ] && [ -n "$high" ] ||
  fatal "the file include/tree_sitter/api.h in $crate does not define the range of ABI versions"
printf 'abi\t%s\t%s\n' "$low" "$high"
