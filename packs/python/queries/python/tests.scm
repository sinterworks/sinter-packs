; SPDX-License-Identifier: Apache-2.0
; Copyright 2026 The Sinter Authors

(module
  (decorated_definition
    (decorator
      [(identifier) @label.parametrize
       (identifier) @label.skip
       (identifier) @label.xfail
       (attribute) @label.parametrize
       (attribute) @label.skip
       (attribute) @label.xfail
       (call function: (identifier) @label.parametrize)
       (call function: (identifier) @label.skip)
       (call function: (identifier) @label.xfail)
       (call function: (attribute) @label.parametrize)
       (call function: (attribute) @label.skip)
       (call function: (attribute) @label.xfail)])
    definition: (class_definition
      [((identifier) @name @_test_name)
       ((identifier) @name
        (argument_list
          [(identifier) @_base
           (attribute attribute: (identifier) @_base)]))]) @group)
  (#match? @_test_name "^Test")
  (#match? @_base "TestCase$")
  (#any-of? @label.parametrize "pytest.mark.parametrize" "mark.parametrize")
  (#any-of? @label.skip
    "pytest.mark.skip" "pytest.mark.skipif" "mark.skip" "mark.skipif"
    "unittest.skip" "unittest.skipIf" "unittest.skipUnless" "skip" "skipIf" "skipUnless")
  (#any-of? @label.xfail
    "pytest.mark.xfail" "mark.xfail" "unittest.expectedFailure" "expectedFailure"))

(module
  [(class_definition
     [((identifier) @name @_test_name)
      ((identifier) @name
       (argument_list
         [(identifier) @_base
          (attribute attribute: (identifier) @_base)]))]) @group
   (decorated_definition
     definition: (class_definition
       [((identifier) @name @_test_name)
        ((identifier) @name
         (argument_list
           [(identifier) @_base
            (attribute attribute: (identifier) @_base)]))]) @group)]
  (#match? @_test_name "^Test")
  (#match? @_base "TestCase$"))

(class_definition
  name: (identifier) @_outer
  body: (block
    (decorated_definition
      (decorator
        [(identifier) @label.parametrize
         (identifier) @label.skip
         (identifier) @label.xfail
         (attribute) @label.parametrize
         (attribute) @label.skip
         (attribute) @label.xfail
         (call function: (identifier) @label.parametrize)
         (call function: (identifier) @label.skip)
         (call function: (identifier) @label.xfail)
         (call function: (attribute) @label.parametrize)
         (call function: (attribute) @label.skip)
         (call function: (attribute) @label.xfail)])
      definition: (class_definition
        [((identifier) @name @_test_name)
         ((identifier) @name
          (argument_list
            [(identifier) @_base
             (attribute attribute: (identifier) @_base)]))]) @group))
  (#match? @_outer "^Test")
  (#match? @_test_name "^Test")
  (#match? @_base "TestCase$")
  (#any-of? @label.parametrize "pytest.mark.parametrize" "mark.parametrize")
  (#any-of? @label.skip
    "pytest.mark.skip" "pytest.mark.skipif" "mark.skip" "mark.skipif"
    "unittest.skip" "unittest.skipIf" "unittest.skipUnless" "skip" "skipIf" "skipUnless")
  (#any-of? @label.xfail
    "pytest.mark.xfail" "mark.xfail" "unittest.expectedFailure" "expectedFailure"))

(class_definition
  name: (identifier) @_outer
  body: (block
    [(class_definition
       [((identifier) @name @_test_name)
        ((identifier) @name
         (argument_list
           [(identifier) @_base
            (attribute attribute: (identifier) @_base)]))]) @group
     (decorated_definition
       definition: (class_definition
         [((identifier) @name @_test_name)
          ((identifier) @name
           (argument_list
             [(identifier) @_base
              (attribute attribute: (identifier) @_base)]))]) @group)])
  (#match? @_outer "^Test")
  (#match? @_test_name "^Test")
  (#match? @_base "TestCase$"))

(module
  (decorated_definition
    .
    [(decorator) @_decorator (comment)]*
    .
    (decorator
      [(identifier) @label.parametrize
       (identifier) @label.skip
       (identifier) @label.xfail
       (attribute) @label.parametrize
       (attribute) @label.skip
       (attribute) @label.xfail
       (call function: (identifier) @label.parametrize)
       (call function: (identifier) @label.skip)
       (call function: (identifier) @label.xfail)
       (call function: (attribute) @label.parametrize)
       (call function: (attribute) @label.skip)
       (call function: (attribute) @label.xfail)])
    .
    [(decorator) @_decorator (comment)]*
    .
    definition: (function_definition
      name: (identifier) @name) @test)
  (#match? @name "^test")
  (#not-match? @_decorator "^@\\s*(\\w+\\s*\\.\\s*)*fixture\\s*(\\(|#|$)")
  (#any-of? @label.parametrize "pytest.mark.parametrize" "mark.parametrize")
  (#any-of? @label.skip
    "pytest.mark.skip" "pytest.mark.skipif" "mark.skip" "mark.skipif"
    "unittest.skip" "unittest.skipIf" "unittest.skipUnless" "skip" "skipIf" "skipUnless")
  (#any-of? @label.xfail
    "pytest.mark.xfail" "mark.xfail" "unittest.expectedFailure" "expectedFailure"))

(module
  [(function_definition
     name: (identifier) @name) @test
   (decorated_definition
     .
     [(decorator) @_decorator (comment)]*
     .
     definition: (function_definition
       name: (identifier) @name) @test)]
  (#match? @name "^test")
  (#not-match? @_decorator "^@\\s*(\\w+\\s*\\.\\s*)*fixture\\s*(\\(|#|$)"))

(module
  [(class_definition
     [((identifier) @_test_name)
      ((identifier)
       (argument_list
         [(identifier) @_base
          (attribute attribute: (identifier) @_base)]))]
     (block
       (decorated_definition
         .
         [(decorator) @_decorator (comment)]*
         .
         (decorator
           [(identifier) @label.parametrize
            (identifier) @label.skip
            (identifier) @label.xfail
            (attribute) @label.parametrize
            (attribute) @label.skip
            (attribute) @label.xfail
            (call function: (identifier) @label.parametrize)
            (call function: (identifier) @label.skip)
            (call function: (identifier) @label.xfail)
            (call function: (attribute) @label.parametrize)
            (call function: (attribute) @label.skip)
            (call function: (attribute) @label.xfail)])
         .
         [(decorator) @_decorator (comment)]*
         .
         definition: (function_definition
           name: (identifier) @name) @test)))
   (decorated_definition
     definition: (class_definition
       [((identifier) @_test_name)
        ((identifier)
         (argument_list
           [(identifier) @_base
            (attribute attribute: (identifier) @_base)]))]
       (block
         (decorated_definition
           .
           [(decorator) @_decorator (comment)]*
           .
           (decorator
             [(identifier) @label.parametrize
              (identifier) @label.skip
              (identifier) @label.xfail
              (attribute) @label.parametrize
              (attribute) @label.skip
              (attribute) @label.xfail
              (call function: (identifier) @label.parametrize)
              (call function: (identifier) @label.skip)
              (call function: (identifier) @label.xfail)
              (call function: (attribute) @label.parametrize)
              (call function: (attribute) @label.skip)
              (call function: (attribute) @label.xfail)])
           .
           [(decorator) @_decorator (comment)]*
           .
           definition: (function_definition
             name: (identifier) @name) @test))))]
  (#match? @_test_name "^Test")
  (#match? @_base "TestCase$")
  (#match? @name "^test")
  (#not-match? @_decorator "^@\\s*(\\w+\\s*\\.\\s*)*fixture\\s*(\\(|#|$)")
  (#any-of? @label.parametrize "pytest.mark.parametrize" "mark.parametrize")
  (#any-of? @label.skip
    "pytest.mark.skip" "pytest.mark.skipif" "mark.skip" "mark.skipif"
    "unittest.skip" "unittest.skipIf" "unittest.skipUnless" "skip" "skipIf" "skipUnless")
  (#any-of? @label.xfail
    "pytest.mark.xfail" "mark.xfail" "unittest.expectedFailure" "expectedFailure"))

(module
  [(class_definition
     [((identifier) @_test_name)
      ((identifier)
       (argument_list
         [(identifier) @_base
          (attribute attribute: (identifier) @_base)]))]
     (block
       [(function_definition
          name: (identifier) @name) @test
        (decorated_definition
          .
          [(decorator) @_decorator (comment)]*
          .
          definition: (function_definition
            name: (identifier) @name) @test)]))
   (decorated_definition
     definition: (class_definition
       [((identifier) @_test_name)
        ((identifier)
         (argument_list
           [(identifier) @_base
            (attribute attribute: (identifier) @_base)]))]
       (block
         [(function_definition
            name: (identifier) @name) @test
          (decorated_definition
            .
            [(decorator) @_decorator (comment)]*
            .
            definition: (function_definition
              name: (identifier) @name) @test)])))]
  (#match? @_test_name "^Test")
  (#match? @_base "TestCase$")
  (#match? @name "^test")
  (#not-match? @_decorator "^@\\s*(\\w+\\s*\\.\\s*)*fixture\\s*(\\(|#|$)"))

(class_definition
  name: (identifier) @_outer
  body: (block
    [(class_definition
       [((identifier) @_test_name)
        ((identifier)
         (argument_list
           [(identifier) @_base
            (attribute attribute: (identifier) @_base)]))]
       (block
         (decorated_definition
           .
           [(decorator) @_decorator (comment)]*
           .
           (decorator
             [(identifier) @label.parametrize
              (identifier) @label.skip
              (identifier) @label.xfail
              (attribute) @label.parametrize
              (attribute) @label.skip
              (attribute) @label.xfail
              (call function: (identifier) @label.parametrize)
              (call function: (identifier) @label.skip)
              (call function: (identifier) @label.xfail)
              (call function: (attribute) @label.parametrize)
              (call function: (attribute) @label.skip)
              (call function: (attribute) @label.xfail)])
           .
           [(decorator) @_decorator (comment)]*
           .
           definition: (function_definition
             name: (identifier) @name) @test)))
     (decorated_definition
       definition: (class_definition
         [((identifier) @_test_name)
          ((identifier)
           (argument_list
             [(identifier) @_base
              (attribute attribute: (identifier) @_base)]))]
         (block
           (decorated_definition
             .
             [(decorator) @_decorator (comment)]*
             .
             (decorator
               [(identifier) @label.parametrize
                (identifier) @label.skip
                (identifier) @label.xfail
                (attribute) @label.parametrize
                (attribute) @label.skip
                (attribute) @label.xfail
                (call function: (identifier) @label.parametrize)
                (call function: (identifier) @label.skip)
                (call function: (identifier) @label.xfail)
                (call function: (attribute) @label.parametrize)
                (call function: (attribute) @label.skip)
                (call function: (attribute) @label.xfail)])
             .
             [(decorator) @_decorator (comment)]*
             .
             definition: (function_definition
               name: (identifier) @name) @test))))])
  (#match? @_outer "^Test")
  (#match? @_test_name "^Test")
  (#match? @_base "TestCase$")
  (#match? @name "^test")
  (#not-match? @_decorator "^@\\s*(\\w+\\s*\\.\\s*)*fixture\\s*(\\(|#|$)")
  (#any-of? @label.parametrize "pytest.mark.parametrize" "mark.parametrize")
  (#any-of? @label.skip
    "pytest.mark.skip" "pytest.mark.skipif" "mark.skip" "mark.skipif"
    "unittest.skip" "unittest.skipIf" "unittest.skipUnless" "skip" "skipIf" "skipUnless")
  (#any-of? @label.xfail
    "pytest.mark.xfail" "mark.xfail" "unittest.expectedFailure" "expectedFailure"))

(class_definition
  name: (identifier) @_outer
  body: (block
    [(class_definition
       [((identifier) @_test_name)
        ((identifier)
         (argument_list
           [(identifier) @_base
            (attribute attribute: (identifier) @_base)]))]
       (block
         [(function_definition
            name: (identifier) @name) @test
          (decorated_definition
            .
            [(decorator) @_decorator (comment)]*
            .
            definition: (function_definition
              name: (identifier) @name) @test)]))
     (decorated_definition
       definition: (class_definition
         [((identifier) @_test_name)
          ((identifier)
           (argument_list
             [(identifier) @_base
              (attribute attribute: (identifier) @_base)]))]
         (block
           [(function_definition
              name: (identifier) @name) @test
            (decorated_definition
              .
              [(decorator) @_decorator (comment)]*
              .
              definition: (function_definition
                name: (identifier) @name) @test)])))])
  (#match? @_outer "^Test")
  (#match? @_test_name "^Test")
  (#match? @_base "TestCase$")
  (#match? @name "^test")
  (#not-match? @_decorator "^@\\s*(\\w+\\s*\\.\\s*)*fixture\\s*(\\(|#|$)"))
