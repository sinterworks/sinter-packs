#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 The Sinter Authors

set -eu
tool=build-archive.sh
. "$(dirname -- "$0")/lib.sh"

usage() {
  cat <<'USAGE'
Usage: tools/build-archive.sh PACK_ROOT ARCHIVE

Write the archive of the folder PACK_ROOT to the file ARCHIVE: a tar file
in the ustar form, compressed with gzip. The archive has one entry for
each regular file, in the byte order of the paths, and no entry for a
folder. The owner, the group, and the time of each entry are 0. The same
files with the same executable bits give the same bytes on each run.

The tool needs GNU tar. It writes nothing when the folder holds an entry
that is not a file or a folder, or a path with a character outside
printable ASCII or with a backslash. It also writes nothing when tar
cannot write the ustar form of a path.

Exit codes: 0 when it writes the archive, 1 when the folder cannot have
an archive, 2 when the command line is wrong, 3 when a command that the
tool needs is missing.
USAGE
}

while getopts h option; do
  case $option in
    h) usage; exit 0 ;;
    *) usage_error "the option is not known" ;;
  esac
done
shift $((OPTIND - 1))
[ "$#" -eq 2 ] || usage_error "give one pack folder and one archive"
root=$1
archive=$2
[ -d "$root" ] || usage_error "$root is not a folder"
[ -d "$(dirname -- "$archive")" ] || usage_error "the folder of $archive does not exist"
need_command tar
need_command gzip
case $(tar --version 2>/dev/null | head -n 1) in
  *"GNU tar"*) ;;
  *) fatal "this tool needs GNU tar, and the command tar is another program" ;;
esac
unset TAR_OPTIONS TAPE GZIP
make_temp_dir

(
  cd -- "$root" || exit 3
  check_pack_entries
  find . -type f | sed 's|^\./||' | sort >"$temp_dir/list"
  if ! tar --format=ustar --owner=0 --group=0 --numeric-owner --mtime=@0 \
    --mode=u+rw,go-w,a+rX --no-recursion --verbatim-files-from \
    -T "$temp_dir/list" -cf - >"$temp_dir/data" 2>"$temp_dir/error"; then
    printf 'tar cannot write the archive: %s\n' "$(head -n 1 "$temp_dir/error")" >&2
    exit 1
  fi
)
gzip -n -9 <"$temp_dir/data" >"$temp_dir/archive"
mv -- "$temp_dir/archive" "$archive"
