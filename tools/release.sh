#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 The Sinter Authors

set -eu
tool=release.sh
. "$(dirname -- "$0")/lib.sh"
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
  GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_NAMESPACE

usage() {
  cat <<'USAGE'
Usage: tools/release.sh [-r REPOSITORY] prepare OUTDIR
       tools/release.sh [-r REPOSITORY] publish OUTDIR
       tools/release.sh [-r REPOSITORY] rehearse OUTDIR NAME TAG
       tools/release.sh clean-rehearsal TAG

Release the packs that the index index.jsonl of REPOSITORY names, by
default the repository that holds this tool.

prepare makes a draft release for each line of the index with no
published release. The tag of a line is NAME-vVERSION. The tool builds
each release from the commit that added its line: the oldest commit on
the first-parent history of GITHUB_SHA whose change to the index adds the
line. The draft has that commit as its target.

  1. It runs the check of the index. With no index, it stops with exit
     code 0, because there is nothing to release. It needs the full
     history, and it refuses a shallow checkout.
  2. It finds the problems: a tag that exists with no published release,
     a line that no commit added, and a commit whose folder of the pack
     does not have the pack hash and the version of the line. With a
     problem, it stops and changes nothing on GitHub.
  3. It deletes each old draft of those lines. It builds and checks each
     archive into OUTDIR, compares the pack hash with the line, and makes
     the draft.
  4. It writes each tag and its commit to the file OUTDIR/tags and prints
     the number of drafts.

publish publishes each draft of OUTDIR/tags, in order. Before it
publishes a draft, it checks that the tag does not exist, that the
release is the only draft of the tag and has the commit of OUTDIR/tags,
and that its one asset has the bytes of the archive in OUTDIR. After it
publishes the draft, it checks the commit of the tag, downloads the
archive from the address in the index, compares it with the archive in
OUTDIR, and runs gh release verify and gh release verify-asset. A failure
stops the run and names the tag. A new run makes a draft again when the
release is not published. A new run skips a published release and does
not check it again. A published release cannot change, so the fix for a
wrong release is a new release.

rehearse does the work of a release for the pack NAME up to a draft, and
it publishes nothing. It reads the folder of the pack from the commit
GITHUB_SHA, as prepare does, and it refuses a shallow checkout. It builds
and checks the archive, compares its pack hash with the folder in
REPOSITORY, and makes a draft with the tag TAG. It checks that the draft
made no tag, and it runs the checks of a draft that publish runs. It
writes TAG and its commit to the file OUTDIR/tags. TAG must not have the
form *-v*.

clean-rehearsal deletes each draft of TAG, and the tag when it exists.
It succeeds when there is nothing to delete. TAG must not have the form
*-v*.

OUTDIR must be empty or absent for prepare and rehearse.

The tool reads the environment:

  GITHUB_REPOSITORY    the repository on GitHub, as OWNER/NAME
  GITHUB_SHA           the commit of the run, as 40 lowercase hex digits;
                       prepare and rehearse need it
  GITHUB_STEP_SUMMARY  a file for a summary of the run, when set
  GH, CURL             other commands in place of gh and curl
  RELEASE_RETRY_WAIT   the seconds between two tries of a verification,
                       by default 5

gh needs a token, for example in GH_TOKEN.

Exit codes: 0 when the command succeeds, 1 when it fails, 2 when the
command line or the environment is wrong, 3 when a command that the tool
needs is missing.
USAGE
}

repository=
while getopts hr: option; do
  case $option in
    h) usage; exit 0 ;;
    r) repository=$OPTARG ;;
    *) usage_error "the option is not known" ;;
  esac
done
shift $((OPTIND - 1))
[ "$#" -ge 1 ] || usage_error "give a command: prepare, publish, rehearse, or clean-rehearsal"
subcommand=$1
shift
repository=${repository:-$(repository_root)}
[ -d "$repository" ] || usage_error "$repository is not a folder"
gh=${GH:-gh}
curl_command=${CURL:-curl}
retry_wait=${RELEASE_RETRY_WAIT:-5}
tab=$(printf '\t')
name_pattern='[a-z][a-z0-9]*(-[a-z0-9]+)*'
release_pattern='(0|[1-9][0-9]*)[.](0|[1-9][0-9]*)[.](0|[1-9][0-9]*)'

