#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 The Sinter Authors

set -eu
tool=check-index.sh
. "$(dirname -- "$0")/lib.sh"

usage() {
  cat <<'USAGE'
Usage: tools/check-index.sh [-b BASE] [REPOSITORY]

Check the folders under packs/ and the index index.jsonl of REPOSITORY,
by default the repository that holds this tool.

  - Each entry under packs/ is a folder whose name is a name of a pack,
    with a descriptor pack.toml whose name is the name of the folder and
    whose version is a release number.
  - Each line of the index is a JSON object in canonical form, with
    exactly the fields hash, name, url, v, and version. v is 1, version
    is a release number, hash is 64 lowercase hex digits, and url is
    https://github.com/sinterworks/sinter-packs/releases/download/NAME-vVERSION/NAME-VERSION.tar.gz.
  - The lines are in the byte order of the names. The lines of one pack
    are in the order of the release numbers, from the oldest, and no two
    of them have one release number.
  - Each pack of the index has its folder. The newest line of the pack
    has the version of the descriptor and the pack hash of the folder.

With -b, the tool also compares the tree with the git revision BASE:

  - Each line of the index of BASE is still in the index.
  - When the files of a pack that has a line in the index of BASE
    changed, the index has a new line for the pack.

Exit codes: 0 when every check passes, 1 when a check fails, 2 when the
command line is wrong, 3 when a command that the tool needs is missing
or BASE is not a revision.
USAGE
}

base=
while getopts hb: option; do
  case $option in
    h) usage; exit 0 ;;
    b) base=$OPTARG ;;
    *) usage_error "the option is not known" ;;
  esac
done
shift $((OPTIND - 1))
[ "$#" -le 1 ] || usage_error "give at most one repository"
repository=${1:-$(repository_root)}
[ -d "$repository" ] || usage_error "$repository is not a folder"
need_command jq
make_temp_dir
index=$repository/index.jsonl
packs=$repository/packs
name_pattern='[a-z][a-z0-9]*(-[a-z0-9]+)*'
release_pattern='(0|[1-9][0-9]*)[.](0|[1-9][0-9]*)[.](0|[1-9][0-9]*)'

: >"$temp_dir/folders"
if [ -d "$packs" ]; then
  find "$packs/." ! -name . -prune -print | sed 's|^.*/||' | sort >"$temp_dir/entries"
  while IFS= read -r name; do
    folder=$packs/$name
    if [ ! -d "$folder" ] || [ -L "$folder" ]; then
      problem "packs/$name is not a folder"
      continue
    fi
    if ! matches "$name" "$name_pattern"; then
      problem "packs/$name: the name of the folder is not a name of a pack"
      continue
    fi
    if [ ! -f "$folder/pack.toml" ]; then
      problem "packs/$name has no descriptor pack.toml"
      continue
    fi
    if ! read_descriptor "$folder/pack.toml" "$temp_dir/descriptor" 2>"$temp_dir/error"; then
      problem "packs/$name: the descriptor cannot be read: $(head -n 1 "$temp_dir/error")"
      continue
    fi
    named=$(descriptor_value "$temp_dir/descriptor" name) || named=
    version=$(descriptor_value "$temp_dir/descriptor" version) || version=
    if [ "$named" != "$name" ]; then
      problem "packs/$name: the descriptor gives the name \"$named\", and the folder has the name $name"
      continue
    fi
    if ! matches "$version" "$release_pattern"; then
      problem "packs/$name: the descriptor gives the version \"$version\", which is not a release number"
      continue
    fi
    printf '%s\t%s\n' "$name" "$version" >>"$temp_dir/folders"
  done <"$temp_dir/entries"
fi

: >"$temp_dir/lines"
if [ -f "$index" ]; then
  if [ -s "$index" ] && [ -n "$(tail -c 1 "$index")" ]; then
    problem "index.jsonl does not end with a line feed"
  fi
  jq -R -n -r \
    --arg names "\\A($name_pattern)\\z" \
    --arg releases "\\A($release_pattern)\\z" \
    '[inputs] | to_entries[] | (.key + 1) as $line | .value as $text |
      ($text | try fromjson catch null) as $object |
      if ($object | type) != "object" then "bad\t\($line)\tthe line is not a JSON object"
      elif ($object | keys) != ["hash", "name", "url", "v", "version"] then
        "bad\t\($line)\tthe line does not have exactly the fields hash, name, url, v, and version"
      elif ($object | to_entries | sort_by(.key) | from_entries | tojson) != $text then
        "bad\t\($line)\tthe line is not in the canonical form: sorted keys, and no space outside the strings"
      elif ($object.v | tojson) != "1" then "bad\t\($line)\tthe field v is not 1"
      elif ($object.name | type) != "string" or ($object.name | test($names) | not) then
        "bad\t\($line)\tthe field name is not a name of a pack"
      elif ($object.version | type) != "string" or ($object.version | test($releases) | not) then
        "bad\t\($line)\tthe field version is not a release number"
      elif ($object.hash | type) != "string" or ($object.hash | test("\\A[0-9a-f]{64}\\z") | not) then
        "bad\t\($line)\tthe field hash is not 64 lowercase hex digits"
      elif $object.url != "https://github.com/sinterworks/sinter-packs/releases/download/\($object.name)-v\($object.version)/\($object.name)-\($object.version).tar.gz" then
        "bad\t\($line)\tthe field url is not the address of the archive of the release"
      else "ok\t\($line)\t\($object.name)\t\($object.version)\t\($object.hash)" end' \
    <"$index" >"$temp_dir/parsed" || fatal "jq cannot read index.jsonl"
  awk -F '\t' '$1 == "bad" { print "index.jsonl: line " $2 ": " $3 }' "$temp_dir/parsed" >"$temp_dir/bad"
  while IFS= read -r message; do
    problem "$message"
  done <"$temp_dir/bad"
  awk -F '\t' 'BEGIN { OFS = "\t" } $1 == "ok" { print $2, $3, $4, $5 }' "$temp_dir/parsed" >"$temp_dir/lines"
