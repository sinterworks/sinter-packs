# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 The Sinter Authors

function stop(message) {
  printf "%s\n", message > "/dev/stderr"
  exit 1
}

function load(chunk,   start, count, command, line, fields, k, j, i) {
  start = chunk * CHUNK
  count = limit - start
  if (count > CHUNK)
    count = CHUNK
  split("", B)
  command = "od -An -v -tu1 -j " start " -N " count " -- data"
  i = start
  while ((command | getline line) > 0) {
    k = split(line, fields, " ")
    for (j = 1; j <= k; j++)
      B[i++] = fields[j] + 0
  }
  close(command)
  if (i != start + count)
    stop("the tar data cannot be read")
  current = chunk
}

function byte(offset,   chunk) {
  chunk = int(offset / CHUNK)
  if (chunk != current)
    load(chunk)
  return B[offset]
}

function read_block(offset,   i) {
  for (i = 0; i < 512; i++)
    H[i] = byte(offset + i)
}

function block_is_zero(   i) {
  for (i = 0; i < 512; i++)
    if (H[i] != 0)
      return 0
  return 1
}

function shown_field(offset, width,   i, text) {
  text = ""
  for (i = offset; i < offset + width && H[i] != 0; i++)
    text = text ((H[i] in CHAR) ? CHAR[H[i]] : "?")
  return text
}

function set_label(   name_, prefix) {
  name_ = shown_field(0, 100)
  prefix = shown_field(345, 155)
  label = "the entry " entries
  if (prefix != "")
    label = label " (" prefix "/" name_ ")"
  else if (name_ != "")
    label = label " (" name_ ")"
}

function fail(message) {
  stop(label ": " message)
}

function check_fixed(field, offset, wanted, words,   i, n, codes) {
  n = split(wanted, codes, " ")
  for (i = 0; i < n; i++)
    if (H[offset + i] != codes[i + 1] + 0)
      fail("the field " field " does not hold " words)
}

function octal(field, offset, width, needs_digit,   i, b, digits, filler, value) {
  digits = 0
  filler = 0
  value = 0
  for (i = offset; i < offset + width; i++) {
    b = H[i]
    if (b >= 48 && b <= 55) {
      if (filler)
        fail("the field " field " holds an octal digit after a NUL byte or a space")
      digits++
      value = value * 8 + b - 48
    } else if (b == 0 || b == 32) {
      filler = 1
    } else {
      fail("the field " field " holds a byte that is not an octal digit, a NUL byte, or a space")
    }
  }
  if (needs_digit && digits == 0)
    fail("the field " field " holds no octal digit")
  return value
}

function header_sum(   i, sum) {
  sum = 0
  for (i = 0; i < 512; i++)
    sum += (i >= 148 && i < 156) ? 32 : H[i]
  return sum
}

function text_field(field, offset, width,   i, end_, text) {
  end_ = offset + width
  for (i = offset; i < offset + width; i++) {
    if (H[i] == 0) {
      end_ = i
      break
    }
  }
  for (i = end_; i < offset + width; i++)
    if (H[i] != 0)
      fail("the field " field " holds another byte after its first NUL byte")
  text = ""
  for (i = offset; i < end_; i++) {
    if (!(H[i] in CHAR))
      fail("the field " field " holds a byte outside printable ASCII")
    if (H[i] == 92)
      fail("the field " field " holds a backslash")
    text = text CHAR[H[i]]
  }
  return text
}

function check_path(path,   names, count, i) {
  if (path == "")
    fail("the path of the folder is empty")
  if (length(path) > 255)
    fail("the path has more than 255 bytes")
  if (substr(path, 1, 1) == "/")
    fail("the path starts with /")
  count = split(path, names, "/")
  for (i = 1; i <= count; i++) {
    if (names[i] == "")
      fail("the path holds an empty name")
    if (names[i] == "." || names[i] == "..")
      fail("the path holds the name " names[i])
  }
  if (count > 16)
    fail("the path has more than 16 names")
  return count
}

