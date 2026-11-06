; SPDX-License-Identifier: Apache-2.0
; Copyright 2026 The Sinter Authors

(
  (attribute_item
    (attribute . (identifier) @label.ignore))
  .
  [(attribute_item) (line_comment) (block_comment)]*
  .
  (attribute_item
    (attribute . [(identifier) (scoped_identifier)] @_test))
  .
  [(attribute_item) (line_comment) (block_comment)]*
  .
  (function_item
    name: (identifier) @name) @test
  (#any-of? @_test "test" "tokio::test" "rstest" "rstest::rstest")
  (#eq? @label.ignore "ignore"))

(
  (attribute_item
    (attribute . [(identifier) (scoped_identifier)] @_test))
  .
  [(attribute_item) (line_comment) (block_comment)]*
  .
  (attribute_item
    (attribute . (identifier) @label.ignore))
  .
  [(attribute_item) (line_comment) (block_comment)]*
  .
  (function_item
    name: (identifier) @name) @test
  (#any-of? @_test "test" "tokio::test" "rstest" "rstest::rstest")
  (#eq? @label.ignore "ignore"))

(
  (attribute_item
    (attribute . [(identifier) (scoped_identifier)] @_test))
  .
  [(attribute_item) (line_comment) (block_comment)]*
  .
  (function_item
    name: (identifier) @name) @test
  (#any-of? @_test "test" "tokio::test" "rstest" "rstest::rstest"))

(
  (attribute_item
    (attribute . (identifier) @_cfg
      arguments: (token_tree . (identifier) @_arg .)))
  .
  [(attribute_item) (line_comment) (block_comment)]*
  .
  (mod_item
    name: (identifier) @name) @group
  (#eq? @_cfg "cfg")
  (#eq? @_arg "test"))
