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
