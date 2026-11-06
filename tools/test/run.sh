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

commit_all() {
  git -C "$1" add -A
  git -C "$1" -c user.name=test -c user.email=test@example.com -c commit.gpgsign=false \
    commit -q -m "$2"
}

index_line() {
  printf '{"hash":"%s","name":"%s","url":"https://github.com/sinterworks/sinter-packs/releases/download/%s-v%s/%s-%s.tar.gz","v":1,"version":"%s"}\n' \
    "$3" "$1" "$1" "$2" "$1" "$2" "$2"
}

set_version() {
  sed "s/^version = \".*\"\$/version = \"$2\"/" "$1/pack.toml" >"$1/pack.toml.new"
  mv "$1/pack.toml.new" "$1/pack.toml"
}

make_repository() {
  mkdir -p repo/packs
  make_pack repo/packs/demo demo demo
  index_line demo 0.1.0 "$(pack_hash repo/packs/demo)" >repo/index.jsonl
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

query_test_case() {
  requires sinter grammars
  mkdir -p "my repo/packs" "my repo/tests/rust/rust"
  make_pack "my repo/packs/rust" rust rust
  cp "$rust_wasm" "my repo/packs/rust/grammars/rust.wasm"
  printf '(line_comment) @comment\n' >"my repo/packs/rust/queries/rust/tags.scm"
  printf '// a\nfn f() {}\n' >"my repo/tests/rust/rust/a b.rs"
  (
    cd "my repo"
    "$sinter" parse --grammar packs/rust/grammars/rust.wasm --query packs/rust/queries/rust/tags.scm \
      "tests/rust/rust/a b.rs" >"tests/rust/rust/a b.tags.jsonl"
  )
}

t_query_tests_pass() {
  query_test_case
  run 0 "$tools_dir/check-query-tests.sh" -s "$sinter" "my repo"
  has "The query tests pass. Expected files that match: 1."
  same "$(jq -r .path "my repo/tests/rust/rust/a b.tags.jsonl")" "tests/rust/rust/a b.rs"
}

t_query_tests_pass_with_no_packs() {
  requires sinter
  mkdir "my repo"
  run 0 "$tools_dir/check-query-tests.sh" -s "$sinter" "my repo"
  has "The query tests pass. Expected files that match: 0."
}

t_query_tests_find_other_captures() {
  query_test_case
  printf '// b\nfn f() {}\n' >"my repo/tests/rust/rust/a b.rs"
  run 1 "$tools_dir/check-query-tests.sh" -s "$sinter" "my repo"
  has "tests/rust/rust/a b.rs, query tags: the captures differ from tests/rust/rust/a b.tags.jsonl:"
  has '  < {"cap":"comment"'
  has '"text":"// a"}'
  has '  > {"cap":"comment"'
  has '"text":"// b"}'
}

t_query_tests_find_a_change_of_one_byte_at_the_end() {
  query_test_case
  printf '\n' >>"my repo/tests/rust/rust/a b.tags.jsonl"
  run 1 "$tools_dir/check-query-tests.sh" -s "$sinter" "my repo"
  has "the captures differ from tests/rust/rust/a b.tags.jsonl"
}

t_query_tests_find_a_command_that_fails() {
  query_test_case
  printf '\377' >"my repo/tests/rust/rust/a b.rs"
  run 1 "$tools_dir/check-query-tests.sh" -s "$sinter" "my repo"
  has "tests/rust/rust/a b.rs, query tags: sinter parse fails: "
}

t_query_tests_find_a_case_with_no_expected_file() {
  query_test_case
  printf '(function_item) @definition\n' >"my repo/packs/rust/queries/rust/definitions.scm"
  run 1 "$tools_dir/check-query-tests.sh" -s "$sinter" "my repo"
  has "tests/rust/rust/a b.rs, query definitions: the case has no expected file tests/rust/rust/a b.definitions.jsonl"
}

t_query_tests_find_an_expected_file_with_no_case() {
  query_test_case
  : >"my repo/tests/rust/rust/c.tags.jsonl"
  run 1 "$tools_dir/check-query-tests.sh" -s "$sinter" "my repo"
  has "tests/rust/rust/c.tags.jsonl: no case has the name c"
}

t_query_tests_find_an_expected_file_of_no_query() {
  query_test_case
  : >"my repo/tests/rust/rust/a b.tests.jsonl"
  run 1 "$tools_dir/check-query-tests.sh" -s "$sinter" "my repo"
  has "tests/rust/rust/a b.tests.jsonl: the grammar rust has no query file tests.scm"
}

t_query_tests_find_an_expected_file_with_a_wrong_name() {
  query_test_case
  : >"my repo/tests/rust/rust/tags.jsonl"
  run 1 "$tools_dir/check-query-tests.sh" -s "$sinter" "my repo"
  has "tests/rust/rust/tags.jsonl: the name is not CASE.QUERY.jsonl"
}

t_query_tests_find_a_query_file_with_no_case() {
  query_test_case
  rm "my repo/tests/rust/rust/a b.rs" "my repo/tests/rust/rust/a b.tags.jsonl"
  run 1 "$tools_dir/check-query-tests.sh" -s "$sinter" "my repo"
  has "packs/rust/queries/rust/tags.scm has no case under tests/rust/rust/"
}

t_query_tests_find_a_query_file_with_no_folder_of_cases() {
  query_test_case
  rm -r "my repo/tests"
  run 1 "$tools_dir/check-query-tests.sh" -s "$sinter" "my repo"
  has "packs/rust/queries/rust/tags.scm has no case under tests/rust/rust/"
}

t_query_tests_find_a_query_file_with_only_a_hidden_case() {
  query_test_case
  rm "my repo/tests/rust/rust/a b.rs" "my repo/tests/rust/rust/a b.tags.jsonl"
  : >"my repo/tests/rust/rust/.hidden.rs"
  run 1 "$tools_dir/check-query-tests.sh" -s "$sinter" "my repo"
  has "packs/rust/queries/rust/tags.scm has no case under tests/rust/rust/"
}

t_query_tests_find_two_cases_of_one_name() {
  query_test_case
  cp "my repo/tests/rust/rust/a b.rs" "my repo/tests/rust/rust/a b.txt"
  run 1 "$tools_dir/check-query-tests.sh" -s "$sinter" "my repo"
  has "tests/rust/rust: two cases have the name a b"
}

t_query_tests_find_a_folder_of_no_pack() {
  query_test_case
  mkdir -p "my repo/tests/other/rust"
  run 1 "$tools_dir/check-query-tests.sh" -s "$sinter" "my repo"
  has "tests/other belongs to no pack"
}

t_query_tests_find_a_folder_of_no_grammar() {
  query_test_case
  mkdir -p "my repo/tests/rust/other"
  run 1 "$tools_dir/check-query-tests.sh" -s "$sinter" "my repo"
  has "tests/rust/other belongs to no grammar of the pack rust"
}

t_query_tests_find_a_file_in_place_of_the_folder_of_a_pack() {
  query_test_case
  : >"my repo/tests/other"
  run 1 "$tools_dir/check-query-tests.sh" -s "$sinter" "my repo"
  has "tests/other is not a folder"
}

t_query_tests_find_a_file_in_place_of_a_folder() {
  query_test_case
  : >"my repo/tests/rust/notes"
  run 1 "$tools_dir/check-query-tests.sh" -s "$sinter" "my repo"
  has "tests/rust/notes is not a folder"
}

t_query_tests_find_a_folder_in_place_of_a_case() {
  query_test_case
  mkdir "my repo/tests/rust/rust/sub"
  run 1 "$tools_dir/check-query-tests.sh" -s "$sinter" "my repo"
  has "tests/rust/rust/sub is not a file"
}

t_query_tests_update_writes_the_expected_files() {
  query_test_case
  printf '(function_item) @definition\n' >"my repo/packs/rust/queries/rust/definitions.scm"
  printf '// b\nfn f() {}\n' >"my repo/tests/rust/rust/a b.rs"
  run 0 "$tools_dir/check-query-tests.sh" -u -s "$sinter" "my repo"
  has "Wrote tests/rust/rust/a b.tags.jsonl. Read it line by line."
  has "Wrote tests/rust/rust/a b.definitions.jsonl. Read it line by line."
  same "$(jq -r .text "my repo/tests/rust/rust/a b.tags.jsonl")" "// b"
  run 0 "$tools_dir/check-query-tests.sh" -s "$sinter" "my repo"
  has "The query tests pass. Expected files that match: 2."
}

t_query_tests_update_writes_no_unchanged_file() {
  query_test_case
  run 0 "$tools_dir/check-query-tests.sh" -u -s "$sinter" "my repo"
  has "The query tests pass. Expected files that match: 1."
  if grep -q Wrote "$case_dir/out"; then
    note "the tool wrote a file that did not change"
    return 1
  fi
}

t_query_tests_update_still_finds_an_expected_file_with_no_case() {
  query_test_case
  : >"my repo/tests/rust/rust/c.tags.jsonl"
  run 1 "$tools_dir/check-query-tests.sh" -u -s "$sinter" "my repo"
  has "tests/rust/rust/c.tags.jsonl: no case has the name c"
}

t_query_tests_take_a_relative_sinter() {
  query_test_case
  mkdir bin
  cp "$sinter" bin/sinter
  run 0 "$tools_dir/check-query-tests.sh" -s bin/sinter "my repo"
  has "The query tests pass. Expected files that match: 1."
}

t_query_tests_skip_names_that_start_with_a_dot() {
  query_test_case
  : >"my repo/tests/.hidden"
  : >"my repo/tests/rust/rust/.hidden"
  : >"my repo/tests/rust/rust/.tags.jsonl"
  mkdir "my repo/tests/rust/.hidden"
  run 0 "$tools_dir/check-query-tests.sh" -s "$sinter" "my repo"
  has "The query tests pass. Expected files that match: 1."
}

t_query_tests_find_a_command_that_is_not_on_the_path() {
  run 3 "$tools_dir/check-query-tests.sh" -s no-such-sinter
  has "no-such-sinter is not a command"
}

t_query_tests_need_one_repository() {
  mkdir a b
  run 2 "$tools_dir/check-query-tests.sh" -s sinter a b
  has "give at most one repository"
}

t_query_tests_need_a_folder() {
  : >file
  run 2 "$tools_dir/check-query-tests.sh" -s sinter file
  has "file is not a folder"
}

t_query_tests_need_a_sinter_command() {
  run 3 "$tools_dir/check-query-tests.sh" -s no/such/sinter
  has "no/such/sinter is not a command"
}

t_query_tests_need_the_sinter_option() {
  run 2 "$tools_dir/check-query-tests.sh"
  has "give the sinter command with -s"
}

license_case() {
  make_pack "my pack" demo demo
}

license_value() {
  license_case
  replace_line "my pack/pack.toml" 'license = "MIT"' "license = \"$1\""
}

t_licenses_pass() {
  license_case
  run 0 "$tools_dir/check-licenses.sh" "my pack"
  has "my pack: the licenses pass."
}

t_licenses_pass_an_expression_with_and_or_and_brackets() {
  license_value "(MIT OR ISC) AND 0BSD"
  run 0 "$tools_dir/check-licenses.sh" "my pack"
}

t_licenses_find_a_top_level_license_that_is_not_apache() {
  license_case
  replace_line "my pack/pack.toml" 'license = "Apache-2.0"' 'license = "MIT"'
  run 1 "$tools_dir/check-licenses.sh" "my pack"
  has "my pack: the top-level license of the descriptor is \"MIT\", and it must be Apache-2.0"
}

t_licenses_find_a_license_off_the_list() {
  license_value "GPL-3.0-only"
  run 1 "$tools_dir/check-licenses.sh" "my pack"
  has "my pack: the value \"GPL-3.0-only\" of grammar[0].license names the license GPL-3.0-only, which is not on the list of licenses that a pack can use"
}

t_licenses_find_a_license_off_the_list_on_a_side_of_or() {
  license_value "MIT OR GPL-2.0-only"
  run 1 "$tools_dir/check-licenses.sh" "my pack"
  has "names the license GPL-2.0-only"
}

t_licenses_find_an_exception() {
  license_value "Apache-2.0 WITH LLVM-exception"
  run 1 "$tools_dir/check-licenses.sh" "my pack"
  has "names a license exception"
}

t_licenses_find_an_expression_that_is_not_spdx() {
  license_value "MIT AND"
  run 1 "$tools_dir/check-licenses.sh" "my pack"
  has "my pack: the value \"MIT AND\" of grammar[0].license is not an SPDX expression"
}

t_licenses_find_a_bracket_that_does_not_close() {
  license_value "(MIT OR ISC"
  run 1 "$tools_dir/check-licenses.sh" "my pack"
  has "is not an SPDX expression"
}

t_licenses_find_a_license_in_lower_case() {
  license_value "mit"
  run 1 "$tools_dir/check-licenses.sh" "my pack"
  has "names the license mit"
}

t_licenses_find_an_operator_in_lower_case() {
  license_value "MIT and ISC"
  run 1 "$tools_dir/check-licenses.sh" "my pack"
  has "my pack: the value \"MIT and ISC\" of grammar[0].license writes the operator and in lower case, and the tools read only AND"
}

t_licenses_find_a_grammar_with_no_license() {
  license_case
  grep -v '^license = "MIT"$' "my pack/pack.toml" >toml
  mv toml "my pack/pack.toml"
  run 1 "$tools_dir/check-licenses.sh" "my pack"
  has "my pack: the grammar demo has no license in the descriptor"
}

t_licenses_find_a_changed_apache_text() {
  license_case
  printf 'x' >>"my pack/licenses/Apache-2.0.txt"
  run 1 "$tools_dir/check-licenses.sh" "my pack"
  has "my pack: licenses/Apache-2.0.txt is not the text of the Apache-2.0 license of this repository"
}

t_licenses_find_a_missing_apache_text() {
  license_case
  rm "my pack/licenses/Apache-2.0.txt"
  run 1 "$tools_dir/check-licenses.sh" "my pack"
  has "my pack: licenses/Apache-2.0.txt is missing"
}

t_licenses_find_a_file_too_many() {
  license_case
  printf 'x' >"my pack/licenses/other file"
  mkdir "my pack/licenses/folder"
  run 1 "$tools_dir/check-licenses.sh" "my pack"
  has "my pack: licenses/other file is not a file that the folder holds"
  has "my pack: licenses/folder is not a file that the folder holds"
}

t_licenses_find_a_missing_upstream_license() {
  license_case
  rm "my pack/licenses/tree-sitter-demo.LICENSE"
  run 1 "$tools_dir/check-licenses.sh" "my pack"
  has "my pack: licenses/tree-sitter-demo.LICENSE is missing"
}

t_licenses_find_an_empty_upstream_license() {
  license_case
  : >"my pack/licenses/tree-sitter-demo.LICENSE"
  run 1 "$tools_dir/check-licenses.sh" "my pack"
  has "my pack: licenses/tree-sitter-demo.LICENSE is empty"
}

t_licenses_find_a_missing_notice() {
  license_case
  rm "my pack/licenses/NOTICE"
  run 1 "$tools_dir/check-licenses.sh" "my pack"
  has "my pack: licenses/NOTICE is missing"
}

t_licenses_find_a_wrong_first_line_of_the_notice() {
  license_case
  replace_line "my pack/licenses/NOTICE" "demo pack" "demo pack of sinter"
  run 1 "$tools_dir/check-licenses.sh" "my pack"
  has "my pack: licenses/NOTICE is not in its form: line 1: the first line is not \"<name> pack of Sinter\""
}

t_licenses_find_a_notice_of_another_pack() {
  license_case
  replace_line "my pack/licenses/NOTICE" "demo pack" "other pack of Sinter"
  run 1 "$tools_dir/check-licenses.sh" "my pack"
  has "my pack: licenses/NOTICE names the pack other, and the descriptor names it demo"
}

t_licenses_find_a_wrong_copyright_line() {
  license_case
  replace_line "my pack/licenses/NOTICE" "Copyright" "Copyright 2026 Somebody"
  run 1 "$tools_dir/check-licenses.sh" "my pack"
  has "line 2: the second line is not"
}

t_licenses_find_a_block_with_a_missing_line() {
  license_case
  grep -v '^asset: ' "my pack/licenses/NOTICE" >notice
  mv notice "my pack/licenses/NOTICE"
  run 1 "$tools_dir/check-licenses.sh" "my pack"
  has "line 8: the line does not start with asset:"
}

t_licenses_find_a_block_that_is_cut_short() {
  license_case
  grep -v '^sha256: ' "my pack/licenses/NOTICE" >notice
  mv notice "my pack/licenses/NOTICE"
  run 1 "$tools_dir/check-licenses.sh" "my pack"
  has "the last block does not have its six lines"
}

t_licenses_find_a_block_of_a_grammar_built_from_source() {
  license_case
  printf 'tree-sitter-cli: 0.26.13 %s\n' "$(printf '%064d' 0)" >>"my pack/licenses/NOTICE"
  run 1 "$tools_dir/check-licenses.sh" "my pack"
  has "licenses/NOTICE is not in its form"
}

t_licenses_find_a_commit_that_is_not_hex() {
  license_case
  replace_line "my pack/licenses/NOTICE" "commit: " "commit: v1.2.3"
  run 1 "$tools_dir/check-licenses.sh" "my pack"
  has "line 7: the value of commit is not in its form"
}

t_licenses_find_a_tag_with_a_parent_folder() {
  license_case
  replace_line "my pack/licenses/NOTICE" "tag: " "tag: ../v1"
  run 1 "$tools_dir/check-licenses.sh" "my pack"
  has "line 6: the value of tag is not in its form"
}

t_licenses_find_a_wrong_sha256_in_the_notice() {
  license_case
  replace_line "my pack/licenses/NOTICE" "sha256: " "sha256: $(printf '%064d' 0)"
  run 1 "$tools_dir/check-licenses.sh" "my pack"
  has "my pack: licenses/NOTICE gives the grammar demo the sha256 $(printf '%064d' 0), and the descriptor gives "
}

t_licenses_find_a_notice_with_no_line_feed_at_its_end() {
  license_case
  printf '%s' "$(cat "my pack/licenses/NOTICE")" >notice
  mv notice "my pack/licenses/NOTICE"
  run 1 "$tools_dir/check-licenses.sh" "my pack"
  has "my pack: licenses/NOTICE does not end with a line feed"
}

two_grammars() {
  license_case
  cp "my pack/grammars/demo.wasm" "my pack/grammars/second.wasm"
  printf '\n[[grammar]]\nname = "second"\nsha256 = "%s"\nlicense = "MIT"\nnames = ["*.y"]\n' \
    "$(sha256_of "my pack/grammars/second.wasm")" >>"my pack/pack.toml"
}

t_licenses_pass_two_grammars_of_one_repository() {
  two_grammars
  notice_block second tree-sitter/tree-sitter-demo v1.2.3 \
    0123456789abcdef0123456789abcdef01234567 tree-sitter-second.wasm \
    "$(sha256_of "my pack/grammars/second.wasm")" >>"my pack/licenses/NOTICE"
  run 0 "$tools_dir/check-licenses.sh" "my pack"
}

t_licenses_find_blocks_in_another_order() {
  two_grammars
  {
    printf 'demo pack of Sinter\nCopyright 2026 The Sinter Authors\n'
    notice_block second tree-sitter/tree-sitter-demo v1.2.3 \
      0123456789abcdef0123456789abcdef01234567 tree-sitter-second.wasm \
      "$(sha256_of "my pack/grammars/second.wasm")"
    sed -n '3,$p' "my pack/licenses/NOTICE"
  } >notice
  mv notice "my pack/licenses/NOTICE"
  run 1 "$tools_dir/check-licenses.sh" "my pack"
  has "my pack: the blocks of licenses/NOTICE do not name the grammars of the descriptor in their order"
}

t_licenses_find_two_tags_of_one_repository() {
  two_grammars
  notice_block second tree-sitter/tree-sitter-demo v9.9.9 \
    0123456789abcdef0123456789abcdef01234567 tree-sitter-second.wasm \
    "$(sha256_of "my pack/grammars/second.wasm")" >>"my pack/licenses/NOTICE"
  run 1 "$tools_dir/check-licenses.sh" "my pack"
  has "my pack: licenses/NOTICE gives two tags of the repository tree-sitter/tree-sitter-demo"
}

stub_github() {
  pack=$1
  mkdir -p stub/api
  cat >stub/gh <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >>"$STUB_DIR/log"
case $1 in
  api)
    file=$STUB_DIR/api/$(printf '%s' "$2" | tr '/?=' '___')
    if [ ! -f "$file" ]; then
      echo "HTTP 404: Not Found ($2)" >&2
      exit 1
    fi
    cat "$file"
    ;;
  attestation)
    if [ ! -f "$STUB_DIR/attested" ]; then
      echo "Error: verifying with issuer \"sigstore.dev\"" >&2
      exit 1
    fi
    echo "Verification succeeded!"
    ;;