stop() {
  printf '%s\n' "$1" >&2
  exit 1
}

stop_before_publication() {
  stop "$1: $2. The release is not published, and a new run makes the draft again."
}

stop_at_publication() {
  stop "$1: $2. When the release is still a draft, a new run makes it again. A published release cannot change, and the fix for a wrong release is a new release."
}

stop_after_publication() {
  stop "$1: $2. The release is published, and a published release cannot change. A new run skips it and does not check it again, so check it with gh release verify. The fix for a wrong release is a new release."
}

error_line() {
  head -n 1 "$temp_dir/error"
}

read_environment() {
  repo=${GITHUB_REPOSITORY:-}
  matches "$repo" '[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+' ||
    usage_error "the variable GITHUB_REPOSITORY must give the repository as OWNER/NAME"
  GH_REPO=$repo
  export GH_REPO
  need_command "$gh"
  need_command jq
  command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 ||
    fatal "this check needs sha256sum or shasum, and neither is installed"
  make_temp_dir
}

read_commit() {
  commit=${GITHUB_SHA:-}
  is_hex "$commit" 40 || usage_error "the variable GITHUB_SHA must give a commit as 40 lowercase hex digits"
}

use_empty_outdir() {
  outdir=$1
  if [ -e "$outdir" ] && [ ! -d "$outdir" ]; then
    usage_error "$outdir is not a folder"
  fi
  mkdir -p -- "$outdir"
  [ -z "$(ls -A -- "$outdir")" ] || usage_error "$outdir holds files, and it must be empty"
}

read_tag_argument() {
  rehearsal_tag=$1
  case $rehearsal_tag in
    *-v*) usage_error "the tag $rehearsal_tag has the form of the tag of a release, and such a tag cannot change" ;;
  esac
  matches "$rehearsal_tag" '[A-Za-z0-9][A-Za-z0-9._-]*' ||
    usage_error "the tag $rehearsal_tag holds a character that a rehearsal does not take"
}

list_releases() {
  "$gh" api --paginate "repos/$repo/releases" </dev/null >"$temp_dir/releases.json" 2>"$temp_dir/error" ||
    stop "GitHub gives no list of the releases: $(error_line)"
  jq -r '.[] | [.tag_name, (.draft | tostring), (.id | tostring)] | @tsv' \
    "$temp_dir/releases.json" >"$temp_dir/releases" 2>"$temp_dir/error" ||
    stop "the list of the releases cannot be read: $(error_line)"
}

has_published_release() {
  awk -F '\t' -v tag="$1" '$1 == tag && $2 == "false" { found = 1 } END { exit !found }' "$temp_dir/releases"
}

draft_ids() {
  awk -F '\t' -v tag="$1" '$1 == tag && $2 == "true" { print $3 }' "$temp_dir/releases"
}

tag_exists() {
  if "$gh" api "repos/$repo/git/ref/tags/$1" </dev/null >/dev/null 2>"$temp_dir/error"; then
    return 0
  fi
  grep -Fq 'HTTP 404' "$temp_dir/error" || stop "GitHub does not say whether the tag $1 exists: $(error_line)"
  return 1
}

delete_release() {
  "$gh" api -X DELETE "repos/$repo/releases/$2" </dev/null >/dev/null 2>"$temp_dir/error" ||
    stop "$1: gh cannot delete the draft $2: $(error_line)"
  printf 'Deleted the draft %s of the tag %s.\n' "$2" "$1"
}

read_index() {
  jq -r '[.name, .version, .hash, .url, tojson] | @tsv' "$repository/index.jsonl" >"$temp_dir/lines" 2>"$temp_dir/error" ||
    stop "index.jsonl cannot be read: $(error_line)"
}

