; SPDX-License-Identifier: Apache-2.0
; Copyright 2026 The Sinter Authors

(application_expression
  function: (value_path) @_fn
  .
  argument: (string [(string_content) @name (string_content) @placeholder]?)
  .
  argument: (tag) @label.slow
  (#not-match? @name "\\\\")
  (#match? @placeholder "\\\\")
  (#any-of? @_fn "Alcotest.test_case" "test_case")
  (#eq? @label.slow "`Slow")) @test

(application_expression
  function: (value_path) @_fn
  .
  argument: (quoted_string (quoted_string_content)? @name)
  .
  argument: (tag) @label.slow
  (#any-of? @_fn "Alcotest.test_case" "test_case")
  (#eq? @label.slow "`Slow")) @test

(application_expression
  function: (value_path) @_fn
  .
  argument: [(value_path) (parenthesized_expression) (field_get_expression)] @placeholder
  .
  argument: (tag) @label.slow
  (#any-of? @_fn "Alcotest.test_case" "test_case")
  (#eq? @label.slow "`Slow")) @test

(application_expression
  function: (value_path) @_fn
  .
  argument: (string [(string_content) @name (string_content) @placeholder]?)
  .
  argument: (_)
  (#not-match? @name "\\\\")
  (#match? @placeholder "\\\\")
  (#any-of? @_fn "Alcotest.test_case" "test_case")) @test

(application_expression
  function: (value_path) @_fn
  .
  argument: (quoted_string (quoted_string_content)? @name)
  .
  argument: (_)
  (#any-of? @_fn "Alcotest.test_case" "test_case")) @test

(application_expression
  function: (value_path) @_fn
  .
  argument: [(value_path) (parenthesized_expression) (field_get_expression)] @placeholder
  .
  argument: (_)
  (#any-of? @_fn "Alcotest.test_case" "test_case")) @test

(application_expression
  function: (value_path) @_fn
  argument: (labeled_argument
    (label_name) @_label
    expression: (string [(string_content) @name (string_content) @placeholder]?))
  (#eq? @_fn "QCheck.Test.make")
  (#eq? @_label "name")
  (#not-match? @name "\\\\")
  (#match? @placeholder "\\\\")) @test

(application_expression
  function: (value_path) @_fn
  argument: (labeled_argument
    (label_name) @_label
    expression: (quoted_string (quoted_string_content)? @name))
  (#eq? @_fn "QCheck.Test.make")
  (#eq? @_label "name")) @test

(application_expression
  function: (value_path) @_fn
  argument: (labeled_argument
    (label_name) @_label
    expression: [(value_path) (parenthesized_expression) (field_get_expression)] @placeholder)
  (#eq? @_fn "QCheck.Test.make")
  (#eq? @_label "name")) @test

(application_expression
  function: (value_path) @_fn
  argument: (labeled_argument
    (label_name) @placeholder
    !expression)
  (#eq? @_fn "QCheck.Test.make")
  (#eq? @placeholder "name")) @test

(application_expression
  function: (value_path) @_fn
  argument: (list_expression
    (tuple_expression
      .
      (string [(string_content) @name (string_content) @placeholder]?)
      .
      (list_expression)
      .) @group)
  (#eq? @_fn "Alcotest.run")
  (#not-match? @name "\\\\")
  (#match? @placeholder "\\\\"))

(application_expression
  function: (value_path) @_fn
  argument: (list_expression
    (parenthesized_expression
      (tuple_expression
        .
        (string [(string_content) @name (string_content) @placeholder]?)
        .
        (list_expression)
        .) @group))
  (#eq? @_fn "Alcotest.run")
  (#not-match? @name "\\\\")
  (#match? @placeholder "\\\\"))

(application_expression
  function: (value_path) @_fn
  argument: (list_expression
    (tuple_expression
      .
      (quoted_string (quoted_string_content)? @name)
      .
      (list_expression)
      .) @group)
  (#eq? @_fn "Alcotest.run"))

(application_expression
  function: (value_path) @_fn
  argument: (list_expression
    (parenthesized_expression
      (tuple_expression
        .
        (quoted_string (quoted_string_content)? @name)
        .
        (list_expression)
        .) @group))
  (#eq? @_fn "Alcotest.run"))

(application_expression
  function: (value_path) @_fn
  argument: (list_expression
    (tuple_expression
      .
      [(value_path) (parenthesized_expression) (field_get_expression)
       (application_expression) (infix_expression)] @placeholder
      .
      (list_expression)
      .) @group)
  (#eq? @_fn "Alcotest.run"))

(application_expression
  function: (value_path) @_fn
  argument: (list_expression
    (parenthesized_expression
      (tuple_expression
        .
        [(value_path) (parenthesized_expression) (field_get_expression)
         (application_expression) (infix_expression)] @placeholder
        .
        (list_expression)
        .) @group))
  (#eq? @_fn "Alcotest.run"))
