# Journal: The first packs

## Set up the repository

- `LICENSES/` holds only `Apache-2.0.txt`. `reuse lint` fails on a
  license text that no file uses, and no file is MIT before the first
  grammar. The step "Add the four packs" adds `LICENSES/MIT.txt`; the
  manifest makes `LICENSES/` an exempt path.
- `THIRD_PARTY.md` has the table with its header row only. The step
  "Add the four packs" adds a row for each grammar.
- The manifest fixes the name of the pin of Sinter, `tools/sinter.pin`,
  as an exempt path, with the lock files under `adapters/`. Neither
  later step that adds them has `sinter.toml` in its scope.
- The form check of `THIRD_PARTY.md` is stricter than Sinter's: a row
  needs three cells that are not empty, and the table needs its header
  row. The license check has no exception for LGPL.
- `CONTRIBUTING.md` fixes the form of `licenses/NOTICE` of a pack: one
  block of six lines for each grammar. The checks of the step "Check
  packs" read the upstream repository, the tag, and the commit from it.
  A grammar built from source adds one line for each archive of its
  build, with its SHA-256. It has no release asset and no attestation,
  so the checks refuse its block.

## Check packs

- The tools read `pack.toml` with a reader in awk for a plain form of
  TOML, by a ruling of the lead: shell and jq cannot read TOML. The
  reader stops at each other form, so a descriptor that it refuses is
  written in the plain form. Sinter's reader checks the full TOML.
- A grammar passes the check of its features when each feature that
  it uses is a feature of the standard library module of the pinned
  tree-sitter. The assets typescript and tsx v0.23.2 have no
  target_features section, and they load in the pinned Sinter. So a
  grammar with no section passes, and the tool says that only its load
  checks its features (ruling of the lead). The check is stricter than
  the load: the module of tree-sitter 0.25.10 has five features, and
  rust v0.24.2 uses eight, but it loads there.
- The ABI version comes from the module without running it: the
  function `tree_sitter_NAME` returns a constant address, and the data
  at that address starts with the version. A module of any other shape
  fails the check.
- The imports are checked by name only. tree-sitter matches an import
  by its name, and a wrong kind fails at the load.
- The list of licenses is a constant of `check-licenses.sh`, the same
  as in `CONTRIBUTING.md`. Sinter's `docs/licensing-setup.md` gives it
  in a sentence, which a tool cannot read reliably.
- The version rule compares the pack hash of each folder with the pack
  hash at the base. The tool unpacks the folder of the base with
  `git archive`, so one function computes both hashes. Reading
  `git ls-tree` failed: it quotes a path with `"`, which the pack hash
  accepts. No line of the index of the base can change or go away.
- The tests unset the variables `GIT_*` that choose a repository, and
  `check-index.sh` unsets them before it runs git. Under
  `git rebase --exec`, GIT_DIR pointed the git commands of the tests at
  the clone of this repository.
- The query check runs each query on an empty file. A compiled query
  is all that the check needs.
- The tests that call GitHub with gh, and the download of the
  grammars of the tests, run only in CI.

## Add the four packs

- The query tests have no license header in their cases and expected
  files (ruling of the lead): a header is a comment, and every expected
  file of `tags.scm` would capture it. The annotation `**` of
  `REUSE.toml` gives them Apache-2.0.
- The JSDoc block tags, with their synonyms, come from the list "Block
  Tags" of https://jsdoc.app/ (read 2026-11-04): 85 words.
- `foreign-tags` leaves out each word that is also a word of Sinter's
  vocabulary (ruling of the lead): `deprecated`, a block tag of JSDoc
  and a status tag of Sinter. The javascript pack lists 84 words.
- The javascript grammar has a second comment node, `html_comment`,
  for `<!--` and `-->`. `tags.scm` captures it as `@comment`.
  `[comments]` has no sigil for it, so it carries no tags.
- A tag before `export function f` attaches to `f` with no pattern for
  `export_statement`: `f` starts on the line of `export`, so no line
  stands between the run and `f`. A decorator before `export class`
  is a child of `export_statement`; it is `@decoration`, and the class
  starts on the next line. Without `export`, a decorator is a child of
  the class, and the class starts at the decorator.
- `definitions.scm` captures `variable_declarator`, not the
  declaration, so that `const a = () => {}, b = function () {}` gives
  two definitions.
- The labels of `tests.scm` use `#eq?` on captures in the branches of
  an alternation. A predicate on a capture that a match does not hold
  passes, so each branch keeps only the property that its label names.
  `it.concurrent` and `it.skip.each` give no test.
- A default export with no name, `export default function () {}`,
  `function* () {}`, `() => {}`, or `class {}`, is a definition with
  no `@name` (ruling of the lead). The grammar gives it as the `value`
  of `export_statement`.
