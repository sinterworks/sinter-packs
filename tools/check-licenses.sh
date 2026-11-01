#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 The Sinter Authors

set -eu
tool=check-licenses.sh
. "$(dirname -- "$0")/lib.sh"

usage() {
  cat <<'USAGE'
Usage: tools/check-licenses.sh PACK_ROOT...

Check the licenses of each pack:

  - The top-level license of the descriptor is Apache-2.0.
  - Each license of the descriptor is an SPDX expression of licenses on
    this list: 0BSD, Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC, MIT,
    MPL-2.0, Unlicense. The expression can join licenses with AND and
    OR, and group them in brackets. Each license that it names must be
    on the list, also on a side of OR. An exception, with WITH, is not
    on the list.
  - The folder licenses/ holds exactly these files: Apache-2.0.txt, with
    the text of the Apache-2.0 license of this repository; NOTICE; and
    REPOSITORY.LICENSE, not empty, for each upstream repository that
    NOTICE names.
  - NOTICE starts with the lines "NAME pack of Sinter" and "Copyright
    YEAR The Sinter Authors". Then it holds one block for each grammar of
    the descriptor, in the same order: a blank line, then the lines
    grammar, repository, tag, commit, asset, and sha256. The name and
    the sha256 of each block are those of the descriptor.

Exit codes: 0 when every check passes, 1 when a check fails, 2 when the
command line is wrong, 3 when a command or a file that the tool needs is
missing.
USAGE
}

while getopts h option; do
  case $option in
    h) usage; exit 0 ;;
    *) usage_error "the option is not known" ;;
  esac
done
shift $((OPTIND - 1))
[ "$#" -ge 1 ] || usage_error "give at least one pack folder"
apache=$(repository_root)/LICENSES/Apache-2.0.txt
[ -f "$apache" ] || fatal "the text of the Apache-2.0 license of this repository is missing"
make_temp_dir

check_descriptor_licenses() {
  pack=$1
  descriptor=$2
  top=$(descriptor_value "$descriptor" license) || top=
  if [ "$top" != "Apache-2.0" ]; then
    problem "$pack: the top-level license of the descriptor is \"$top\", and it must be Apache-2.0"
  fi
  while IFS= read -r grammar; do
    if ! descriptor_grammar_value "$descriptor" "$grammar" license >/dev/null; then
      problem "$pack: the grammar $grammar has no license in the descriptor"
    fi
  done <"$temp_dir/grammars"
  awk -F '\t' '$1 == "license" || $1 ~ /\.license$/' "$descriptor" >"$temp_dir/licenses"
  while IFS="$(printf '\t')" read -r key value; do
    message=$(spdx_problem "$value")
    if [ -n "$message" ]; then
      problem "$pack: the value \"$value\" of $key $message"
    fi
  done <"$temp_dir/licenses"
}

check_folder() {
  pack=$1
  descriptor=$2
  folder=$pack/licenses
  if [ ! -d "$folder" ]; then
    problem "$pack has no folder licenses/"
    return
  fi
  if [ ! -f "$folder/Apache-2.0.txt" ]; then
    problem "$pack: licenses/Apache-2.0.txt is missing"
  elif ! cmp -s "$folder/Apache-2.0.txt" "$apache"; then
    problem "$pack: licenses/Apache-2.0.txt is not the text of the Apache-2.0 license of this repository"
  fi
  printf '%s\n' Apache-2.0.txt NOTICE >"$temp_dir/expected"
  if [ ! -f "$folder/NOTICE" ]; then
    problem "$pack: licenses/NOTICE is missing"
  elif ! read_notice "$folder/NOTICE" "$temp_dir/notice" 2>"$temp_dir/error"; then
    problem "$pack: licenses/NOTICE is not in its form: $(head -n 1 "$temp_dir/error")"
  else
    if [ -n "$(tail -c 1 "$folder/NOTICE")" ]; then
      problem "$pack: licenses/NOTICE does not end with a line feed"
    fi
    name=$(descriptor_value "$descriptor" name) || name=
    notice_name=$(awk -F '\t' '$1 == "name" { print $2 }' "$temp_dir/notice")
    if [ "$notice_name" != "$name" ]; then
      problem "$pack: licenses/NOTICE names the pack $notice_name, and the descriptor names it $name"
    fi
    awk -F '\t' '$1 == "grammar" { print $2 }' "$temp_dir/notice" >"$temp_dir/notice-grammars"
    if ! cmp -s "$temp_dir/notice-grammars" "$temp_dir/grammars"; then
      problem "$pack: the blocks of licenses/NOTICE do not name the grammars of the descriptor in their order"
    fi
    awk -F '\t' '$1 == "grammar" { print $2 "\t" $7 }' "$temp_dir/notice" >"$temp_dir/hashes"
    while IFS="$(printf '\t')" read -r grammar hash; do
      expected=$(descriptor_grammar_value "$descriptor" "$grammar" sha256) || continue
      if [ "$hash" != "$expected" ]; then
        problem "$pack: licenses/NOTICE gives the grammar $grammar the sha256 $hash, and the descriptor gives $expected"
      fi
    done <"$temp_dir/hashes"
    awk -F '\t' '$1 == "grammar" { if (($3 in tag) && tag[$3] != $4) print $3; tag[$3] = $4 }' \
      "$temp_dir/notice" | sort -u >"$temp_dir/tags"
    while IFS= read -r repository; do
      problem "$pack: licenses/NOTICE gives two tags of the repository $repository"
    done <"$temp_dir/tags"
    awk -F '\t' '$1 == "grammar" { n = split($3, parts, "/"); print parts[n] ".LICENSE" }' \
      "$temp_dir/notice" | sort -u >>"$temp_dir/expected"
  fi
  sort -u "$temp_dir/expected" >"$temp_dir/expected-sorted"
  find "$folder/." ! -name . -prune -print | sed 's|^.*/||' | sort >"$temp_dir/present"
  comm -13 "$temp_dir/expected-sorted" "$temp_dir/present" >"$temp_dir/extra"
  while IFS= read -r entry; do
    problem "$pack: licenses/$entry is not a file that the folder holds"
  done <"$temp_dir/extra"
  while IFS= read -r entry; do
    case $entry in
      *.LICENSE)
        if [ ! -f "$folder/$entry" ]; then
          problem "$pack: licenses/$entry is missing"
        elif [ ! -s "$folder/$entry" ]; then
          problem "$pack: licenses/$entry is empty"
        fi
        ;;
    esac
  done <"$temp_dir/expected-sorted"
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
  before=$problems
  check_descriptor_licenses "$pack" "$descriptor"
  check_folder "$pack" "$descriptor"
  if [ "$problems" -eq "$before" ]; then
    printf '%s: the licenses pass.\n' "$pack"
  fi
done
finish
