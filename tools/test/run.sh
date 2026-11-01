#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 The Sinter Authors

set -eu
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
  GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_NAMESPACE GIT_PREFIX
tools_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
tool=run.sh
. "$(dirname -- "$0")/../lib.sh"

usage() {
  cat <<'USAGE'
Usage: tools/test/run.sh [-s SINTER] [-t CRATE] [-g GRAMMARS] [-u] [NAME...]

Run the tests of the pack checks. Each test builds packs, indexes, and
repositories in a temporary folder. A test that needs an option fails
when the option is not given.

  -s SINTER    the sinter command
  -t CRATE     the folder of the source of the tree-sitter crate that
               SINTER uses
  -g GRAMMARS  a folder that holds the upstream grammars
               tree-sitter-rust.wasm and tree-sitter-typescript.wasm
  -u           also run the tests that call GitHub with gh
  NAME         run only the tests whose names, without their prefix
               t_, start with NAME

Exit codes: 0 when every test passes, 1 when a test fails, 2 when the
command line is wrong.
USAGE
}

sinter=
crate=
grammars=
online=0
while getopts hs:t:g:u option; do
  case $option in
    h) usage; exit 0 ;;
    s) sinter=$OPTARG ;;
    t) crate=$OPTARG ;;
    g) grammars=$OPTARG ;;
    u) online=1 ;;
    *) usage_error "the option is not known" ;;
  esac
done
shift $((OPTIND - 1))
rust_wasm=$grammars/tree-sitter-rust.wasm
typescript_wasm=$grammars/tree-sitter-typescript.wasm
make_temp_dir
passed=0
failed=0
number=0

note() {
  printf '    %s\n' "$1" >>"$case_dir/notes"
}

run() {
  expected=$1
  shift
  status=0
  "$@" >"$case_dir/out" 2>&1 </dev/null || status=$?
  if [ "$status" -ne "$expected" ]; then
    note "the command exits with $status, and the test expects $expected: $*"
    sed 's/^/      /' "$case_dir/out" >>"$case_dir/notes"
    return 1
  fi
}

has() {
  if ! grep -Fq -- "$1" "$case_dir/out"; then
    note "the output does not hold: $1"
    sed 's/^/      /' "$case_dir/out" >>"$case_dir/notes"
    return 1
  fi
}

requires() {
  for need in "$@"; do
    case $need in
      sinter) [ -n "$sinter" ] || { note "the test needs the option -s"; return 1; } ;;
      crate) [ -n "$crate" ] || { note "the test needs the option -t"; return 1; } ;;
      grammars)
        if [ -z "$grammars" ] || [ ! -f "$rust_wasm" ] || [ ! -f "$typescript_wasm" ]; then
          note "the test needs the option -g, with a folder that holds the grammars"
          return 1
        fi
        ;;
    esac
  done
}

same() {
  if [ "$1" != "$2" ]; then
    note "the value is \"$1\", and the test expects \"$2\""
    return 1
  fi
}