esac
STUB
  chmod +x stub/gh
  printf '{"sha":"0123456789abcdef0123456789abcdef01234567"}\n' \
    >stub/api/repos_tree-sitter_tree-sitter-demo_commits_v1.2.3
  printf '{"assets":[{"name":"other.wasm","digest":null},{"name":"tree-sitter-demo.wasm","digest":"sha256:%s"}]}\n' \
    "$(sha256_of "$pack/grammars/demo.wasm")" >stub/api/repos_tree-sitter_tree-sitter-demo_releases_tags_v1.2.3
  jq -R -s '@base64 | [scan(".{1,60}")] | join("\n") | {content: (. + "\n"), encoding: "base64"}' \
    <"$pack/licenses/tree-sitter-demo.LICENSE" >stub/api/repos_tree-sitter_tree-sitter-demo_license_ref_v1.2.3
  : >stub/attested
  STUB_DIR=$case_dir/stub
  GH=$case_dir/stub/gh
  export STUB_DIR GH
}

upstream_case() {
  make_pack "my pack" demo demo
  stub_github "my pack"
}

t_upstream_pass() {
  upstream_case
  run 0 "$tools_dir/check-upstream.sh" "my pack"
  has "my pack: the upstream releases pass."
  grep -Fxq "attestation verify my pack/grammars/demo.wasm --repo tree-sitter/tree-sitter-demo --signer-workflow tree-sitter/workflows/.github/workflows/release.yml --source-ref refs/tags/v1.2.3 --source-digest 0123456789abcdef0123456789abcdef01234567 --deny-self-hosted-runners" stub/log
}

