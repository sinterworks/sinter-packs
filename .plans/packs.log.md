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
