; SPDX-License-Identifier: Apache-2.0
; Copyright 2026 The Sinter Authors

(function_declaration
  name: (identifier) @name
  body: (statement_block) @body) @definition

(generator_function_declaration
  name: (identifier) @name
  body: (statement_block) @body) @definition

(function_signature
  name: (identifier) @name) @definition

(class_declaration
  name: (type_identifier) @name
  body: (class_body) @body) @definition

(abstract_class_declaration
  name: (type_identifier) @name
  body: (class_body) @body) @definition

(method_definition
  name: (_) @name
  body: (statement_block) @body) @definition

(method_signature
  name: (_) @name) @definition

(abstract_method_signature
  name: (_) @name) @definition

(interface_declaration
  name: (type_identifier) @name
  body: (interface_body) @body) @definition

(type_alias_declaration
  name: (type_identifier) @name
  value: (_) @body) @definition

(enum_declaration
  name: (identifier) @name
  body: (enum_body) @body) @definition

(internal_module
  name: (_) @name
  body: (statement_block) @body) @definition

(module
  name: [(identifier) @name
         (nested_identifier) @name
         (string (string_fragment) @name)]
  body: (statement_block) @body) @definition

(variable_declarator
  name: (identifier) @name
  value: [(function_expression body: (statement_block) @body)
          (generator_function body: (statement_block) @body)
          (arrow_function body: (_) @body)]) @definition

(public_field_definition
  name: (_) @name
  value: [(function_expression body: (statement_block) @body)
          (generator_function body: (statement_block) @body)
          (arrow_function body: (_) @body)]) @definition

(export_statement
  value: [(function_expression body: (statement_block) @body)
          (generator_function body: (statement_block) @body)
          (arrow_function body: (_) @body)
          (class body: (class_body) @body)] @definition)

(decorator) @decoration