t_upstream_find_a_tag_of_another_commit() {
  upstream_case
  printf '{"sha":"%s"}\n' "$(printf '%040d' 1)" >stub/api/repos_tree-sitter_tree-sitter-demo_commits_v1.2.3
  run 1 "$tools_dir/check-upstream.sh" "my pack"
  has "my pack: the grammar demo: the tag v1.2.3 of tree-sitter/tree-sitter-demo names the commit $(printf '%040d' 1), and licenses/NOTICE gives 0123456789abcdef0123456789abcdef01234567"
}

t_upstream_find_a_missing_tag() {
  upstream_case
  rm stub/api/repos_tree-sitter_tree-sitter-demo_commits_v1.2.3
  run 1 "$tools_dir/check-upstream.sh" "my pack"
  has "my pack: the grammar demo: GitHub gives no commit for the tag v1.2.3 of tree-sitter/tree-sitter-demo: HTTP 404"
}

t_upstream_find_a_wrong_digest() {
  upstream_case
  printf '{"assets":[{"name":"tree-sitter-demo.wasm","digest":"sha256:%064d"}]}\n' 0 \
    >stub/api/repos_tree-sitter_tree-sitter-demo_releases_tags_v1.2.3
  run 1 "$tools_dir/check-upstream.sh" "my pack"
  has "my pack: the grammar demo has the SHA-256 "
  has ", and GitHub gives the digest $(printf '%064d' 0) for the asset tree-sitter-demo.wasm"
}

