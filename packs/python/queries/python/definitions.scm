; SPDX-License-Identifier: Apache-2.0
; Copyright 2026 The Sinter Authors

(function_definition
  name: (identifier) @name
  body: (block) @body) @definition

(class_definition
  name: (identifier) @name
  body: (block) @body) @definition

(type_alias_statement
  left: (type [(identifier) @name
               (generic_type . (identifier) @name)])) @definition

(module
  [(expression_statement . (assignment left: (identifier) @name) @definition .)
   (assignment left: (identifier) @name) @definition])

(decorator) @decoration
