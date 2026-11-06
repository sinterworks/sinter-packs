#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 The Sinter Authors

set -eu
tool=check-archive.sh
. "$(dirname -- "$0")/lib.sh"

usage() {
  cat <<'USAGE'
Usage: tools/check-archive.sh ARCHIVE

Check that the file ARCHIVE is a correct archive of a pack, and print its
pack hash on one line. The tool computes the hash from the paths and the
contents of the entries of the regular files. It extracts no file.

  - The archive has at most 64 MiB, and it is gzip data whose CRC-32 and
    size are correct. The size in the last trailer equals the length of
    the tar data. These checks do not prove that the archive is one gzip
    member in every case: an empty member before the last member passes.
  - The tar data has at most 128 MiB. It is a sequence of entries, then
    two blocks of zero bytes, and after them only zero bytes.
  - An entry is a header of one block, then its content. Zero bytes fill
    the last block of the content.
  - Each header has the ustar form, with a correct checksum. Each numeric
    field holds octal digits, then NUL bytes or spaces. The fields size
    and chksum hold at least one digit.
  - Each entry is a regular file, with the type 0 or NUL, or a folder,
    with the type 5 and the size 0.
  - The fields name and prefix end at their first NUL byte, and only NUL
    bytes follow it. The name is not empty. The path of a folder ends
    with one /, and the path of a regular file does not.
  - Each path holds only printable ASCII and no backslash, does not start
    with /, holds no empty name and no name . or .., and has at most 255
    bytes. No path is both a file and a folder. No two paths are equal
    after ASCII case folding. No path occurs in two entries. Below each
    folder that has an entry, the archive holds a regular file.
  - The archive has at most 4096 entries, and each path has at most 16
    names.

Exit codes: 0 when the archive passes, 1 when the archive is broken, 2
when the command line is wrong, 3 when a command that the tool needs is
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
[ "$#" -eq 1 ] || usage_error "give one archive"
archive=$1
[ -f "$archive" ] || usage_error "$archive is not a file"
need_command gzip
need_command od
command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 ||
  fatal "this check needs sha256sum or shasum, and neither is installed"
unset GZIP
make_temp_dir

refuse() {
  printf '%s\n' "$1" >&2
  exit 1
}

most_archive=67108864
most_data=134217728
tab=$(printf '\t')

size=$(wc -c <"$archive" | tr -d ' ')
[ "$size" -le "$most_archive" ] || refuse "the archive has $size bytes, which is more than 64 MiB"
start=$(head -c 3 <"$archive" | od -An -v -tu1 | awk 'NF { print $1, $2, $3 }')
[ "$start" = "31 139 8" ] || refuse "the archive is not gzip data"
gzip -dc <"$archive" 2>/dev/null | head -c "$((most_data + 1))" >"$temp_dir/data"
data_size=$(wc -c <"$temp_dir/data" | tr -d ' ')
[ "$data_size" -le "$most_data" ] || refuse "the tar data has more than 128 MiB"
gzip -t <"$archive" 2>"$temp_dir/error" ||
  refuse "the gzip data is not correct: $(head -n 1 "$temp_dir/error")"
trailer=$(tail -c 4 <"$archive" | od -An -v -tu1 |
  awk 'NF { printf "%.0f", $1 + 256 * $2 + 65536 * $3 + 16777216 * $4 }')
[ "$trailer" = "$data_size" ] ||
  refuse "the size in the gzip trailer is $trailer, and the tar data has $data_size bytes, so the archive is more than one gzip member"

cd -- "$temp_dir"
TAR_DATA_SIZE=$data_size awk -f "$tools_dir/archive.awk" </dev/null >entries || exit 1
sort -t "$tab" -k1,1 entries >sorted
: >listing
while IFS="$tab" read -r path offset count; do
  if [ "$count" -eq 0 ]; then
    hash=$(sha256_of /dev/null)
  else
    hash=$(tail -c +"$((offset + 1))" data 2>/dev/null | head -c "$count" | sha256_of_stdin)
  fi
  is_hex "$hash" 64 || fatal "the SHA-256 of an entry cannot be computed"
  printf '%s  %s\n' "$hash" "$path" >>listing
done <sorted
sha256_of listing