t_upstream_pass_an_asset_with_no_digest_and_say_so() {
  upstream_case
  printf '{"assets":[{"name":"tree-sitter-demo.wasm","digest":null}]}\n' \
    >stub/api/repos_tree-sitter_tree-sitter-demo_releases_tags_v1.2.3
  run 0 "$tools_dir/check-upstream.sh" "my pack"
  has "my pack: the grammar demo: GitHub gives no digest for the asset tree-sitter-demo.wasm, so the sha256 of the descriptor is the only record of the file."
}

t_upstream_find_a_missing_asset() {
  upstream_case
  printf '{"assets":[]}\n' >stub/api/repos_tree-sitter_tree-sitter-demo_releases_tags_v1.2.3
  run 1 "$tools_dir/check-upstream.sh" "my pack"
  has "has 0 assets with the name tree-sitter-demo.wasm, and it must have one"
}

t_upstream_find_two_assets_of_one_name() {
  upstream_case
  printf '{"assets":[{"name":"tree-sitter-demo.wasm","digest":null},{"name":"tree-sitter-demo.wasm","digest":null}]}\n' \
    >stub/api/repos_tree-sitter_tree-sitter-demo_releases_tags_v1.2.3
  run 1 "$tools_dir/check-upstream.sh" "my pack"
  has "has 2 assets with the name tree-sitter-demo.wasm, and it must have one"
}

