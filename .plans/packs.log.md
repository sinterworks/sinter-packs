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
