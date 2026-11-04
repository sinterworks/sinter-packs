#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 The Sinter Authors

set -eu
tool=check-query-tests.sh
. "$(dirname -- "$0")/lib.sh"

usage() {
  cat <<'USAGE'
Usage: tools/check-query-tests.sh [-u] -s SINTER [REPOSITORY]

Run the query tests of REPOSITORY, by default the repository that holds
this tool. The folder tests/PACK/GRAMMAR/ holds the cases of the grammar
GRAMMAR of the pack in packs/PACK/:

  - CASE.EXT is a case: a small file of the language. A case has one
    extension, and no other case of the folder has its name CASE.
  - CASE.QUERY.jsonl holds the captures that the query file
    queries/GRAMMAR/QUERY.scm of the pack must give for the case.

At the root of REPOSITORY, the tool runs this command for each case and
each query file of its grammar, and compares the output with
CASE.QUERY.jsonl byte for byte:

  SINTER parse --grammar packs/PACK/grammars/GRAMMAR.wasm \
    --query packs/PACK/queries/GRAMMAR/QUERY.scm tests/PACK/GRAMMAR/CASE.EXT

A check fails when the output differs, when the command fails, when a
case has no file CASE.QUERY.jsonl for a query file, when a file
CASE.QUERY.jsonl has no case or no query file, when a query file has no
case, and when a folder under tests/ has no pack or no grammar. The
tool skips each file and folder whose name starts with a dot.

  -s SINTER  the sinter command
  -u         write each file CASE.QUERY.jsonl from the output of the
             command, then check the other rules. A person must read
             each file that changed, line by line, before it is
             committed.

Exit codes: 0 when every check passes, 1 when a check fails, 2 when the
command line is wrong, 3 when a command that the tool needs is missing.
USAGE
}

sinter=
update=0
while getopts hs:u option; do
  case $option in
    h) usage; exit 0 ;;
    s) sinter=$OPTARG ;;
    u) update=1 ;;
    *) usage_error "the option is not known" ;;
  esac
done
shift $((OPTIND - 1))
[ -n "$sinter" ] || usage_error "give the sinter command with -s"
[ "$#" -le 1 ] || usage_error "give at most one repository"
repository=${1:-$(repository_root)}
[ -d "$repository" ] || usage_error "$repository is not a folder"
case $sinter in
  */*)
    sinter_dir=$(CDPATH='' cd -- "$(dirname -- "$sinter")" 2>/dev/null && pwd) || fatal "$sinter is not a command"
    sinter=$sinter_dir/${sinter##*/}
    ;;
esac
[ -x "$sinter" ] || command -v "$sinter" >/dev/null 2>&1 || fatal "$sinter is not a command"
make_temp_dir
cd -- "$repository"

entries() {
  if [ -d "$1" ]; then
    find "$1/." ! -name . -prune ! -name '.*' -print | sed 's|^.*/||' | sort
  fi
}

matched=0
entries packs >"$temp_dir/packs"
while IFS= read -r pack; do
  entries "packs/$pack/queries" >"$temp_dir/grammars"
  while IFS= read -r grammar; do
    folder=tests/$pack/$grammar
    for query in "packs/$pack/queries/$grammar"/*.scm; do
      [ -f "$query" ] || continue
      found=0
      if [ -d "$folder" ]; then
        found=$(find "$folder/." ! -name . -prune -type f ! -name '.*' ! -name '*.jsonl' -print | wc -l | tr -d ' ')
      fi
      if [ "$found" -eq 0 ]; then
        problem "$query has no case under $folder/"
      fi
    done
  done <"$temp_dir/grammars"
done <"$temp_dir/packs"

check_case() {
  file=$1
  grammar_file=$2
  queries=$3
  case_name=${file%.*}
  for query in "$queries"/*.scm; do
    [ -f "$query" ] || continue
    query_name=${query##*/}
    query_name=${query_name%.scm}
    expected=$case_name.$query_name.jsonl
    if ! "$sinter" parse --grammar "$grammar_file" --query "$query" "$file" \
      </dev/null >"$temp_dir/actual" 2>"$temp_dir/error"; then
      problem "$file, query $query_name: sinter parse fails: $(head -n 1 "$temp_dir/error")"
      continue
    fi
    if [ "$update" -eq 1 ]; then
      if [ ! -f "$expected" ] || ! cmp -s "$temp_dir/actual" "$expected"; then
        cp "$temp_dir/actual" "$expected"
        printf 'Wrote %s. Read it line by line.\n' "$expected"
      fi
      matched=$((matched + 1))
    elif [ ! -f "$expected" ]; then
      problem "$file, query $query_name: the case has no expected file $expected"
    elif ! cmp -s "$temp_dir/actual" "$expected"; then
      problem "$file, query $query_name: the captures differ from $expected:"
      diff "$expected" "$temp_dir/actual" | grep '^[<>]' | sed 's/^/  /' || true
    else
      matched=$((matched + 1))
    fi
  done
}

entries tests >"$temp_dir/test-packs"
while IFS= read -r pack; do
  if [ ! -d "tests/$pack" ]; then
    problem "tests/$pack is not a folder"
    continue
  fi
  if [ ! -d "packs/$pack" ]; then
    problem "tests/$pack belongs to no pack"
    continue
  fi
  entries "tests/$pack" >"$temp_dir/test-grammars"
  while IFS= read -r grammar; do
    folder=tests/$pack/$grammar
    grammar_file=packs/$pack/grammars/$grammar.wasm
    queries=packs/$pack/queries/$grammar
    if [ ! -d "$folder" ]; then
      problem "$folder is not a folder"
      continue
    fi
    if [ ! -f "$grammar_file" ]; then
      problem "$folder belongs to no grammar of the pack $pack"
      continue
    fi
    entries "$folder" >"$temp_dir/files"
    grep -v '\.jsonl$' "$temp_dir/files" >"$temp_dir/cases" || true
    sed 's/\.[^.]*$//' "$temp_dir/cases" | sort | uniq -d >"$temp_dir/twice"
    while IFS= read -r name; do
      problem "$folder: two cases have the name $name"
    done <"$temp_dir/twice"
    grep '\.jsonl$' "$temp_dir/files" >"$temp_dir/expected" || true
    while IFS= read -r name; do
      base=${name%.jsonl}
      query_name=${base##*.}
      case_name=${base%.*}
      if [ "$base" = "$query_name" ]; then
        problem "$folder/$name: the name is not CASE.QUERY.jsonl"
        continue
      fi
      if [ ! -f "$queries/$query_name.scm" ]; then
        problem "$folder/$name: the grammar $grammar has no query file $query_name.scm"
      fi
      if ! sed 's/\.[^.]*$//' "$temp_dir/cases" | grep -Fqx -- "$case_name"; then
        problem "$folder/$name: no case has the name $case_name"
      fi
    done <"$temp_dir/expected"
    while IFS= read -r name; do
      if [ ! -f "$folder/$name" ]; then
        problem "$folder/$name is not a file"
        continue
      fi
      check_case "$folder/$name" "$grammar_file" "$queries"
    done <"$temp_dir/cases"
  done <"$temp_dir/test-grammars"
done <"$temp_dir/test-packs"

if [ "$problems" -eq 0 ]; then
  printf 'The query tests pass. Expected files that match: %s.\n' "$matched"
fi
finish