t_upstream_find_a_file_that_the_attestation_does_not_cover() {
  upstream_case
  rm stub/attested
  run 1 "$tools_dir/check-upstream.sh" "my pack"
  has "my pack: the grammar demo: gh attestation verify does not accept the file: Error: verifying"
}

t_upstream_find_a_changed_license_file() {
  upstream_case
  printf 'x' >>"my pack/licenses/tree-sitter-demo.LICENSE"
  run 1 "$tools_dir/check-upstream.sh" "my pack"
  has "my pack: licenses/tree-sitter-demo.LICENSE is not the license file of tree-sitter/tree-sitter-demo at v1.2.3"
}

t_upstream_find_a_missing_license_on_github() {
  upstream_case
  rm stub/api/repos_tree-sitter_tree-sitter-demo_license_ref_v1.2.3
  run 1 "$tools_dir/check-upstream.sh" "my pack"
  has "my pack: GitHub gives no license file of tree-sitter/tree-sitter-demo at v1.2.3"
}

t_index_passes() {
  make_repository
  run 0 "$tools_dir/check-index.sh" repo
  has "The packs and the index pass, with 1 pack folders and 1 lines in the index."
}

t_index_passes_with_no_index() {
  make_repository
  rm repo/index.jsonl
  run 0 "$tools_dir/check-index.sh" repo
}