test_case() {
  if [ -n "$selection" ]; then
    selected=0
    for prefix in $selection; do
      case ${1#t_} in "$prefix"*) selected=1 ;; esac
    done
    [ "$selected" -eq 1 ] || return 0
  fi
  number=$((number + 1))
  case_dir="$temp_dir/case $number"
  mkdir -p "$case_dir"
  : >"$case_dir/notes"
  set +e
  (
    set -e
    cd "$case_dir"
    "$1"
  )
  status=$?
  set -e
  if [ "$status" -eq 0 ]; then
    passed=$((passed + 1))
    printf 'ok   %s\n' "$1"
  else
    failed=$((failed + 1))
    printf 'FAIL %s\n' "$1"
    cat "$case_dir/notes"
  fi
}

replace_line() {
  awk -v from="$2" -v to="$3" '{ if (index($0, from) == 1) print to; else print }' "$1" >"$1.new"
  mv "$1.new" "$1"
}

t_hash_matches_the_command_of_the_specification() {
  mkdir -p pack/queries/x pack/grammars
  printf 'a' >pack/pack.toml
  printf 'b' >pack/queries/x/tags.scm
  printf 'c' >pack/grammars/x.wasm
  printf 'd' >pack/.hidden
  printf 'e' >pack/Upper
  printf 'f' >pack/a-b.c
  run 0 "$tools_dir/pack-hash.sh" pack
  if command -v sha256sum >/dev/null 2>&1; then
    expected=$(cd pack && find . -type f | sed 's|^\./||' | LC_ALL=C sort | xargs sha256sum | sha256sum | awk '{ print $1 }')
  else
    expected=$(cd pack && find . -type f | sed 's|^\./||' | LC_ALL=C sort | xargs shasum -a 256 | shasum -a 256 | awk '{ print $1 }')
  fi
  same "$(cat "$case_dir/out")" "$expected"
}

t_hash_reads_paths_with_spaces() {
  mkdir -p "pack/a b"
  printf 'a' >"pack/a b/c d"
  printf 'b' >"pack/pack.toml"
  run 0 "$tools_dir/pack-hash.sh" pack
  same "$(cat "$case_dir/out")" 71fa9bf1cb1159a8c8c9c23c7dc6a575de6c681db0decdff17f767afeddf39c6
}

t_hash_refuses_a_link() {
  mkdir pack
  printf 'a' >pack/pack.toml
  ln -s pack.toml pack/link
  run 1 "$tools_dir/pack-hash.sh" pack
  has "the pack holds an entry that is not a file or a folder: link"
}

t_hash_refuses_a_backslash() {
  mkdir pack
  printf 'a' >'pack/a\b'
  run 1 "$tools_dir/pack-hash.sh" pack
  has "with a backslash"
}

t_hash_refuses_a_line_feed() {
  mkdir pack
  printf 'a' >"pack/a
b"
  run 1 "$tools_dir/pack-hash.sh" pack
  has "a character outside printable ASCII"
}

descriptor() {
  awk -f "$tools_dir/descriptor.awk" <pack.toml
}

descriptor_errors() {
  awk -f "$tools_dir/descriptor.awk" <pack.toml >/dev/null
}

t_descriptor_reads_the_example_of_the_specification() {
  cat >pack.toml <<'TOML'
sinter-spec = "1.0"
name = "typescript"
version = "1.0.0"
license = 'Apache-2.0'
name-separator = "."
foreign-tags = ["param", "returns"]

[comments]
line = ["//"]
block = [["/*", "*/"], ["/**", "*/"]]
inner = ["*"] # a comment

[[grammar]]
name = "typescript"
sha256 = "778025db5a8be0e70f8ccc3671e486dfeddd048c25d9e8a70c26de2e1bf6f97d"
license = "MIT"
names = [
  "*.ts",
  "*.mts",  # a comment
]

[[grammar]]
name = "tsx"
sha256 = "79e5da75ea62855a0cd67177685f0164eac87d5f630b3cbe1e0a099751ad30f8"
license = "MIT"
names = ["*.tsx"]

[runner.vitest.match]
path = ["name"]
rewrite = [["\\", "/"]]
line-base = 0
suite-match = false

[runner.vitest.settings]
recognise = ["testsuites@name=vitest tests"]

[runner.nextest.adapter]
sha256 = "0000000000000000000000000000000000000000000000000000000000000000"
license = "Apache-2.0"
TOML
  run 0 descriptor
  same "$(cat "$case_dir/out")" "$(printf '%s\n' \
    'sinter-spec	1.0' 'name	typescript' 'version	1.0.0' 'license	Apache-2.0' \
    'name-separator	.' 'grammar[0].name	typescript' \
    'grammar[0].sha256	778025db5a8be0e70f8ccc3671e486dfeddd048c25d9e8a70c26de2e1bf6f97d' \
    'grammar[0].license	MIT' 'grammar[1].name	tsx' \
    'grammar[1].sha256	79e5da75ea62855a0cd67177685f0164eac87d5f630b3cbe1e0a099751ad30f8' \
    'grammar[1].license	MIT' \
    'runner.nextest.adapter.sha256	0000000000000000000000000000000000000000000000000000000000000000' \
    'runner.nextest.adapter.license	Apache-2.0')"
}

refusal() {
  printf '%s' "$1" >pack.toml
  run 1 descriptor_errors
  same "$(cat "$case_dir/out")" "$2"
}

t_descriptor_refuses_a_dotted_key() {
  refusal 'name = "x"
[runner.nextest]
adapter.sha256 = "0"
' "line 3: a dotted key"
}

t_descriptor_refuses_an_unknown_table_header() {
  refusal 'name = "x"

[grammars]
name = "y"
' "line 3: the table header grammars is not one that the descriptor has"
}

t_descriptor_refuses_an_unknown_array_of_tables() {
  refusal '[[runner]]
' "line 1: the table header runner is not one that the descriptor has"
}

t_descriptor_refuses_an_unknown_part_of_a_runner() {
  refusal '[runner.vitest.other]
' "line 1: the table header runner.vitest.other is not one that the descriptor has"
}

t_descriptor_refuses_a_key_written_twice() {
  refusal 'name = "x"
version = "1.0.0"
name = "y"
' "line 3: the key name is written twice"
}

t_descriptor_refuses_a_table_written_twice() {
  refusal '[comments]
line = ["#"]
[comments]
' "line 3: the table comments is written twice"
}

t_descriptor_refuses_a_multi_line_basic_string() {
  refusal 'name = """x"""
' "line 1: a multi-line string"
}

t_descriptor_refuses_a_multi_line_literal_string() {
  refusal "name = '''x'''
" "line 1: a multi-line string"
}

t_descriptor_refuses_an_escape_in_a_value_that_the_checks_read() {
  refusal 'version = "1.0.0"

[[grammar]]
name = "a\u0062"
' "line 4: an escape in the value of name"
}

t_descriptor_takes_an_escape_in_a_value_that_the_checks_do_not_read() {
  printf 'name = "x"\nname-separator = "\\t"\n' >pack.toml
  run 0 descriptor
  same "$(cat "$case_dir/out")" "name	x"
}

t_descriptor_refuses_a_value_on_the_next_line() {
  refusal 'name =
"x"
' "line 1: the value of name is not on the line of its key"
}

t_descriptor_refuses_an_inline_table() {
  refusal 'name = "x"
other = {}
' "line 2: an inline table"
}

t_descriptor_refuses_a_float() {
  refusal 'level = 1.5
' "line 1: a value that is not in the plain form"
}

t_descriptor_refuses_a_date() {
  refusal 'day = 2026-11-01
' "line 1: a value that is not in the plain form"
}

t_descriptor_refuses_a_quoted_key() {
  refusal '"name" = "x"
' "line 1: a quoted key"
}

t_descriptor_refuses_a_carriage_return() {
  refusal "$(printf 'name = "x"\r\n')" "line 1: a carriage return"
}

t_descriptor_refuses_a_string_that_does_not_end() {
  refusal 'name = "x
' "line 1: a string that does not end on its line"
}

t_descriptor_refuses_an_array_that_does_not_end() {
  refusal 'names = ["a",
' "line 2: an array that does not end"
}

t_descriptor_refuses_text_after_a_value() {
  refusal 'name = "x" "y"
' "line 1: the line holds more text after its value"
}

t_descriptor_refuses_a_key_on_the_line_of_a_header() {
  refusal '[comments] line = ["#"]
' "line 1: the line holds more text after its value"
}

t_tools_print_their_usage() {
  for script in "$tools_dir"/*.sh; do
    name=${script##*/}
    [ "$name" != lib.sh ] || continue
    run 0 "$script" -h
    has "Usage: tools/$name"
  done
}

t_tools_refuse_a_wrong_command_line() {
  for script in "$tools_dir"/*.sh; do
    name=${script##*/}
    [ "$name" != lib.sh ] || continue
    run 2 "$script" -x -y
    has "Run $name -h for the usage."
  done
}

selection="$*"
tests=$(grep -E '^t_[a-z0-9_]+\(\) \{$' "$0" | sed 's/().*//')
for name in $tests; do
  case $name in
    t_online_*) [ "$online" -eq 1 ] || continue ;;
  esac
  test_case "$name"
done
printf '%s passed, %s failed.\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