build_and_check() {
  archive=$outdir/$1-$2.tar.gz
  "$tools_dir/build-archive.sh" "$3" "$archive" </dev/null
  archive_hash=$("$tools_dir/check-archive.sh" "$archive" </dev/null)
}

make_draft() {
  "$gh" release create "$1" "$archive" --draft --target "$5" --latest=false \
    --title "$2 $3" --notes "The pack hash of this release is $4." \
    </dev/null >/dev/null 2>"$temp_dir/error" ||
    stop "$1: gh cannot make the draft: $(error_line)"
  printf 'Made a draft of the tag %s at the commit %s.\n' "$1" "$5"
}

check_history() {
  need_command git
  need_command tar
  shallow=$(git -C "$repository" rev-parse --is-shallow-repository 2>"$temp_dir/error") ||
    stop "$repository is not a git repository: $(error_line)"
  [ "$shallow" = false ] ||
    stop "the checkout is shallow, so its history does not show which commit added a line of the index. Fetch the full history."
  git -C "$repository" cat-file -e "$commit^{commit}" 2>/dev/null ||
    stop "the repository has no commit $commit"
}

extract_folder() {
  if ! git -C "$repository" archive --format=tar "$3" "packs/$2" \
    >"$temp_dir/source.tar" 2>"$temp_dir/error"; then
    source_fault="the commit $3 has no folder packs/$2: $(error_line)"
    return 1
  fi
  source_root=$temp_dir/source/$1
  mkdir -p "$source_root"
  tar -x -f "$temp_dir/source.tar" -C "$source_root" 2>"$temp_dir/error" ||
    stop "$1: tar cannot read the folder of the commit $3: $(error_line)"
  source_root=$source_root/packs/$2
  if [ -L "$source_root" ] || [ ! -d "$source_root" ]; then
    source_fault="packs/$2 is not a folder in the commit $3"
    return 1
  fi
}

read_line_source() {
  line_tag=$1
  line_name=$2
  line_version=$3
  line_hash=$4
  line_text=$5
  git -C "$repository" log --first-parent --reverse --format=%H -S"$line_text" "$commit" -- index.jsonl \
    >"$temp_dir/found" 2>"$temp_dir/error" ||
    stop "$line_tag: git cannot read the history of the index: $(error_line)"
  target=$(head -n 1 "$temp_dir/found")
  if [ -z "$target" ]; then
    problem "$line_tag: no commit in the history of $commit adds this line of the index: $line_text"
    return 1
  fi
  git -C "$repository" show "$target:index.jsonl" >"$temp_dir/index-at-target" 2>"$temp_dir/error" ||
    stop "$line_tag: git cannot read the index of the commit $target: $(error_line)"
  if ! grep -Fxq -- "$line_text" "$temp_dir/index-at-target"; then
    problem "$line_tag: the commit $target changes this line of the index but does not hold it as a line: $line_text"
    return 1
  fi
  if ! extract_folder "$line_tag" "$line_name" "$target"; then
    problem "$line_tag: $source_fault"
    return 1
  fi
  if ! folder_hash=$("$tools_dir/pack-hash.sh" "$source_root" </dev/null 2>"$temp_dir/error"); then
    problem "$line_tag: packs/$line_name has no pack hash in the commit $target: $(error_line)"
    return 1
  fi
  if [ "$folder_hash" != "$line_hash" ]; then
    problem "$line_tag: the line of the index has the hash $line_hash, and packs/$line_name in the commit $target that adds the line holds other content, with the pack hash $folder_hash"
    return 1
  fi
  if ! read_descriptor "$source_root/pack.toml" "$temp_dir/descriptor" 2>"$temp_dir/error"; then
    problem "$line_tag: the descriptor of packs/$line_name in the commit $target cannot be read: $(error_line)"
    return 1
  fi
  folder_name=$(descriptor_value "$temp_dir/descriptor" name) || folder_name=
  folder_version=$(descriptor_value "$temp_dir/descriptor" version) || folder_version=
  if [ "$folder_name" != "$line_name" ] || [ "$folder_version" != "$line_version" ]; then
    problem "$line_tag: the descriptor of packs/$line_name in the commit $target gives the name \"$folder_name\" and the version \"$folder_version\", which are not those of the line"
    return 1
  fi
}

