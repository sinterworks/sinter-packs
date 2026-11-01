# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 The Sinter Authors

function stop(message) {
  printf "line %d: %s\n", L, message > "/dev/stderr"
  failed = 1
  exit 1
}

function ch() {
  return substr(S, P, 1)
}

function skip_blanks() {
  while (ch() == " " || ch() == "\t")
    P++
}

function skip_comment() {
  if (ch() == "#")
    while (P <= N && ch() != "\n")
      P++
}

function skip_lines() {
  while (1) {
    skip_blanks()
    skip_comment()
    if (P <= N && ch() == "\n") {
      P++
      L++
      continue
    }
    return
  }
}

function end_of_line() {
  skip_blanks()
  skip_comment()
  if (P > N)
    return
  if (ch() != "\n")
    stop("the line holds more text after its value")
  P++
  L++
}

function bare_key(   start, c) {
  start = P
  while (P <= N) {
    c = ch()
    if (c ~ /[A-Za-z0-9_-]/)
      P++
    else
      break
  }
  if (P == start) {
    if (c == "\"" || c == "'")
      stop("a quoted key")
    stop("a key or a table name is missing")
  }
  return substr(S, start, P - start)
}

function header_name(   name) {
  skip_blanks()
  name = bare_key()
  while (ch() == ".") {
    P++
    name = name "." bare_key()
  }
  skip_blanks()
  return name
}

function known_header(name, is_array) {
  if (is_array)
    return name == "grammar"
  if (name == "comments")
    return 1
  return name ~ /^runner\.[a-z][a-z0-9]*(-[a-z0-9]+)*(\.(match|settings|adapter))?$/
}

function header(   is_array, name) {
  P++
  is_array = 0
  if (ch() == "[") {
    is_array = 1
    P++
  }
  name = header_name()
  if (ch() != "]")
    stop("a table header that is not in the plain form")
  P++
  if (is_array) {
    if (ch() != "]")
      stop("a table header that is not in the plain form")
    P++
  }
  if (!known_header(name, is_array))
    stop("the table header " name " is not one that the descriptor has")
  if (is_array) {
    if (name in tables || name in seen)
      stop("the table " name " is written twice")
    arrays[name] = 1
    prefix = name "[" count[name]++ "]"
  } else {
    if (name in tables || name in arrays || name in seen)
      stop("the table " name " is written twice")
    tables[name] = 1
    prefix = name
  }
}

function key_value(   key, path) {
  key = bare_key()
  if (ch() == ".")
    stop("a dotted key")
  skip_blanks()
  if (ch() != "=")
    stop("a key with no = after it")
  P++
  skip_blanks()
  if (P > N || ch() == "\n" || ch() == "#")
    stop("the value of " key " is not on the line of its key")
  path = prefix == "" ? key : prefix "." key
  if (path in seen || path in tables || path in arrays)
    stop("the key " key " is written twice")
  seen[path] = 1
  value(path, key, 1)
}

function delimited(   c) {
  if (P > N)
    return 1
  c = ch()
  return c == " " || c == "\t" || c == "\n" || c == "," || c == "]" || c == "#"
}

function value(path, key, top,   c, start, escaped, text) {
  c = ch()
  if (c == "\"") {
    if (substr(S, P, 3) == "\"\"\"")
      stop("a multi-line string")
    P++
    start = P
    escaped = 0
    while (1) {
      if (P > N || ch() == "\n")
        stop("a string that does not end on its line")
      if (ch() == "\\") {
        escaped = 1
        P += 2
        continue
      }
      if (ch() == "\"")
        break
      P++
    }
    text = substr(S, start, P - start)
    P++
    if (top && key ~ /^(name|version|license|sha256)$/ && escaped)
      stop("an escape in the value of " key)
    if (top && !escaped)
      emit(path, text)
    return
  }
  if (c == "'") {
    if (substr(S, P, 3) == "'''")
      stop("a multi-line string")
    P++
    start = P
    while (1) {
      if (P > N || ch() == "\n")
        stop("a string that does not end on its line")
      if (ch() == "'")
        break
      P++
    }
    text = substr(S, start, P - start)
    P++
    if (top)
      emit(path, text)
    return
  }
  if (c == "[") {
    P++
    while (1) {
      skip_lines()
      if (P > N)
        stop("an array that does not end")
      if (ch() == "]") {
        P++
        return
      }
      value(path "[]", key, 0)
      skip_lines()
      if (ch() == ",") {
        P++
        continue
      }
      if (ch() == "]") {
        P++
        return
      }
      stop("an array that is not in the plain form")
    }
  }
  if (c == "{")
    stop("an inline table")
  if (substr(S, P, 4) == "true") {
    P += 4
    if (!delimited())
      stop("a value that is not in the plain form")
    return
  }
  if (substr(S, P, 5) == "false") {
    P += 5
    if (!delimited())
      stop("a value that is not in the plain form")
    return
  }
  if (c ~ /[-+0-9]/) {
    if (c == "-" || c == "+")
      P++
    start = P
    while (P <= N && ch() ~ /[0-9_]/)
      P++
    text = substr(S, start, P - start)
    if (text == "" || text ~ /^_|_$|__/ || !delimited())
      stop("a value that is not in the plain form")
    return
  }
  stop("a value that is not in the plain form")
}

function emit(path, text) {
  if (index(text, "\t"))
    stop("a tab in a string")
  print path "\t" text
}

{
  L = NR
  if (index($0, "\r"))
    stop("a carriage return")
  S = S $0 "\n"
}

END {
  if (failed)
    exit 1
  N = length(S)
  P = 1
  L = 1
  prefix = ""
  while (1) {
    skip_lines()
    if (P > N)
      break
    if (ch() == "[")
      header()
    else
      key_value()
    end_of_line()
  }
}
