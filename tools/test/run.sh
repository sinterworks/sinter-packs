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

count_bytes() {
  printf '%s\n' "$1" | awk '{ count += NF } END { printf "%d", count }'
}

leb_bytes() {
  value=$1
  out=
  while :; do
    low=$((value % 128))
    value=$((value / 128))
    if [ "$value" -eq 0 ]; then
      out="$out $low"
      break
    fi
    out="$out $((low + 128))"
  done
  printf '%s' "$out"
}

string_bytes() {
  printf '%s' "$(leb_bytes "${#1}") $(printf '%s' "$1" | od -An -v -tu1 | tr -s ' \n' '  ')"
}

section_bytes() {
  printf '%s' "$1 $(leb_bytes "$(count_bytes "$2")") $2"
}

write_bytes() {
  escapes=$(printf '%s\n' "$1" | awk '{ for (i = 1; i <= NF; i++) printf "\\0%o", $i }')
  printf '%b' "$escapes"
}

grammar_module() {
  name=$1
  abi=$2
  imports=$3
  features=$4
  export_name=${5:-tree_sitter_$name}
  types="96 0 1 127"
  import_list="$(string_bytes env) $(string_bytes __memory_base) 3 127 0"
  import_count=1
  for import in $imports; do
    import_list="$import_list $(string_bytes env) $(string_bytes "$import") 0 0"
    import_count=$((import_count + 1))
  done
  import_list="$import_list $(string_bytes env) $(string_bytes memory) 2 0 1"
  import_count=$((import_count + 1))
  function_imports=$((import_count - 2))
  module="0 97 115 109 1 0 0 0"
  module="$module $(section_bytes 1 "1 $types")"
  module="$module $(section_bytes 2 "$(leb_bytes "$import_count") $import_list")"
  module="$module $(section_bytes 3 "1 0")"
  module="$module $(section_bytes 7 "1 $(string_bytes "$export_name") 0 $(leb_bytes "$function_imports")")"
  body="0 35 0 65 16 106 11"
  module="$module $(section_bytes 10 "1 $(leb_bytes "$(count_bytes "$body")") $body")"
  data="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 $((abi % 256)) $((abi / 256 % 256)) 0 0"
  module="$module $(section_bytes 11 "1 0 35 0 11 $(leb_bytes "$(count_bytes "$data")") $data")"
  if [ -n "$features" ]; then
    list=
    feature_count=0
    for feature in $features; do
      list="$list 43 $(string_bytes "$feature")"
      feature_count=$((feature_count + 1))
    done
    module="$module $(section_bytes 0 "$(string_bytes target_features) $(leb_bytes "$feature_count") $list")"
  fi
  printf '%s' "$module"
}

stdlib_module() {
  list=
  feature_count=0
  for feature in $1; do
    list="$list 43 $(string_bytes "$feature")"
    feature_count=$((feature_count + 1))
  done
  printf '%s' "0 97 115 109 1 0 0 0 $(section_bytes 0 "$(string_bytes target_features) $(leb_bytes "$feature_count") $list")"
}

hex_array() {
  printf '%s\n' "$1" | awk '
    BEGIN { print "unsigned char STDLIB_WASM[] = {" }
    { for (i = 1; i <= NF; i++) { printf "  0x%02x,\n", $i; count++ } }
    END { print "};"; print "unsigned int STDLIB_WASM_LEN = " count ";" }
  '
}

make_crate() {
  crate=$1
  mkdir -p "$crate/src/wasm" "$crate/include/tree_sitter"
  printf '[package]\nname = "tree-sitter"\nversion = "9.8.7"\n\n[dependencies]\nversion = "1"\n' >"$crate/Cargo.toml"
  cat >"$crate/src/wasm_store.c" <<'C'
#include "./wasm/wasm-stdlib.h"

const char *STDLIB_SYMBOLS[] = {
  #include "./stdlib-symbols.txt"
};

static bool ts_wasm_store__provide_builtin_import(
  TSWasmStore *self,
  const wasm_name_t *import_name,
  wasmtime_extern_t *import
) {
  if (name_eq(import_name, "__memory_base")) {
  } else if (name_eq(import_name, "memory")) {
  } else if (name_eq(import_name, "abort")) {
  } else {
    return false;
  }
  return true;
}

static bool other(const wasm_name_t *import_name) {
  return name_eq(import_name, "not_a_builtin");
}
C
  printf '"calloc",\n"free",\n"iswspace",\n' >"$crate/src/wasm/stdlib-symbols.txt"
  hex_array "$(stdlib_module "bulk-memory sign-ext mutable-globals")" >"$crate/src/wasm/wasm-stdlib.h"
  printf '#define TREE_SITTER_LANGUAGE_VERSION 15\n#define TREE_SITTER_MIN_COMPATIBLE_LANGUAGE_VERSION 13\n' \
    >"$crate/include/tree_sitter/api.h"
}

notice_block() {
  printf '\ngrammar: %s\nrepository: %s\ntag: %s\ncommit: %s\nasset: %s\nsha256: %s\n' "$@"
}

make_pack() {
  pack=$1
  name=$2
  grammar=$3
  mkdir -p "$pack/grammars" "$pack/licenses" "$pack/queries/$grammar"
  write_bytes "$(grammar_module "$grammar" 15 "calloc iswspace" "bulk-memory sign-ext")" >"$pack/grammars/$grammar.wasm"
  hash=$(sha256_of "$pack/grammars/$grammar.wasm")
  cat >"$pack/pack.toml" <<TOML
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 The Sinter Authors

sinter-spec = "1.0"
name = "$name"
version = "0.1.0"
license = "Apache-2.0"
name-separator = "::"

[comments]
line = ["//"]
block = [["/*", "*/"]]

[[grammar]]
name = "$grammar"
sha256 = "$hash"
license = "MIT"
names = ["*.x"]
TOML
  cp "$(repository_root)/LICENSES/Apache-2.0.txt" "$pack/licenses/Apache-2.0.txt"
  printf 'MIT License\n\nCopyright (c) 2026 Upstream\n' >"$pack/licenses/tree-sitter-$grammar.LICENSE"
  {
    printf '%s pack of Sinter\nCopyright 2026 The Sinter Authors\n' "$name"
    notice_block "$grammar" "tree-sitter/tree-sitter-$grammar" v1.2.3 \
      0123456789abcdef0123456789abcdef01234567 "tree-sitter-$grammar.wasm" "$hash"
  } >"$pack/licenses/NOTICE"
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

t_limits_reads_a_crate() {
  make_crate crate
  run 0 "$tools_dir/tree-sitter-limits.sh" crate
  same "$(cat "$case_dir/out")" "$(printf '%s\n' 'version	9.8.7' \
    'import	__memory_base' 'import	abort' 'import	calloc' 'import	free' 'import	iswspace' \
    'import	memory' 'feature	bulk-memory' 'feature	mutable-globals' 'feature	sign-ext' \
    'abi	13	15')"
}

t_limits_reads_the_crate_of_sinter() {
  requires crate
  run 0 "$tools_dir/tree-sitter-limits.sh" "$crate"
  has "import	calloc"
  has "import	__memory_base"
  has "feature	mutable-globals"
  grep -q '^abi	[0-9]*	[0-9]*$' "$case_dir/out"
}

t_limits_needs_the_header_of_the_api() {
  make_crate crate
  rm crate/include/tree_sitter/api.h
  run 3 "$tools_dir/tree-sitter-limits.sh" crate
  has "holds no file include/tree_sitter/api.h"
}

t_limits_needs_one_list_of_the_standard_library() {
  make_crate crate
  mkdir crate/src/other
  cp crate/src/wasm/stdlib-symbols.txt crate/src/other/
  run 3 "$tools_dir/tree-sitter-limits.sh" crate
  has "does not hold exactly one file stdlib-symbols.txt"
}

t_limits_needs_a_list_of_names() {
  make_crate crate
  printf '"calloc",\nint x;\n' >crate/src/wasm/stdlib-symbols.txt
  run 3 "$tools_dir/tree-sitter-limits.sh" crate
  has "is not a list of names"
}

t_limits_needs_the_range_of_abi_versions() {
  make_crate crate
  printf '#define TREE_SITTER_LANGUAGE_VERSION 15\n' >crate/include/tree_sitter/api.h
  run 3 "$tools_dir/tree-sitter-limits.sh" crate
  has "does not define the range of ABI versions"
}

grammar_case() {
  make_crate crate
  make_pack "my pack" demo demo
  if [ "$#" -gt 0 ]; then
    write_bytes "$(grammar_module demo "$@")" >"my pack/grammars/demo.wasm"
    hash=$(sha256_of "my pack/grammars/demo.wasm")
    replace_line "my pack/pack.toml" "sha256 = " "sha256 = \"$hash\""
  fi
}

t_grammars_pass() {
  grammar_case
  run 0 "$tools_dir/check-grammars.sh" -t crate "my pack"
  has "my pack: the grammar demo passes: ABI version 15, 4 imports, 2 features."
}

t_grammars_find_a_wrong_sha256() {
  grammar_case
  printf 'x' >>"my pack/grammars/demo.wasm"
  run 1 "$tools_dir/check-grammars.sh" -t crate "my pack"
  has "my pack: the grammar demo has the SHA-256 "
  has ", and the descriptor gives "
}

t_grammars_find_an_import_that_tree_sitter_does_not_give() {
  grammar_case 15 "calloc iswpunct" "sign-ext"
  run 1 "$tools_dir/check-grammars.sh" -t crate "my pack"
  has "my pack: the grammar demo imports iswpunct, which tree-sitter 9.8.7 does not give a grammar"
}

t_grammars_find_a_feature_outside_the_standard_library() {
  grammar_case 15 "calloc" "sign-ext simd128"
  run 1 "$tools_dir/check-grammars.sh" -t crate "my pack"
  has "my pack: the grammar demo uses the WebAssembly feature simd128, which the standard library of tree-sitter 9.8.7 does not use"
}

t_grammars_pass_a_grammar_with_no_features_and_say_so() {
  grammar_case 14 "calloc" ""
  run 0 "$tools_dir/check-grammars.sh" -t crate "my pack"
  has "my pack: the grammar demo has no target_features section, so only its load checks its WebAssembly features."
  has "my pack: the grammar demo passes: ABI version 14, 3 imports, 0 features."
}

t_grammars_find_an_abi_version_below_the_range() {
  grammar_case 12 "calloc" "sign-ext"
  run 1 "$tools_dir/check-grammars.sh" -t crate "my pack"
  has "my pack: the grammar demo has the ABI version 12, and tree-sitter 9.8.7 loads the versions 13 to 15"
}

t_grammars_find_an_abi_version_above_the_range() {
  grammar_case 16 "calloc" "sign-ext"
  run 1 "$tools_dir/check-grammars.sh" -t crate "my pack"
  has "has the ABI version 16, and tree-sitter 9.8.7 loads the versions 13 to 15"
}

t_grammars_find_a_grammar_without_its_function() {
  grammar_case 15 "calloc" "sign-ext" tree_sitter_other
  run 1 "$tools_dir/check-grammars.sh" -t crate "my pack"
  has "my pack: the grammar demo cannot be read: the module exports no function tree_sitter_demo"
}

t_grammars_find_a_module_that_is_cut_short() {
  grammar_case
  head -c 40 "my pack/grammars/demo.wasm" >short.wasm
  mv short.wasm "my pack/grammars/demo.wasm"
  replace_line "my pack/pack.toml" "sha256 = " "sha256 = \"$(sha256_of "my pack/grammars/demo.wasm")\""
  run 1 "$tools_dir/check-grammars.sh" -t crate "my pack"
  has "my pack: the grammar demo cannot be read: the module is cut short"
}

t_grammars_find_a_file_that_is_not_webassembly() {
  grammar_case
  printf 'not a module' >"my pack/grammars/demo.wasm"
  replace_line "my pack/pack.toml" "sha256 = " "sha256 = \"$(sha256_of "my pack/grammars/demo.wasm")\""
  run 1 "$tools_dir/check-grammars.sh" -t crate "my pack"
  has "my pack: the grammar demo cannot be read: the file is not a WebAssembly module"
}

t_grammars_find_a_missing_file() {
  grammar_case
  rm "my pack/grammars/demo.wasm"
  run 1 "$tools_dir/check-grammars.sh" -t crate "my pack"
  has "my pack: the grammar demo has no file grammars/demo.wasm"
}

t_grammars_find_a_grammar_named_twice() {
  grammar_case
  printf '\n[[grammar]]\nname = "demo"\n' >>"my pack/pack.toml"
  run 1 "$tools_dir/check-grammars.sh" -t crate "my pack"
  has "my pack: the descriptor names the grammar demo twice"
}

t_grammars_find_a_descriptor_that_cannot_be_read() {
  grammar_case
  printf 'level = 1.5\n' >>"my pack/pack.toml"
  run 1 "$tools_dir/check-grammars.sh" -t crate "my pack"
  has "my pack: the descriptor cannot be read: line 19: a value that is not in the plain form"
}

t_grammars_pass_the_upstream_grammars() {
  requires crate grammars
  mkdir -p rust/grammars typescript/grammars
  cp "$rust_wasm" rust/grammars/rust.wasm
  cp "$typescript_wasm" typescript/grammars/typescript.wasm
  printf 'name = "rust"\n\n[[grammar]]\nname = "rust"\nsha256 = "%s"\n' "$(sha256_of "$rust_wasm")" >rust/pack.toml
  printf 'name = "typescript"\n\n[[grammar]]\nname = "typescript"\nsha256 = "%s"\n' "$(sha256_of "$typescript_wasm")" >typescript/pack.toml
  run 0 "$tools_dir/check-grammars.sh" -t "$crate" rust typescript
  has "rust: the grammar rust passes: ABI version 15,"
  has "typescript: the grammar typescript has no target_features section"
  has "typescript: the grammar typescript passes: ABI version 14,"
}

query_case() {
  requires sinter grammars
  make_pack "my pack" rust rust
  cp "$rust_wasm" "my pack/grammars/rust.wasm"
}

t_queries_pass_a_query_that_compiles() {
  query_case
  printf '(line_comment) @comment\n(block_comment) @comment\n' >"my pack/queries/rust/tags.scm"
  run 0 "$tools_dir/check-queries.sh" -s "$sinter" "my pack"
  has "my pack: queries/rust/tags.scm compiles."
}

t_queries_find_a_query_that_does_not_compile() {
  query_case
  printf '(line_comment) @comment\n' >"my pack/queries/rust/tags.scm"
  printf '(no_such_node) @definition\n' >"my pack/queries/rust/definitions.scm"
  run 1 "$tools_dir/check-queries.sh" -s "$sinter" "my pack"
  has "my pack: queries/rust/tags.scm compiles."
  has "my pack: queries/rust/definitions.scm does not compile: "
  has "no_such_node"
}

t_queries_find_a_directive() {
  query_case
  printf '((line_comment) @comment (#set! kind "x"))\n' >"my pack/queries/rust/tags.scm"
  run 1 "$tools_dir/check-queries.sh" -s "$sinter" "my pack"
  has "my pack: queries/rust/tags.scm does not compile: "
}

t_queries_find_a_folder_of_no_grammar() {
  query_case
  printf '(line_comment) @comment\n' >"my pack/queries/rust/tags.scm"
  mkdir "my pack/queries/other"
  run 1 "$tools_dir/check-queries.sh" -s "$sinter" "my pack"
  has "my pack: queries/other belongs to no grammar of the descriptor"
}

t_queries_find_a_missing_grammar() {
  query_case
  rm "my pack/grammars/rust.wasm"
  run 1 "$tools_dir/check-queries.sh" -s "$sinter" "my pack"
  has "my pack: the grammar rust has no file grammars/rust.wasm"
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
