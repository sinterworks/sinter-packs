; SPDX-License-Identifier: Apache-2.0
; Copyright 2026 The Sinter Authors

(call_expression
  function: [(identifier) @_fn
             (member_expression
               object: (identifier) @_fn
               property: [(property_identifier) @label.skip
                          (property_identifier) @label.only
                          (property_identifier) @label.todo])
             (call_expression
               function: (member_expression
                 object: (identifier) @_fn
                 property: (property_identifier) @label.each))]
  arguments: (arguments .
    (string [(string_fragment) @name (escape_sequence) @placeholder]*))
  (#any-of? @_fn "it" "test")
  (#eq? @label.skip "skip")
  (#eq? @label.only "only")
  (#eq? @label.todo "todo")
  (#eq? @label.each "each")) @test

(call_expression
  function: [(identifier) @_fn
             (member_expression
               object: (identifier) @_fn
               property: [(property_identifier) @label.skip
                          (property_identifier) @label.only
                          (property_identifier) @label.todo])
             (call_expression
               function: (member_expression
                 object: (identifier) @_fn
                 property: (property_identifier) @label.each))]
  arguments: (arguments .
    (template_string [(string_fragment) @name (escape_sequence) @placeholder
                      (template_substitution) @placeholder]*))
  (#any-of? @_fn "it" "test")
  (#eq? @label.skip "skip")
  (#eq? @label.only "only")
  (#eq? @label.todo "todo")
  (#eq? @label.each "each")) @test

(call_expression
  function: [(identifier) @_fn
             (member_expression
               object: (identifier) @_fn
               property: [(property_identifier) @label.skip
                          (property_identifier) @label.only
                          (property_identifier) @label.todo])
             (call_expression
               function: (member_expression
                 object: (identifier) @_fn
                 property: (property_identifier) @label.each))]
  arguments: (arguments .
    [(identifier) (member_expression) (subscript_expression) (call_expression)
     (binary_expression) (ternary_expression) (parenthesized_expression)
     (as_expression) (non_null_expression) (satisfies_expression)] @placeholder)
  (#any-of? @_fn "it" "test")
  (#eq? @label.skip "skip")
  (#eq? @label.only "only")
  (#eq? @label.todo "todo")
  (#eq? @label.each "each")) @test

(call_expression
  function: [(identifier) @_fn
             (member_expression
               object: (identifier) @_fn
               property: [(property_identifier) @label.skip
                          (property_identifier) @label.only
                          (property_identifier) @label.todo])
             (call_expression
               function: (member_expression
                 object: (identifier) @_fn
                 property: (property_identifier) @label.each))]
  arguments: (arguments .
    (string [(string_fragment) @name (escape_sequence) @placeholder]*))
  (#eq? @_fn "describe")
  (#eq? @label.skip "skip")
  (#eq? @label.only "only")
  (#eq? @label.todo "todo")
  (#eq? @label.each "each")) @group

(call_expression
  function: [(identifier) @_fn
             (member_expression
               object: (identifier) @_fn
               property: [(property_identifier) @label.skip
                          (property_identifier) @label.only
                          (property_identifier) @label.todo])
             (call_expression
               function: (member_expression
                 object: (identifier) @_fn
                 property: (property_identifier) @label.each))]
  arguments: (arguments .
    (template_string [(string_fragment) @name (escape_sequence) @placeholder
                      (template_substitution) @placeholder]*))
  (#eq? @_fn "describe")
  (#eq? @label.skip "skip")
  (#eq? @label.only "only")
  (#eq? @label.todo "todo")
  (#eq? @label.each "each")) @group

(call_expression
  function: [(identifier) @_fn
             (member_expression
               object: (identifier) @_fn
               property: [(property_identifier) @label.skip
                          (property_identifier) @label.only
                          (property_identifier) @label.todo])
             (call_expression
               function: (member_expression
                 object: (identifier) @_fn
                 property: (property_identifier) @label.each))]
  arguments: (arguments .
    [(identifier) (member_expression) (subscript_expression) (call_expression)
     (binary_expression) (ternary_expression) (parenthesized_expression)
     (as_expression) (non_null_expression) (satisfies_expression)] @placeholder)
  (#eq? @_fn "describe")
  (#eq? @label.skip "skip")
  (#eq? @label.only "only")
  (#eq? @label.todo "todo")
  (#eq? @label.each "each")) @group
