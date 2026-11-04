; SPDX-License-Identifier: Apache-2.0
; Copyright 2026 The Sinter Authors

(compilation_unit
  (value_definition
    (let_binding
      pattern: [(value_name) (parenthesized_operator)] @name
      body: (_) @body) @definition))

(structure
  (value_definition
    (let_binding
      pattern: [(value_name) (parenthesized_operator)] @name
      body: (_) @body) @definition))

(compilation_unit
  (value_definition
    (let_binding
      body: (_) @body) @definition))

(structure
  (value_definition
    (let_binding
      body: (_) @body) @definition))

(type_binding
  name: (type_constructor) @name
  body: (_)? @body) @definition

(module_binding
  (module_name) @name
  body: (_)? @body) @definition

(module_type_definition
  (module_type_name) @name
  body: (_)? @body) @definition

(class_binding
  (class_name) @name
  body: (_)? @body) @definition

(external
  [(value_name) (parenthesized_operator)] @name) @definition

(exception_definition
  (constructor_declaration
    (constructor_name) @name)) @definition
