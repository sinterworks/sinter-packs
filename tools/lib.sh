# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 The Sinter Authors

LC_ALL=C
export LC_ALL

tools_dir=${tools_dir:-$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)}
repository_root() {
  CDPATH='' cd -- "$tools_dir/.." && pwd
}

problems=0

usage_error() {
  printf '%s: %s\n' "${tool:?}" "$1" >&2
  printf 'Run %s -h for the usage.\n' "$tool" >&2
  exit 2
}

fatal() {
  printf '%s: %s\n' "${tool:?}" "$1" >&2
  exit 3
}

problem() {
  printf '%s\n' "$1"
  problems=$((problems + 1))
}

finish() {
  if [ "$problems" -ne 0 ]; then
    exit 1
  fi
  exit 0
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || fatal "this check needs the command $1, and it is not installed"
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum <"$1" | awk '{ print $1 }'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 <"$1" | awk '{ print $1 }'
  else
    fatal "this check needs sha256sum or shasum, and neither is installed"
  fi
}

sha256_of_stdin() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{ print $1 }'
  else
    shasum -a 256 | awk '{ print $1 }'
  fi
}

make_temp_dir() {
  temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/sinter-packs.XXXXXX") || fatal "cannot make a temporary folder"
  temp_dir=$(CDPATH='' cd -- "$temp_dir" && pwd)
  trap 'rm -rf -- "$temp_dir"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
}

matches() {
  MATCH_VALUE=$1 MATCH_PATTERN=$2 awk 'BEGIN {
    exit !(ENVIRON["MATCH_VALUE"] ~ ("^(" ENVIRON["MATCH_PATTERN"] ")$"))
  }'
}

is_hex() {
  matches "$1" '[0-9a-f]+' && [ "${#1}" -eq "$2" ]
}

read_descriptor() {
  awk -f "$tools_dir/descriptor.awk" <"$1" >"$2"
}

pack_hash() {
  (
    cd -- "$1" || exit 3
    odd=$(find . ! -type f ! -type d | sed 's|^\./||' | head -n 1)
    if [ -n "$odd" ]; then
      printf 'the pack holds an entry that is not a file or a folder: %s\n' "$odd" >&2
      exit 1
    fi
    odd=$(find . \( -name '*[! -~]*' -o -name '*\\*' \) | sed 's|^\./||' | head -n 1)
    if [ -n "$odd" ]; then
      printf 'the pack holds a path with a character outside printable ASCII or with a backslash: %s\n' "$odd" >&2
      exit 1
    fi
    find . -type f | sed 's|^\./||' | sort >"$temp_dir/paths"
    : >"$temp_dir/listing"
    while IFS= read -r path; do
      hash=$(sha256_of "$path")
      is_hex "$hash" 64 || exit 3
      printf '%s  %s\n' "$hash" "$path" >>"$temp_dir/listing"
    done <"$temp_dir/paths"
    sha256_of "$temp_dir/listing"
  )
}

descriptor_value() {
  awk -F '\t' -v key="$2" '$1 == key { print $2; found = 1; exit } END { exit !found }' "$1"
}

descriptor_grammars() {
  awk -F '\t' '$1 ~ /^grammar\[[0-9]+\]\.name$/ { print $2 }' "$1"
}

descriptor_grammar_value() {
  awk -F '\t' -v name="$2" -v key="$3" '
    $1 ~ /^grammar\[[0-9]+\]\.name$/ && $2 == name { prefix = substr($1, 1, length($1) - 4) }
    { values[$1] = $2 }
    END {
      if (prefix == "" || !((prefix key) in values)) exit 1
      print values[prefix key]
    }
  ' "$1"
}
