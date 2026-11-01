# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 The Sinter Authors

function stop(message) {
  printf "%s\n", message > "/dev/stderr"
  failed = 1
  exit 1
}

function quoted(text) {
  if (index(text, "'"))
    stop("the path of the file holds a quote, and the tool cannot read such a path")
  return "'" text "'"
}

function load(chunk,   start, count, command, line, fields, k, j, i) {
  start = chunk * CHUNK
  count = limit - start
  if (count > CHUNK)
    count = CHUNK
  command = "od -An -v -tu1 -j " start " -N " count " -- " quoted(file)
  i = start
  while ((command | getline line) > 0) {
    k = split(line, fields, " ")
    for (j = 1; j <= k; j++)
      B[i++] = fields[j] + 0
  }
  close(command)
  if (i != start + count)
    stop("the file cannot be read")
  loaded[chunk] = 1
}

function byte(offset,   chunk) {
  if (offset < 0 || offset >= limit)
    stop("the module is cut short")
  if (mode == "file") {
    chunk = int(offset / CHUNK)
    if (!(chunk in loaded))
      load(chunk)
  }
  return B[offset]
}

function leb(signed,   result, shift, b, count) {
  result = 0
  shift = 1
  count = 0
  while (1) {
    b = byte(at++)
    count++
    result += (b % 128) * shift
    shift *= 128
    if (b < 128)
      break
    if (count == 10)
      stop("a number of the module is too long")
  }
  if (signed && b >= 64)
    result -= shift
  return result
}

function name(   length_, text, b, i, plain) {
  length_ = leb(0)
  if (at + length_ > limit)
    stop("the module is cut short")
  text = ""
  plain = 1
  for (i = 0; i < length_; i++) {
    b = byte(at++)
    if (b < 33 || b > 126)
      plain = 0
    else
      text = text sprintf("%c", b)
  }
  if (!plain)
    return "\n"
  return text
}

function printable(text, what) {
  if (text == "\n")
    stop("the module has " what " that is not printable ASCII")
  return text
}

function limits_(   flags) {
  flags = byte(at++)
  leb(0)
  if (flags % 2 == 1)
    leb(0)
}

function read_imports(end_,   count, i, module_, field, kind) {
  count = leb(0)
  for (i = 0; i < count; i++) {
    module_ = printable(name(), "an import module name")
    field = printable(name(), "an import name")
    kind = byte(at++)
    if (kind == 0) {
      leb(0)
      function_imports++
      print "import\t" module_ "\t" field "\tfunc"
    } else if (kind == 1) {
      at++
      limits_()
      print "import\t" module_ "\t" field "\ttable"
    } else if (kind == 2) {
      limits_()
      print "import\t" module_ "\t" field "\tmemory"
    } else if (kind == 3) {
      at += 2
      if (field == "__memory_base")
        memory_base = global_imports
      global_imports++
      print "import\t" module_ "\t" field "\tglobal"
    } else if (kind == 4) {
      at++
      leb(0)
      print "import\t" module_ "\t" field "\ttag"
    } else {
      stop("an import of an unknown kind")
    }
  }
  if (at != end_)
    stop("the import section does not have the length that it states")
}

function read_exports(end_,   count, i, field, kind, index_) {
  count = leb(0)
  for (i = 0; i < count; i++) {
    field = printable(name(), "an export name")
    kind = byte(at++)
    index_ = leb(0)
    if (kind == 0)
      exported_function[field] = index_
    print "export\t" field "\t" (kind == 0 ? "func" : kind == 1 ? "table" : kind == 2 ? "memory" : kind == 3 ? "global" : "other")
  }
  if (at != end_)
    stop("the export section does not have the length that it states")
}

function read_features(end_,   count, i, prefix, feature) {
  count = leb(0)
  for (i = 0; i < count; i++) {
    prefix = byte(at++)
    feature = printable(name(), "a target feature")
    if (prefix != 43 && prefix != 45 && prefix != 61)
      stop("the target features section is not in its form")
    print "feature\t" sprintf("%c", prefix) "\t" feature
  }
  if (at != end_)
    stop("the target features section does not have the length that it states")
}

function sections(   id, length_, end_, section_name) {
  at = 0
  if (byte(0) != 0 || byte(1) != 97 || byte(2) != 115 || byte(3) != 109)
    stop("the file is not a WebAssembly module")
  if (byte(4) != 1 || byte(5) != 0 || byte(6) != 0 || byte(7) != 0)
    stop("the file is not a WebAssembly module of version 1")
  at = 8
  memory_base = -1
  code_at = -1
  data_at = -1
  while (at < limit) {
    id = byte(at++)
    length_ = leb(0)
    end_ = at + length_
    if (end_ > limit)
      stop("the module is cut short")
    if (id == 0) {
      section_name = name()
      if (section_name == "target_features")
        read_features(end_)
    } else if (id == 2) {
      read_imports(end_)
    } else if (id == 7) {
      read_exports(end_)
    } else if (id == 10) {
      code_at = at
    } else if (id == 11) {
      data_at = at
    }
    at = end_
  }
}