write_summary() {
  [ -z "${GITHUB_STEP_SUMMARY:-}" ] || printf '%s\n' "$1" >>"$GITHUB_STEP_SUMMARY"
}

prepare() {
  read_environment
  read_commit
  use_empty_outdir "$1"
  if [ ! -f "$repository/index.jsonl" ]; then
    printf 'The repository has no index.jsonl, so there is nothing to release.\n'
    : >"$outdir/tags"
    printf 'Number of drafts: 0\n'
    exit 0
  fi
  "$tools_dir/check-index.sh" "$repository" </dev/null
  check_history
  read_index
  list_releases
  : >"$temp_dir/needed"
  : >"$temp_dir/old-drafts"
  while IFS="$tab" read -r name version hash url text; do
    line_tag=$name-v$version
    if has_published_release "$line_tag"; then
      printf '%s has a published release.\n' "$line_tag"
      continue
    fi
    if tag_exists "$line_tag"; then
      problem "$line_tag: the tag exists with no published release, and a tag cannot change. The index needs a new release of $name."
      continue
    fi
    read_line_source "$line_tag" "$name" "$version" "$hash" "$text" || continue
    printf '%s\t%s\t%s\t%s\t%s\n' "$line_tag" "$name" "$version" "$hash" "$target" >>"$temp_dir/needed"
    draft_ids "$line_tag" | while IFS= read -r id; do
      printf '%s\t%s\n' "$line_tag" "$id"
    done >>"$temp_dir/old-drafts"
  done <"$temp_dir/lines"
  if [ "$problems" -ne 0 ]; then
    printf 'The tool changed nothing on GitHub.\n'
    exit 1
  fi
  while IFS="$tab" read -r line_tag id; do
    delete_release "$line_tag" "$id"
  done <"$temp_dir/old-drafts"
  : >"$temp_dir/tags"
  while IFS="$tab" read -r line_tag name version hash target; do
    build_and_check "$name" "$version" "$temp_dir/source/$line_tag/packs/$name"
    if [ "$archive_hash" != "$hash" ]; then
      stop "$line_tag: the archive has the pack hash $archive_hash, and the line of the index has the hash $hash"
    fi
    make_draft "$line_tag" "$name" "$version" "$hash" "$target"
    printf '%s\t%s\n' "$line_tag" "$target" >>"$temp_dir/tags"
  done <"$temp_dir/needed"
  mv -- "$temp_dir/tags" "$outdir/tags"
  printf 'Number of drafts: %s\n' "$(awk 'END { print NR }' "$outdir/tags")"
}