function add_path(path, kind,   folded) {
  if (path in KIND) {
    if (KIND[path] != kind)
      fail("the path " path " is the path of a file and also of a folder")
    return
  }
  folded = tolower(path)
  if (folded in FOLDED)
    fail("the paths " FOLDED[folded] " and " path " are equal after ASCII case folding")
  FOLDED[folded] = path
  KIND[path] = kind
}

function add_entry(path, is_folder,   count, names, i, parent) {
  count = check_path(path)
  if (path in ENTERED)
    fail("the path " path " occurs in two entries")
  ENTERED[path] = 1
  split(path, names, "/")
  parent = ""
  for (i = 1; i < count; i++) {
    parent = (i == 1) ? names[i] : parent "/" names[i]
    add_path(parent, "folder")
    if (!is_folder)
      HOLDS_FILE[parent] = 1
  }
  add_path(path, is_folder ? "folder" : "file")
  if (is_folder)
    FOLDERS[++folder_count] = path
}

function read_entry(   type, size, sum, name_, prefix, path, is_folder, blocks, i) {
  entries++
  set_label()
  if (entries > 4096)
    stop("the archive has more than 4096 entries")
  check_fixed("magic", 257, "117 115 116 97 114 0", "ustar and a NUL byte")
  check_fixed("version", 263, "48 48", "00")
  octal("mode", 100, 8, 0)
  octal("uid", 108, 8, 0)
  octal("gid", 116, 8, 0)
  size = octal("size", 124, 12, 1)
  octal("mtime", 136, 12, 0)
  sum = octal("chksum", 148, 8, 1)
  octal("devmajor", 329, 8, 0)
  octal("devminor", 337, 8, 0)
  if (sum != header_sum())
    fail("the field chksum does not hold the sum of the bytes of the header")
  type = H[156]
  if (type != 48 && type != 0 && type != 53) {
    fail("the type " ((type in CHAR) ? CHAR[type] : "with the byte value " type) " is not a regular file or a folder")
  }
  is_folder = (type == 53)
  name_ = text_field("name", 0, 100)
  prefix = text_field("prefix", 345, 155)
  if (name_ == "")
    fail("the field name is empty")
  path = (prefix == "") ? name_ : prefix "/" name_
  if (is_folder) {
    if (substr(path, length(path)) != "/")
      fail("the path of the folder does not end with /")
    path = substr(path, 1, length(path) - 1)
    if (size != 0)
      fail("the entry of a folder has a size that is not 0")
  } else if (substr(path, length(path)) == "/") {
    fail("the path of the regular file ends with /")
  }
  add_entry(path, is_folder)
  blocks = int((size + 511) / 512)
  if (at + 512 + blocks * 512 > limit)
    fail("the content is cut short")
  for (i = at + 512 + size; i < at + 512 + blocks * 512; i++)
    if (byte(i) != 0)
      fail("a byte after the content in its last block is not zero")
  if (!is_folder)
    printf "%s\t%d\t%d\n", path, at + 512, size
  at += 512 + blocks * 512
}

function check_rest(   command, count) {
  command = "tail -c +" (at + 1) " data | tr -d '\\000' | wc -c"
  if ((command | getline count) <= 0)
    stop("the tar data cannot be read")
  close(command)
  if (count + 0 != 0)
    stop("the tar data holds a byte that is not zero after the end marker")
}

BEGIN {
  CHUNK = 16384
  current = -1
  limit = ENVIRON["TAR_DATA_SIZE"] + 0
  for (i = 32; i <= 126; i++)
    CHAR[i] = sprintf("%c", i)
  at = 0
  while (1) {
    if (at + 512 > limit)
      stop("the tar data has no end marker")
    read_block(at)
    if (block_is_zero())
      break
    read_entry()
  }
  if (at + 1024 > limit)
    stop("the tar data has no end marker")
  read_block(at + 512)
  if (!block_is_zero())
    stop("the tar data has no end marker: a block of zero bytes comes before a block that is not zero")
  at += 1024
  check_rest()
  for (i = 1; i <= folder_count; i++)
    if (!(FOLDERS[i] in HOLDS_FILE))
      stop("the entry of the folder " FOLDERS[i] " has no regular file below it")
}
