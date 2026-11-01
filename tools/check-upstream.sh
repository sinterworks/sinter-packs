#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 The Sinter Authors

set -eu
tool=check-upstream.sh
. "$(dirname -- "$0")/lib.sh"

usage() {
  cat <<'USAGE'
Usage: tools/check-upstream.sh PACK_ROOT...

Check each grammar of each pack against its upstream release on GitHub,
with the repository, the tag, the commit, and the asset that the block
of the grammar in licenses/NOTICE names:

  - the tag names the commit;
  - the release of the tag has the asset, and the SHA-256 of
    grammars/NAME.wasm is the digest that GitHub gives for the asset.
    When GitHub gives no digest, the tool says so, and the sha256 of the
    descriptor is the only record of the file;
  - gh attestation verify accepts the file: an attestation of the
    repository, signed by the release workflow of the tree-sitter
    organization, for the tag and the commit, on a runner of GitHub;
  - the file REPOSITORY.LICENSE in licenses/ is the license file of the
    repository at the tag, byte for byte.

The tool runs gh, and the environment variable GH can name another
command. gh needs a token, for example in GH_TOKEN.

Exit codes: 0 when every check passes, 1 when a check fails, 2 when the
command line is wrong, 3 when a command that the tool needs is missing.
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
gh=${GH:-gh}
need_command "$gh"
need_command jq
make_temp_dir
signer=tree-sitter/workflows/.github/workflows/release.yml

check_block() {
  pack=$1
  grammar=$2
  repository=$3
  tag=$4
  commit=$5
  asset=$6
  label="$pack: the grammar $grammar"
  file=$pack/grammars/$grammar.wasm
  if "$gh" api "repos/$repository/commits/$tag" </dev/null >"$temp_dir/commit.json" 2>"$temp_dir/error"; then
    named=$(jq -r '.sha // ""' "$temp_dir/commit.json")
    if [ "$named" != "$commit" ]; then
      problem "$label: the tag $tag of $repository names the commit $named, and licenses/NOTICE gives $commit"
    fi
  else
    problem "$label: GitHub gives no commit for the tag $tag of $repository: $(head -n 1 "$temp_dir/error")"
  fi
  if [ ! -f "$file" ]; then
    problem "$label has no file grammars/$grammar.wasm"
    return
  fi
  actual=$(sha256_of "$file")
  if "$gh" api "repos/$repository/releases/tags/$tag" </dev/null >"$temp_dir/release.json" 2>"$temp_dir/error"; then
    jq -r --arg name "$asset" \
      '[.assets[]? | select(.name == $name)] | if length == 1 then (.[0].digest // "none") else "count \(length)" end' \
      "$temp_dir/release.json" >"$temp_dir/digest"
    digest=$(cat "$temp_dir/digest")
    case $digest in
      none)
        printf '%s: GitHub gives no digest for the asset %s, so the sha256 of the descriptor is the only record of the file.\n' "$label" "$asset"
        ;;
      "sha256:$actual") ;;
      sha256:*)
        problem "$label has the SHA-256 $actual, and GitHub gives the digest ${digest#sha256:} for the asset $asset"
        ;;
      count*)
        problem "$label: the release $tag of $repository has ${digest#count } assets with the name $asset, and it must have one"
        ;;
      *)
        problem "$label: GitHub gives the asset $asset a digest that is not a SHA-256: $digest"
        ;;
    esac
  else
    problem "$label: GitHub gives no release for the tag $tag of $repository: $(head -n 1 "$temp_dir/error")"
  fi
  if ! "$gh" attestation verify "$file" \
    --repo "$repository" \
    --signer-workflow "$signer" \
    --source-ref "refs/tags/$tag" \
    --source-digest "$commit" \
    --deny-self-hosted-runners </dev/null >"$temp_dir/attestation" 2>&1; then
    problem "$label: gh attestation verify does not accept the file: $(grep -v '^$' "$temp_dir/attestation" | tail -n 1)"
  fi
}

check_license() {
  pack=$1
  repository=$2
  tag=$3
  name=${repository#*/}.LICENSE
  if [ ! -f "$pack/licenses/$name" ]; then
    problem "$pack: licenses/$name is missing"
    return
  fi
  if ! "$gh" api "repos/$repository/license?ref=$tag" </dev/null >"$temp_dir/license.json" 2>"$temp_dir/error"; then
    problem "$pack: GitHub gives no license file of $repository at $tag: $(head -n 1 "$temp_dir/error")"
    return
  fi
  if ! jq -j '.content | gsub("\n"; "") | @base64d' "$temp_dir/license.json" >"$temp_dir/license" 2>"$temp_dir/error"; then
    problem "$pack: the license file of $repository at $tag cannot be decoded"
    return
  fi
  if ! cmp -s "$temp_dir/license" "$pack/licenses/$name"; then
    problem "$pack: licenses/$name is not the license file of $repository at $tag"
  fi
}

for pack in "$@"; do
  pack=${pack%/}
  if [ ! -f "$pack/licenses/NOTICE" ]; then
    problem "$pack: licenses/NOTICE is missing"
    continue
  fi
  if ! read_notice "$pack/licenses/NOTICE" "$temp_dir/notice" 2>"$temp_dir/error"; then
    problem "$pack: licenses/NOTICE is not in its form: $(head -n 1 "$temp_dir/error")"
    continue
  fi
  before=$problems
  awk -F '\t' '$1 == "grammar"' "$temp_dir/notice" >"$temp_dir/blocks"
  while IFS="$(printf '\t')" read -r _ grammar repository tag commit asset _; do
    check_block "$pack" "$grammar" "$repository" "$tag" "$commit" "$asset"
  done <"$temp_dir/blocks"
  awk -F '\t' '$1 == "grammar" && !seen[$3]++ { print $3 "\t" $4 }' "$temp_dir/notice" >"$temp_dir/repositories"
  while IFS="$(printf '\t')" read -r repository tag; do
    check_license "$pack" "$repository" "$tag"
  done <"$temp_dir/repositories"
  if [ "$problems" -eq "$before" ]; then
    printf '%s: the upstream releases pass.\n' "$pack"
  fi
done
finish
