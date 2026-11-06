; SPDX-License-Identifier: Apache-2.0
; Copyright 2026 The Sinter Authors

(value_specification
  [(value_name) (parenthesized_operator)] @name) @definition

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
