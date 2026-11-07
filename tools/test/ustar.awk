# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 The Sinter Authors

function put(offset, width, value,   n, i, c, code) {
  for (i = 0; i < width; i++)
    H[offset + i] = 0
  n = 0
  for (i = 1; i <= length(value); i++) {
    c = substr(value, i, 1)
    if (c == "\\") {
      code = substr(value, i + 1, 1) * 64 + substr(value, i + 2, 1) * 8 + substr(value, i + 3, 1)
      i += 3
    } else {
      code = ORD[c]
    }
    if (n >= width) {
      printf "the value %s is too long for its field\n", value > "/dev/stderr"
      exit 3
    }
    H[offset + n++] = code
  }
}

function emit(   i, text, sum) {
  if (!(148 in GIVEN)) {
    put(148, 8, "        ")
    sum = 0
    for (i = 0; i < 512; i++)
      sum += H[i]
    put(148, 8, sprintf(FORM, sum))
  }
  text = ""
  for (i = 0; i < 512; i++)
    text = text CHR[H[i]]
  printf "%s", text
}

BEGIN {
  for (i = 2; i < 256; i++) {
    CHR[i] = sprintf("%c", i)
    ORD[CHR[i]] = i
  }
  CHR[0] = sprintf("%c", 1)
  split("name 0 100 mode 100 8 uid 108 8 gid 116 8 size 124 12 mtime 136 12 chksum 148 8 type 156 1 linkname 157 100 magic 257 6 version 263 2 uname 265 32 gname 297 32 devmajor 329 8 devminor 337 8 prefix 345 155", spec, " ")
  for (i = 1; i in spec; i += 3) {
    OFFSET[spec[i]] = spec[i + 1] + 0
    WIDTH[spec[i]] = spec[i + 2] + 0
  }
}

{
  split("", H)
  split("", GIVEN)
  FORM = "%06o\\000 "
  for (i = 0; i < 512; i++)
    H[i] = 0
  put(100, 8, "0000644\\000")
  put(108, 8, "0000000\\000")
  put(116, 8, "0000000\\000")
  put(124, 12, "00000000000\\000")
  put(136, 12, "00000000000\\000")
  put(156, 1, "0")
  put(257, 6, "ustar\\000")
  put(263, 2, "00")
  put(329, 8, "0000000\\000")
  put(337, 8, "0000000\\000")
  count = split($0, parts, "\t")
  for (p = 1; p <= count; p++) {
    at = index(parts[p], "=")
    key = substr(parts[p], 1, at - 1)
    value = substr(parts[p], at + 1)
    if (key == "length") {
      put(124, 12, sprintf("%011o", value + 0) "\\000")
    } else if (key == "chksum-form") {
      FORM = value
    } else if (key in OFFSET) {
      put(OFFSET[key], WIDTH[key], value)
      GIVEN[OFFSET[key]] = 1
    } else {
      printf "the field %s is not known\n", key > "/dev/stderr"
      exit 3
    }
  }
  emit()
}
