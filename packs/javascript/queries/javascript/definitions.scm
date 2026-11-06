; SPDX-License-Identifier: Apache-2.0
; Copyright 2026 The Sinter Authors

(function_declaration
  name: (identifier) @name
  body: (statement_block) @body) @definition

(generator_function_declaration
  name: (identifier) @name
  body: (statement_block) @body) @definition

(class_declaration
  name: (identifier) @name
  body: (class_body) @body) @definition

(method_definition
  name: (_) @name
  body: (statement_block) @body) @definition

(variable_declarator
  name: (identifier) @name
  value: [(function_expression body: (statement_block) @body)
          (generator_function body: (statement_block) @body)
          (arrow_function body: (_) @body)]) @definition

(field_definition
  property: (_) @name
  value: [(function_expression body: (statement_block) @body)
          (generator_function body: (statement_block) @body)
          (arrow_function body: (_) @body)]) @definition

(export_statement
  value: [(function_expression body: (statement_block) @body)
          (generator_function body: (statement_block) @body)
          (arrow_function body: (_) @body)
          (class body: (class_body) @body)] @definition)

(decorator) @decoration