index_refusal() {
  make_repository
  printf '%s\n' "$1" >repo/index.jsonl
  run 1 "$tools_dir/check-index.sh" repo
  has "$2"
}

good_line() {
  index_line demo 0.1.0 "$(pack_hash repo/packs/demo)"
}

t_index_finds_a_line_that_is_not_json() {
  index_refusal '{"hash":' "index.jsonl: line 1: the line is not a JSON object"
}

t_index_finds_an_array() {
  index_refusal '[1]' "index.jsonl: line 1: the line is not a JSON object"
}

t_index_finds_a_space() {
  make_repository
  good_line | sed 's/,"name"/, "name"/' >repo/index.jsonl
  run 1 "$tools_dir/check-index.sh" repo
  has "index.jsonl: line 1: the line is not in the canonical form"
}

t_index_finds_keys_out_of_order() {
  make_repository
  good_line | jq -c '{name, hash, url, v, version}' >repo/index.jsonl
  run 1 "$tools_dir/check-index.sh" repo
  has "index.jsonl: line 1: the line is not in the canonical form"
}

t_index_finds_a_key_written_twice() {
  make_repository
  good_line | sed 's/^{/{"hash":"x",/' >repo/index.jsonl
  run 1 "$tools_dir/check-index.sh" repo
  has "index.jsonl: line 1: the line is not in the canonical form"
}

t_index_finds_a_field_too_many() {
  make_repository
  good_line | jq -c -S '. + {extra: 1}' >repo/index.jsonl
  run 1 "$tools_dir/check-index.sh" repo
  has "index.jsonl: line 1: the line does not have exactly the fields hash, name, url, v, and version"
}

t_index_finds_a_missing_field() {
  make_repository
  good_line | jq -c -S 'del(.url)' >repo/index.jsonl
  run 1 "$tools_dir/check-index.sh" repo
  has "the line does not have exactly the fields"
}

t_index_finds_a_v_that_is_not_one() {
  make_repository
  good_line | sed 's/"v":1/"v":2/' >repo/index.jsonl
  run 1 "$tools_dir/check-index.sh" repo
  has "index.jsonl: line 1: the field v is not 1"
}

t_index_finds_a_v_written_as_a_fraction() {
  make_repository
  good_line | sed 's/"v":1/"v":1.0/' >repo/index.jsonl
  run 1 "$tools_dir/check-index.sh" repo
  has "index.jsonl: line 1: the "
}

t_index_finds_a_v_written_as_a_string() {
  make_repository
  good_line | sed 's/"v":1/"v":"1"/' >repo/index.jsonl
  run 1 "$tools_dir/check-index.sh" repo
  has "index.jsonl: line 1: the field v is not 1"
}

t_index_finds_a_version_with_a_leading_zero() {
  make_repository
  index_line demo 01.0.0 "$(pack_hash repo/packs/demo)" >repo/index.jsonl
  run 1 "$tools_dir/check-index.sh" repo
  has "index.jsonl: line 1: the field version is not a release number"
}

t_index_finds_a_version_of_two_numbers() {
  make_repository
  index_line demo 0.1 "$(pack_hash repo/packs/demo)" >repo/index.jsonl
  run 1 "$tools_dir/check-index.sh" repo
  has "the field version is not a release number"
}

t_index_finds_a_name_that_is_not_a_name_of_a_pack() {
  make_repository
  index_line Demo 0.1.0 "$(pack_hash repo/packs/demo)" >repo/index.jsonl
  run 1 "$tools_dir/check-index.sh" repo
  has "index.jsonl: line 1: the field name is not a name of a pack"
}

t_index_finds_a_hash_in_upper_case() {
  make_repository
  index_line demo 0.1.0 "$(pack_hash repo/packs/demo | tr 'a-f' 'A-F')" >repo/index.jsonl
  run 1 "$tools_dir/check-index.sh" repo
  has "index.jsonl: line 1: the field hash is not 64 lowercase hex digits"
}

t_index_finds_a_name_with_a_line_feed_at_the_end() {
  make_repository
  index_line 'demo\n' 0.1.0 "$(pack_hash repo/packs/demo)" >repo/index.jsonl
  run 1 "$tools_dir/check-index.sh" repo
  has "index.jsonl: line 1: the field name is not a name of a pack"
}