check_draft() {
  list_releases
  if has_published_release "$1"; then
    draft_fault="a published release has this tag"
    return 1
  fi
  jq -r --arg tag "$1" \
    '.[] | select(.tag_name == $tag and .draft) |
      [(.target_commitish // "none"), (.assets | length), (.assets[0].name // "none"), (.assets[0].id // "none")] | @tsv' \
    "$temp_dir/releases.json" >"$temp_dir/draft" 2>"$temp_dir/error" ||
    stop "the list of the releases cannot be read: $(error_line)"
  draft_count=$(awk 'END { print NR }' "$temp_dir/draft")
  if [ "$draft_count" -ne 1 ]; then
    draft_fault="GitHub holds $draft_count drafts of this tag, and it must hold one"
    return 1
  fi
  IFS="$tab" read -r draft_target asset_count asset_name asset_id <"$temp_dir/draft"
  if [ "$draft_target" != "$2" ]; then
    draft_fault="the draft has the commit $draft_target, and it must have the commit $2"
    return 1
  fi
  if [ "$asset_count" -ne 1 ] || [ "$asset_name" != "${archive##*/}" ]; then
    draft_fault="the draft does not have exactly one asset, with the name ${archive##*/}"
    return 1
  fi
  if ! "$gh" api -H 'Accept: application/octet-stream' "repos/$repo/releases/assets/$asset_id" \
    </dev/null >"$temp_dir/asset" 2>"$temp_dir/error"; then
    draft_fault="the asset of the draft cannot be downloaded: $(error_line)"
    return 1
  fi
  built=$(sha256_of "$archive") || built=
  if ! is_hex "$built" 64; then
    draft_fault="the SHA-256 of the archive cannot be computed"
    return 1
  fi
  asset_hash=$(sha256_of "$temp_dir/asset") || asset_hash=
  if [ "$asset_hash" != "$built" ]; then
    draft_fault="the asset of the draft has the SHA-256 $asset_hash, and the archive that this run built has $built"
    return 1
  fi
}

read_tag_commit() {
  "$gh" api "repos/$repo/git/ref/tags/$1" >"$temp_dir/ref" &&
    jq -e -r '.object.sha' "$temp_dir/ref" >"$temp_dir/tag-commit"
}

verify_with_retries() {
  tries=0
  while :; do
    tries=$((tries + 1))
    "$@" </dev/null >/dev/null 2>"$temp_dir/error" && return 0
    [ "$tries" -lt 5 ] || return 1
    sleep "$retry_wait"
  done
}

select_line() {
  line=$(awk -F '\t' -v tag="$1" '($1 "-v" $2) == tag { print; exit }' "$temp_dir/lines")
  [ -n "$line" ] || stop "$1: the index has no line of this tag"
  IFS="$tab" read -r name version hash url text <<LINE
$line
LINE
  archive=$outdir/$name-$version.tar.gz
}

publish_one() {
  select_line "$1"
  is_hex "$2" 40 || stop "$1: the file of the tags gives no commit for this tag"
  if tag_exists "$1"; then
    stop_before_publication "$1" "the tag exists, and the release would take it at its commit"
  fi
  check_draft "$1" "$2" || stop_before_publication "$1" "$draft_fault"
  "$gh" release edit "$1" --draft=false --latest=false </dev/null >/dev/null 2>"$temp_dir/error" ||
    stop_at_publication "$1" "gh cannot publish the draft: $(error_line)"
  verify_with_retries read_tag_commit "$1" ||
    stop_after_publication "$1" "the commit of the tag cannot be read: $(error_line)"
  tag_commit=$(cat "$temp_dir/tag-commit")
  [ "$tag_commit" = "$2" ] ||
    stop_after_publication "$1" "the tag has the commit $tag_commit, and it must have the commit $2"
  "$curl_command" -fsSL --proto '=https' --retry 5 --retry-all-errors --retry-delay 5 \
    -o "$temp_dir/download" "$url" </dev/null 2>"$temp_dir/error" ||
    stop_after_publication "$1" "the archive cannot be downloaded from $url: $(error_line)"
  downloaded=$(sha256_of "$temp_dir/download")
  [ "$downloaded" = "$built" ] ||
    stop_after_publication "$1" "the file at $url has the SHA-256 $downloaded, and the archive that this run built has $built"
  verify_with_retries "$gh" release verify "$1" ||
    stop_after_publication "$1" "gh release verify does not accept the release: $(error_line)"
  verify_with_retries "$gh" release verify-asset "$1" "$archive" ||
    stop_after_publication "$1" "gh release verify-asset does not accept the archive: $(error_line)"
  printf 'Published %s.\n' "$1"
  write_summary "- $name $version: pack hash $hash, SHA-256 of the archive $built"
}

publish() {
  read_environment
  outdir=$1
  need_command "$curl_command"
  [ -f "$outdir/tags" ] || usage_error "$outdir holds no file tags"
  read_index
  while IFS="$tab" read -r line_tag target; do
    select_line "$line_tag"
    [ -f "$archive" ] || stop "$line_tag: $outdir holds no archive of this tag"
  done <"$outdir/tags"
  while IFS="$tab" read -r line_tag target; do
    publish_one "$line_tag" "$target"
  done <"$outdir/tags"
}

rehearse() {
  read_environment
  read_commit
  rehearsal_name=$2
  matches "$rehearsal_name" "$name_pattern" || usage_error "$rehearsal_name is not a name of a pack"
  if [ ! -d "$repository/packs/$rehearsal_name" ] || [ -L "$repository/packs/$rehearsal_name" ]; then
    usage_error "the repository has no folder packs/$rehearsal_name"
  fi
  read_tag_argument "$3"
  use_empty_outdir "$1"
  check_history
  extract_folder "$rehearsal_tag" "$rehearsal_name" "$commit" || stop "$rehearsal_tag: $source_fault"
  read_descriptor "$source_root/pack.toml" "$temp_dir/descriptor" 2>"$temp_dir/error" ||
    stop "packs/$rehearsal_name: the descriptor cannot be read: $(error_line)"
  version=$(descriptor_value "$temp_dir/descriptor" version) || version=
  matches "$version" "$release_pattern" ||
    stop "packs/$rehearsal_name: the descriptor gives the version \"$version\", which is not a release number"
  build_and_check "$rehearsal_name" "$version" "$source_root"
  folder_hash=$("$tools_dir/pack-hash.sh" "$repository/packs/$rehearsal_name" </dev/null)
  [ "$archive_hash" = "$folder_hash" ] ||
    stop "$rehearsal_tag: the archive has the pack hash $archive_hash, and packs/$rehearsal_name has the pack hash $folder_hash"
  make_draft "$rehearsal_tag" "$rehearsal_name" "$version" "$archive_hash" "$commit"
  if tag_exists "$rehearsal_tag"; then
    stop "$rehearsal_tag: the draft made a tag, so the design of the rehearsal does not hold: a draft of a release would make a tag that cannot change"
  fi
  check_draft "$rehearsal_tag" "$commit" || stop "$rehearsal_tag: $draft_fault"
  printf '%s\t%s\n' "$rehearsal_tag" "$commit" >"$outdir/tags"
  printf 'The rehearsal of %s %s passes with the tag %s.\n' "$rehearsal_name" "$version" "$rehearsal_tag"
  write_summary "- Rehearsal of $rehearsal_name $version with the tag $rehearsal_tag: pack hash $archive_hash, SHA-256 of the archive $built. The draft made no tag, and its asset has the bytes of the archive."
}

clean_rehearsal() {
  read_environment
  read_tag_argument "$1"
  list_releases
  if has_published_release "$rehearsal_tag"; then
    stop "$rehearsal_tag: a published release has this tag, and the tool deletes only a draft"
  fi
  draft_ids "$rehearsal_tag" >"$temp_dir/ids"
  while IFS= read -r id; do
    delete_release "$rehearsal_tag" "$id"
  done <"$temp_dir/ids"
  if tag_exists "$rehearsal_tag"; then
    "$gh" api -X DELETE "repos/$repo/git/refs/tags/$rehearsal_tag" </dev/null >/dev/null 2>"$temp_dir/error" ||
      stop "$rehearsal_tag: gh cannot delete the tag: $(error_line)"
    printf 'Deleted the tag %s.\n' "$rehearsal_tag"
  fi
  printf 'The rehearsal of the tag %s has left nothing on GitHub.\n' "$rehearsal_tag"
}

case $subcommand in
  prepare)
    [ "$#" -eq 1 ] || usage_error "prepare needs one OUTDIR"
    prepare "$1"
    ;;
  publish)
    [ "$#" -eq 1 ] || usage_error "publish needs one OUTDIR"
    publish "$1"
    ;;
  rehearse)
    [ "$#" -eq 3 ] || usage_error "rehearse needs OUTDIR, NAME, and TAG"
    rehearse "$1" "$2" "$3"
    ;;
  clean-rehearsal)
    [ "$#" -eq 1 ] || usage_error "clean-rehearsal needs one TAG"
    clean_rehearsal "$1"
    ;;
  *)
    usage_error "the command $subcommand is not known"
    ;;
esac
