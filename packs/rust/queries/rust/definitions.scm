; SPDX-License-Identifier: Apache-2.0
; Copyright 2026 The Sinter Authors

(function_item
  name: (identifier) @name
  body: (block) @body) @definition

(function_signature_item
  name: (identifier) @name) @definition

(struct_item
  name: (type_identifier) @name
  body: (_)? @body) @definition

(enum_item
  name: (type_identifier) @name
  body: (enum_variant_list) @body) @definition

(union_item
  name: (type_identifier) @name
  body: (field_declaration_list) @body) @definition

(trait_item
  name: (type_identifier) @name
  body: (declaration_list) @body) @definition

(impl_item
  type: [(type_identifier) @name
         (generic_type type: (type_identifier) @name)
         (scoped_type_identifier name: (type_identifier) @name)]
  body: (declaration_list) @body) @definition

(impl_item
  body: (declaration_list) @body) @definition

(mod_item
  name: (identifier) @name
  body: (declaration_list)? @body) @definition

(const_item
  name: (identifier) @name) @definition

(static_item
  name: (identifier) @name) @definition

(type_item
  name: (type_identifier) @name) @definition

(macro_definition
  name: (identifier) @name) @definition

(attribute_item) @decoration