- A class field whose value is a function, a generator, or an arrow
  function is a definition, as a variable with such a value is
  (ruling of the lead).
- A test or a group whose title is an identifier, a member, a
  subscript, a call, a binary or ternary expression, or a parenthesized
  expression has that title as one `@placeholder` (ruling of the
  lead). The cost: such a name matches any name that the runner
  reports, and one such test in a loop stands for many tests at run
  time.
- The TSDoc block tags come from the tag reference of
  https://tsdoc.org/ (read 2026-11-04). Its list has 25 tags; the
  file `StandardTags.ts` of microsoft/tsdoc gives the kind of each.
  The 11 block tags are `decorator`, `defaultValue`, `deprecated`,
  `example`, `param`, `privateRemarks`, `remarks`, `returns`, `see`,
  `throws`, and `typeParam`. The four `jsx` tags of that file are not
  in the reference. The typescript pack lists 89 words: the 84 of
  JSDoc and 5 of TSDoc that JSDoc does not have.
- The grammars typescript and tsx have the same text in each query
  file. `tsx` parses JSX, and `typescript` parses the type assertion
  `<T>x`; the node types that the queries name are in both.
- The name of `declare module "x"` is the `string_fragment`, so that
  the name path holds no quotes.
- In TypeScript, a title that is an `as`, `!`, or `satisfies`
  expression is one `@placeholder` too.
- In Rust, an attribute is a sibling before its item, not a child. The
  patterns of `tests.scm` read the attributes before a function as a
  sibling sequence: a test attribute, then any attributes and comments,
  then the function. `#[ignore]` before or after the test attribute
  has a pattern of its own, before the pattern with no label, so that
  the match with the label is the first one.
- `definitions.scm` captures every `attribute_item` as `@decoration`,
  as the example of the specification does, also an attribute of a
  parameter such as `#[case]`.
- An `impl` has the name of its type: `impl Shape for Unit` and
  `impl<T> Named<T>` have the names `Unit` and `Named`. An `impl` for
  another type, such as a reference, is a definition with no name.
- Only a module with `#[cfg(test)]` is a group (ruling of the lead). A
  module inside such a module, a test module without `#[cfg(test)]`,
  and a module with `#[cfg(all(test, unix))]` are no groups, so the
  name path of their tests lacks that module. The step "Add the scan
  fixtures" can widen the rule.
- In the rust grammar, a doc line comment `///` or `//!` holds its
  line ending, and in a file with CRLF line ends, a plain line comment
  holds the CR.
- The OCaml `tags.scm` is the example of the specification: a comment
  that starts with `(**` and a character that is not `*` is
  `@untagged`, so `(***)` stays a tagged comment.
- In `.ml`, each `let_binding` of a `let` in a file or in a `struct` is
  a definition. A binding whose pattern is not a name, such as
  `let () =`, has a pattern of its own with no `@name`, after the
  pattern with the name. A `let ... in` gives no definition.
- An `Alcotest.test_case` has a pattern with the label `slow` before
  the pattern with no label. One pattern with an optional tag gave no
  match for `` `Quick ``: a match whose predicate fails is dropped, and
  tree-sitter gives no match without the optional node.
- In ``test_case "x" `Quick @@ fun () -> ...``, the test is the
  application ``test_case "x" `Quick``, and the function is outside
  it.
- When the string of an OCaml name holds a backslash, the name is one
  `@placeholder` (ruling of the lead). The grammar gives the text
  around an escape sequence no node of its own. The cost: such a name
  matches any name that the runner reports.
- An OCaml test name that is a value path, a field, or an expression
  in brackets is one `@placeholder`, and so is the punned label
  `~name` of `QCheck.Test.make` (ruling of the lead, as for JavaScript).
  A group name that is not a literal is one `@placeholder` too: in a
  tuple, it can also be an application or an infix expression with no
  brackets. A quoted string `{|...|}` is a literal: its content is
  `@name`.
- A group needs a list literal: `("unit", unit_tests)` is no group, as
  its tests are not inside it.
- The grammar ocaml_interface has no `tests.scm` (ruling of the lead):
  an interface declares no tests.
- In the grammar ocaml v0.26.0, a comment that does not end runs to
  the end of the file, with no `ERROR` node.

## Release packs

- `check-archive.sh` checks the first three bytes before it runs gzip:
  `gzip -t` also accepts the data of the command `compress`, with exit
  code 0.
- The tool stops the decompression at 128 MiB and one byte, with
  `head -c`, so that a small archive cannot fill the disk of the runner.
- The tests of `build-archive.sh` use a stub of `tar` that writes real
  ustar entries with `tools/test/ustar.awk`, so that they run on macOS
  too. Only the tests with the prefix `t_gnu_` run the real tar.
- `run.sh` prints one line `skip` for each test that an option leaves
  out, so that no test skips silently. This also applies to `-u`.