function address(   b, g) {
  b = byte(at++)
  if (b == 35) {
    g = leb(0)
    if (g != memory_base)
      return "no"
    if (byte(at++) != 65)
      return "no"
    offset_ = leb(1)
    if (byte(at++) != 106)
      return "no"
    relative = 1
  } else if (b == 65) {
    offset_ = leb(1)
    relative = 0
  } else {
    return "no"
  }
  if (byte(at++) != 11)
    return "no"
  return "yes"
}

function segment_base(   b, g, depth) {
  depth = 0
  while (1) {
    b = byte(at++)
    if (b == 11)
      break
    if (b == 65) {
      depth++
      V[depth] = leb(1)
      R[depth] = 0
      K[depth] = 1
    } else if (b == 35) {
      g = leb(0)
      depth++
      V[depth] = 0
      R[depth] = 1
      K[depth] = g == memory_base
    } else if (b == 106 && depth >= 2) {
      V[depth - 1] += V[depth]
      R[depth - 1] += R[depth]
      K[depth - 1] = K[depth - 1] && K[depth]
      depth--
    } else {
      stop("the data section holds an offset that this tool does not read")
    }
  }
  if (depth != 1)
    stop("the data section holds an offset that this tool does not read")
  base_ = V[1]
  base_relative = R[1]
  if (K[1] && R[1] <= 1)
    return "yes"
  return "no"
}

function abi(   wanted, body, count, i, length_, locals, start, flags, readable, value_) {
  wanted = "tree_sitter_" grammar
  if (!(wanted in exported_function))
    stop("the module exports no function " wanted)
  body = exported_function[wanted] - function_imports
  if (body < 0 || code_at < 0)
    stop("the module does not define the function " wanted)
  at = code_at
  count = leb(0)
  if (body >= count)
    stop("the module does not define the function " wanted)
  for (i = 0; i < body; i++) {
    length_ = leb(0)
    at += length_
  }
  leb(0)
  locals = leb(0)
  for (i = 0; i < locals; i++) {
    leb(0)
    at++
  }
  if (address() != "yes")
    stop("the ABI version cannot be read: the function " wanted " does not return the address of a constant")
  if (data_at < 0)
    stop("the ABI version cannot be read: the module has no data")
  at = data_at
  count = leb(0)
  for (i = 0; i < count; i++) {
    flags = leb(0)
    readable = "no"
    if (flags == 0) {
      readable = segment_base()
    } else if (flags == 2) {
      leb(0)
      readable = segment_base()
    } else if (flags != 1) {
      stop("the data section is not in its form")
    }
    length_ = leb(0)
    start = at
    if (readable == "yes" && base_relative == relative && base_ <= offset_ && offset_ + 4 <= base_ + length_) {
      at = start + offset_ - base_
      value_ = byte(at) + 256 * byte(at + 1) + 65536 * byte(at + 2) + 16777216 * byte(at + 3)
      print "abi\t" value_
      return
    }
    at = start + length_
  }
  stop("the ABI version cannot be read: no data holds the address that " wanted " returns")
}

function hex(text,   digits) {
  digits = "0123456789abcdef"
  text = tolower(text)
  return (index(digits, substr(text, 1, 1)) - 1) * 16 + index(digits, substr(text, 2, 1)) - 1
}

BEGIN {
  CHUNK = 16384
  file = ENVIRON["WASM_FILE"]
  mode = ENVIRON["WASM_MODE"]
  grammar = ENVIRON["WASM_GRAMMAR"]
  if (mode == "file")
    limit = ENVIRON["WASM_SIZE"] + 0
}

mode == "header" && /STDLIB_WASM\[\] = \{/ {
  inside = 1
  found = 1
  next
}

mode == "header" && inside && /^\};/ {
  inside = 0
  next
}

mode == "header" && inside {
  line = $0
  while (match(line, /0x[0-9a-fA-F][0-9a-fA-F]/)) {
    B[limit++] = hex(substr(line, RSTART + 2, 2))
    line = substr(line, RSTART + RLENGTH)
  }
}

END {
  if (failed)
    exit 1
  if (mode == "header" && !found)
    stop("the file holds no array STDLIB_WASM")
  sections()
  if (grammar != "")
    abi()
}