t_index_finds_a_version_with_a_line_feed_at_the_end() {
  make_repository
  index_line demo '0.1.0\n' "$(pack_hash repo/packs/demo)" >repo/index.jsonl
  run 1 "$tools_dir/check-index.sh" repo
  has "index.jsonl: line 1: the field version is not a release number"
}

t_index_finds_a_hash_with_a_line_feed_at_the_end() {
  make_repository
  index_line demo 0.1.0 "$(pack_hash repo/packs/demo)\n" >repo/index.jsonl
  run 1 "$tools_dir/check-index.sh" repo
  has "index.jsonl: line 1: the field hash is not 64 lowercase hex digits"
}

t_index_finds_a_url_of_another_repository() {
  make_repository
  good_line | sed 's|sinterworks/sinter-packs|lathrys-at/sinter-packs|' >repo/index.jsonl
  run 1 "$tools_dir/check-index.sh" repo
  has "index.jsonl: line 1: the field url is not the address of the archive of the release"
}

t_index_finds_a_url_of_another_release() {
  make_repository
  good_line | sed 's|demo-v0.1.0/|demo-v0.1.1/|' >repo/index.jsonl
  run 1 "$tools_dir/check-index.sh" repo
  has "the field url is not the address of the archive of the release"
}

t_index_finds_a_carriage_return() {
  make_repository
  good_line | sed "s/\$/$(printf '\r')/" >repo/index.jsonl
  run 1 "$tools_dir/check-index.sh" repo
  has "index.jsonl: line 1: the line is not in the canonical form"
}

t_index_finds_a_blank_line() {
  make_repository
  printf '\n' >>repo/index.jsonl
  run 1 "$tools_dir/check-index.sh" repo
  has "index.jsonl: line 2: the line is not a JSON object"
}

t_index_finds_no_line_feed_at_the_end() {
  make_repository
  printf '%s' "$(good_line)" >repo/index.jsonl
  run 1 "$tools_dir/check-index.sh" repo
  has "index.jsonl does not end with a line feed"
}

second_pack() {
  make_pack repo/packs/alpha alpha alpha
}

t_index_passes_two_packs_in_byte_order() {
  make_repository
  second_pack
  {
    index_line alpha 0.1.0 "$(pack_hash repo/packs/alpha)"
    good_line
  } >repo/index.jsonl
  run 0 "$tools_dir/check-index.sh" repo
}

t_index_finds_packs_out_of_byte_order() {
  make_repository
  second_pack
  {
    good_line
    index_line alpha 0.1.0 "$(pack_hash repo/packs/alpha)"
  } >repo/index.jsonl
  run 1 "$tools_dir/check-index.sh" repo
  has "index.jsonl: line 2: the pack alpha comes after the pack demo, and the lines must be in the byte order of the names"
}

t_index_passes_releases_in_the_order_of_their_numbers() {
  make_repository
  set_version repo/packs/demo 0.10.0
  {
    index_line demo 0.9.0 "$(printf '%064d' 0)"
    index_line demo 0.10.0 "$(pack_hash repo/packs/demo)"
  } >repo/index.jsonl
  run 0 "$tools_dir/check-index.sh" repo
}

t_index_finds_releases_out_of_the_order_of_their_numbers() {
  make_repository
  set_version repo/packs/demo 0.9.0
  {
    index_line demo 0.10.0 "$(printf '%064d' 0)"
    index_line demo 0.9.0 "$(pack_hash repo/packs/demo)"
  } >repo/index.jsonl
  run 1 "$tools_dir/check-index.sh" repo
  has "index.jsonl: line 2: the release 0.9.0 of demo comes after the release 0.10.0"
}

t_index_finds_a_release_written_twice() {
  make_repository
  {
    good_line
    good_line
  } >repo/index.jsonl
  run 1 "$tools_dir/check-index.sh" repo
  has "index.jsonl: line 2: the release 0.1.0 of demo comes after the release 0.1.0"
}

t_index_finds_a_pack_with_no_folder() {
  make_repository
  {
    good_line
    index_line zeta 0.1.0 "$(printf '%064d' 0)"
  } >repo/index.jsonl
  run 1 "$tools_dir/check-index.sh" repo
  has "index.jsonl: line 2: the pack zeta has no folder packs/zeta with a descriptor that passes"
}

t_index_finds_a_newest_release_of_another_version() {
  make_repository
  set_version repo/packs/demo 0.2.0
  index_line demo 0.1.0 "$(pack_hash repo/packs/demo)" >repo/index.jsonl
  run 1 "$tools_dir/check-index.sh" repo
  has "index.jsonl: line 1: the newest release of demo is 0.1.0, and the descriptor gives the version 0.2.0"
}

t_index_finds_a_hash_of_other_files() {
  make_repository
  printf 'x' >>repo/packs/demo/queries/demo/tags.scm
  run 1 "$tools_dir/check-index.sh" repo
  has "index.jsonl: line 1: the release 0.1.0 of demo has the hash "
  has ", and the pack hash of packs/demo is $(pack_hash repo/packs/demo)"
}

t_index_finds_a_descriptor_of_another_name() {
  make_repository
  replace_line repo/packs/demo/pack.toml 'name = "demo"' 'name = "other"'
  run 1 "$tools_dir/check-index.sh" repo
  has "packs/demo: the descriptor gives the name \"other\", and the folder has the name demo"
}

