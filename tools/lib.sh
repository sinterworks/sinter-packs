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

wasm_info() {
  WASM_FILE=$1 WASM_MODE=file WASM_GRAMMAR=$2 \
    WASM_SIZE=$(wc -c <"$1" | tr -d ' ') \
    awk -f "$tools_dir/wasm.awk" </dev/null
}

read_notice() {
  awk '
    function stop(message) {
      printf "line %d: %s\n", NR, message > "/dev/stderr"
      failed = 1
      exit 1
    }
    function field(key, pattern,   value) {
      if (index($0, key ": ") != 1)
        stop("the line does not start with " key ":")
      value = substr($0, length(key) + 3)
      if (value !~ ("^(" pattern ")$"))
        stop("the value of " key " is not in its form")
      return value
    }
    NR == 1 {
      if ($0 !~ /^[a-z][a-z0-9]*(-[a-z0-9]+)* pack of Sinter$/)
        stop("the first line is not \"<name> pack of Sinter\"")
      print "name\t" substr($0, 1, length($0) - 15)
      next
    }
    NR == 2 {
      if ($0 !~ /^Copyright [0-9][0-9][0-9][0-9] The Sinter Authors$/)
        stop("the second line is not \"Copyright <year> The Sinter Authors\"")
      next
    }
    {
      place = (NR - 3) % 7
      if (place == 0) {
        if ($0 != "")
          stop("a blank line must stand before each block")
      } else if (place == 1) {
        grammar = field("grammar", "[a-z][a-z0-9_]*")
      } else if (place == 2) {
        repository = field("repository", "[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+")
        if (repository ~ /(^|\/)\.\.?(\/|$)/)
          stop("the value of repository is not in its form")
      } else if (place == 3) {
        tag = field("tag", "[A-Za-z0-9_.+-]+(/[A-Za-z0-9_.+-]+)*")
        if (tag ~ /(^|\/)\.\.?(\/|$)/)
          stop("the value of tag is not in its form")
      } else if (place == 4) {
        commit = field("commit", "[0-9a-f]+")
        if (length(commit) != 40)
          stop("the value of commit is not in its form")
      } else if (place == 5) {
        asset = field("asset", "[A-Za-z0-9_.+-]+")
        if (asset == "." || asset == "..")
          stop("the value of asset is not in its form")
      } else {
        sha256 = field("sha256", "[0-9a-f]+")
        if (length(sha256) != 64)
          stop("the value of sha256 is not in its form")
        print "grammar\t" grammar "\t" repository "\t" tag "\t" commit "\t" asset "\t" sha256
      }
    }
    END {
      if (failed)
        exit 1
      if (NR < 2)
        stop("the notice is shorter than its two first lines")
      if (NR > 2 && (NR - 3) % 7 != 6) {
        NR = NR + 1
        stop("the last block does not have its six lines")
      }
    }
  ' <"$1" >"$2"
}

spdx_problem() {
  SPDX_EXPRESSION=$1 awk '
    function next_token(   upper) {
      position++
      token = position <= count ? tokens[position] : ""
      upper = toupper(token)
      if ((upper == "AND" || upper == "OR" || upper == "WITH") && token != upper)
        stop("writes the operator " token " in lower case, and the tools read only " upper)
    }
    function term() {
      if (token == "(") {
        next_token()
        expression()
        if (token != ")")
          stop("is not an SPDX expression")
        next_token()
        return
      }
      if (token !~ /^[A-Za-z0-9.+-]+$/ || token == "AND" || token == "OR" || token == "WITH")
        stop("is not an SPDX expression")
      if (!(token in allowed))
        stop("names the license " token ", which is not on the list of licenses that a pack can use")
      next_token()
      if (token == "WITH")
        stop("names a license exception, and no exception is on the list of licenses that a pack can use")
    }
    function expression() {
      term()
      while (token == "AND" || token == "OR") {
        next_token()
        term()
      }
    }
    function stop(message) {
      print message
      exit 0
    }
    BEGIN {
      split("0BSD Apache-2.0 BSD-2-Clause BSD-3-Clause ISC MIT MPL-2.0 Unlicense", list, " ")
      for (i in list)
        allowed[list[i]] = 1
      text = ENVIRON["SPDX_EXPRESSION"]
      gsub(/\(/, " ( ", text)
      gsub(/\)/, " ) ", text)
      if (text ~ /[^ -~]/)
        stop("is not an SPDX expression")
      count = split(text, tokens, " ")
      position = 0
      next_token()
      if (token == "")
        stop("is not an SPDX expression")
      expression()
      if (token != "")
        stop("is not an SPDX expression")
    }
  '
}

pack_hash_at() {
  rm -rf "$temp_dir/base"
  mkdir "$temp_dir/base"
  git -C "$1" archive --format=tar "$2" "$3" >"$temp_dir/base.tar" || return 3
  tar -x -f "$temp_dir/base.tar" -C "$temp_dir/base" || return 3
  pack_hash "$temp_dir/base/$3"
}