fi

awk -F '\t' '
  function newer(a, b,   x, y, i) {
    split(a, x, ".")
    split(b, y, ".")
    for (i = 1; i <= 3; i++) {
      if (x[i] + 0 > y[i] + 0) return 1
      if (x[i] + 0 < y[i] + 0) return 0
    }
    return 0
  }
  NR > 1 && $2 < name {
    print "index.jsonl: line " $1 ": the pack " $2 " comes after the pack " name ", and the lines must be in the byte order of the names"
  }
  NR > 1 && $2 == name && !newer($3, version) {
    print "index.jsonl: line " $1 ": the release " $3 " of " $2 " comes after the release " version ", and the lines of a pack must be in the order of the release numbers, each number once"
  }
  { name = $2; version = $3 }
' "$temp_dir/lines" >"$temp_dir/order"
while IFS= read -r message; do
  problem "$message"
done <"$temp_dir/order"

awk -F '\t' 'BEGIN { OFS = "\t" } { newest[$2] = $3 "\t" $4; line[$2] = $1 } END { for (n in newest) print n, line[n], newest[n] }' \
  "$temp_dir/lines" | sort >"$temp_dir/newest"
while IFS="$(printf '\t')" read -r name line version hash; do
  folder_version=$(awk -F '\t' -v name="$name" '$1 == name { print $2 }' "$temp_dir/folders")
  if [ -z "$folder_version" ]; then
    problem "index.jsonl: line $line: the pack $name has no folder packs/$name with a descriptor that passes"
    continue
  fi
  if [ "$version" != "$folder_version" ]; then
    problem "index.jsonl: line $line: the newest release of $name is $version, and the descriptor gives the version $folder_version"
  fi
  if ! actual=$(pack_hash "$packs/$name" 2>"$temp_dir/error"); then
    problem "packs/$name has no pack hash: $(head -n 1 "$temp_dir/error")"
    continue
  fi
  if [ "$hash" != "$actual" ]; then
    problem "index.jsonl: line $line: the release $version of $name has the hash $hash, and the pack hash of packs/$name is $actual"
  fi
done <"$temp_dir/newest"

if [ -n "$base" ]; then
  need_command git
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
    GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_NAMESPACE
  commit=$(git -C "$repository" rev-parse --verify --quiet "$base^{commit}") ||
    fatal "$base is not a revision of the repository"
  if git -C "$repository" cat-file -e "$commit:index.jsonl" 2>/dev/null; then
    git -C "$repository" show "$commit:index.jsonl" >"$temp_dir/base-index"
  else
    : >"$temp_dir/base-index"
  fi
  if [ -f "$index" ]; then
    cp "$index" "$temp_dir/head-index"
  else
    : >"$temp_dir/head-index"
  fi
  awk 'NR == FNR { head[$0] = 1; next } !($0 in head) { print FNR }' \
    "$temp_dir/head-index" "$temp_dir/base-index" >"$temp_dir/gone"
  while IFS= read -r line; do
    problem "index.jsonl: line $line of the index of $base is no longer in the index"
  done <"$temp_dir/gone"
  while IFS="$(printf '\t')" read -r name version; do
    released=$(jq -R -r --arg name "$name" 'fromjson? | select(.name == $name) | .version' "$temp_dir/base-index" | tail -n 1)
    [ -n "$released" ] || continue
    git -C "$repository" cat-file -e "$commit:packs/$name/pack.toml" 2>/dev/null || continue
    if ! before=$(pack_hash_at "$repository" "$commit" "packs/$name" 2>"$temp_dir/error"); then
      problem "packs/$name has no pack hash at $base: $(head -n 1 "$temp_dir/error")"
      continue
    fi
    after=$(pack_hash "$packs/$name" 2>/dev/null) || continue
    [ "$before" != "$after" ] || continue
    jq -R -r --arg name "$name" 'fromjson? | select(.name == $name) | .version' "$temp_dir/base-index" >"$temp_dir/base-versions"
    added=$(jq -R -r --arg name "$name" 'fromjson? | select(.name == $name) | .version' "$temp_dir/head-index" |
      grep -Fvx -f "$temp_dir/base-versions" || true)
    if [ -z "$added" ]; then
      problem "packs/$name: the files of the pack changed since $base, and the index has no new release of it; raise the version in the descriptor and add the line of the new release to the index"
    fi
  done <"$temp_dir/folders"
fi

if [ "$problems" -eq 0 ]; then
  printf 'The packs and the index pass, with %s pack folders and %s lines in the index.\n' \
    "$(awk 'END { print NR }' "$temp_dir/folders")" "$(awk 'END { print NR }' "$temp_dir/lines")"
fi
finish
