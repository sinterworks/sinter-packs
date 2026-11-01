#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 The Sinter Authors

set -eu
tool=pack-hash.sh
. "$(dirname -- "$0")/lib.sh"

usage() {
  cat <<'USAGE'
Usage: tools/pack-hash.sh PACK_ROOT

Print the pack hash of the folder PACK_ROOT: the SHA-256 of the list of
the files of the pack, each with its SHA-256, in the byte order of the
paths.

The command fails when the folder holds an entry that is not a file or a
folder, or a path with a character outside printable ASCII or with a
backslash.

Exit codes: 0 when it prints the hash, 1 when the folder cannot have a
pack hash, 2 when the command line is wrong, 3 when a command that the
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
[ "$#" -eq 1 ] || usage_error "give one folder"
[ -d "$1" ] || usage_error "$1 is not a folder"
make_temp_dir
pack_hash "$1"