t_index_finds_a_folder_that_is_not_a_name_of_a_pack() {
  make_repository
  mkdir "repo/packs/My Pack"
  run 1 "$tools_dir/check-index.sh" repo
  has "packs/My Pack: the name of the folder is not a name of a pack"
}

t_index_finds_a_file_under_packs() {
  make_repository
  printf 'x' >repo/packs/README
  run 1 "$tools_dir/check-index.sh" repo
  has "packs/README is not a folder"
}

t_index_finds_a_version_that_is_not_a_release_number() {
  make_repository
  set_version repo/packs/demo 1.0
  run 1 "$tools_dir/check-index.sh" repo
  has "packs/demo: the descriptor gives the version \"1.0\", which is not a release number"
}

base_repository() {
  make_repository
  mkdir -p "repo/packs/demo/a folder"
  printf 'x' >"repo/packs/demo/a folder/a file"
  printf 'y' >"repo/packs/demo/a folder.txt"
  printf 'z' >'repo/packs/demo/a "quoted" name'
  index_line demo 0.1.0 "$(pack_hash repo/packs/demo)" >repo/index.jsonl
  git init -q repo
  commit_all repo base
}

t_index_passes_an_unchanged_pack_against_the_base() {
  base_repository
  run 0 "$tools_dir/check-index.sh" -b HEAD repo
}

t_index_finds_a_changed_pack_with_no_new_release() {
  base_repository
  printf 'x' >>repo/packs/demo/queries/demo/tags.scm
  index_line demo 0.1.0 "$(pack_hash repo/packs/demo)" >repo/index.jsonl
  run 1 "$tools_dir/check-index.sh" -b HEAD repo
  has "packs/demo: the files of the pack changed since HEAD, and the index has no new release of it"
}

t_index_passes_a_changed_pack_with_a_new_release() {
  base_repository
  printf 'x' >>repo/packs/demo/queries/demo/tags.scm
  set_version repo/packs/demo 0.1.1
  index_line demo 0.1.1 "$(pack_hash repo/packs/demo)" >>repo/index.jsonl
  run 0 "$tools_dir/check-index.sh" -b HEAD repo
}

t_index_finds_a_line_of_the_base_that_is_gone() {
  base_repository
  printf 'x' >>repo/packs/demo/queries/demo/tags.scm
  set_version repo/packs/demo 0.1.1
  index_line demo 0.1.1 "$(pack_hash repo/packs/demo)" >repo/index.jsonl
  run 1 "$tools_dir/check-index.sh" -b HEAD repo
  has "index.jsonl: line 1 of the index of HEAD is no longer in the index"
}

t_index_passes_a_new_pack_with_no_release() {
  base_repository
  second_pack
  run 0 "$tools_dir/check-index.sh" -b HEAD repo
}

t_index_passes_a_pack_with_no_release_at_the_base() {
  make_repository
  rm repo/index.jsonl
  git init -q repo
  commit_all repo base
  printf 'x' >>repo/packs/demo/queries/demo/tags.scm
  run 0 "$tools_dir/check-index.sh" -b HEAD repo
}

t_index_finds_a_link_in_the_pack_at_the_base() {
  base_repository
  ln -s pack.toml repo/packs/demo/link
  commit_all repo link
  base=$(git -C repo rev-parse HEAD)
  rm repo/packs/demo/link
  commit_all repo "no link"
  run 1 "$tools_dir/check-index.sh" -b "$base" repo
  has "packs/demo has no pack hash at $base: the pack holds an entry that is not a file or a folder: link"
}

t_index_reads_the_repository_that_it_names() {
  base_repository
  mkdir other
  git init -q other
  run 0 env GIT_DIR="$case_dir/other/.git" "$tools_dir/check-index.sh" -b HEAD repo
}

t_index_needs_a_revision() {
  base_repository
  run 3 "$tools_dir/check-index.sh" -b no-such-revision repo
  has "no-such-revision is not a revision of the repository"
}

online_pack() {
  requires grammars
  mkdir -p "rust pack/grammars" "rust pack/licenses"
  cp "$rust_wasm" "rust pack/grammars/rust.wasm"
  curl -fsSL --proto '=https' -o "rust pack/licenses/tree-sitter-rust.LICENSE" \
    https://raw.githubusercontent.com/tree-sitter/tree-sitter-rust/v0.24.2/LICENSE
  {
    printf 'rust pack of Sinter\nCopyright 2026 The Sinter Authors\n'
    notice_block rust tree-sitter/tree-sitter-rust v0.24.2 "$1" tree-sitter-rust.wasm "$(sha256_of "$rust_wasm")"
  } >"rust pack/licenses/NOTICE"
}

t_online_upstream_passes_tree_sitter_rust() {
  online_pack 77a3747266f4d621d0757825e6b11edcbf991ca5
  run 0 "$tools_dir/check-upstream.sh" "rust pack"
  has "rust pack: the upstream releases pass."
}

t_online_upstream_finds_a_wrong_commit() {
  online_pack 0123456789abcdef0123456789abcdef01234567
  run 1 "$tools_dir/check-upstream.sh" "rust pack"
  has "names the commit 77a3747266f4d621d0757825e6b11edcbf991ca5"
  has "gh attestation verify does not accept the file"
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
