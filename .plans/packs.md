# The first packs
@plan packs@939532
@scope README.md, CONTRIBUTING.md, NOTICE, REUSE.toml, LICENSES/**, THIRD_PARTY.md, sinter.toml, docs/**, packs/**, adapters/**, fixtures/**, tools/**, tests/**, index.jsonl, .github/workflows/**
Release the packs javascript, ocaml, rust, and typescript at 0.1.0,
with their queries, their conformance fixtures, and their test
runners, and the CI that checks and releases each pack.

## Set up the repository
@scope CONTRIBUTING.md, NOTICE, REUSE.toml, LICENSES/**, THIRD_PARTY.md, sinter.toml, docs/**, .github/workflows/licensing.yml
@decision upstream-grammars
@decision packs-repository
Add the files of the repository root, the manifest that lets Sinter
check this repository, and the four license checks of Sinter's CI.

## Check packs
@scope tools/**, .github/workflows/ci.yml, CONTRIBUTING.md
Check each pack on each pull request with a Sinter built from a
pinned commit: the upstream digest and provenance of each grammar,
its imports, features, and ABI against the pinned tree-sitter, each
query, the license list, the folder `licenses/`, and the rules of
`index.jsonl`.

## Add the four packs
@scope packs/**, REUSE.toml, LICENSES/**, THIRD_PARTY.md, CONTRIBUTING.md, tests/**, tools/**, .github/workflows/ci.yml, docs/decisions/**
@decision query-tests
Add the packs javascript, ocaml, rust, and typescript: the upstream
grammars by SHA-256, their license texts and notice, the descriptors,
and the query files for comments, definitions, and tests. Test the
queries of each grammar on small files against the captures that
`sinter parse --query` prints, in CI.

## Name the sinterworks organization
@scope README.md, CONTRIBUTING.md, .github/workflows/ci.yml
Change the address of Sinter from lathrys-at to sinterworks after the
move of the repository.

## Release packs
@scope tools/**, .github/workflows/release.yml
Release each pack that `index.jsonl` names and that has no release:
build the archive, check its pack hash, attest it, and publish it as
`<name>-v<version>`.

## Add the scan fixtures
@scope fixtures/**, tools/**, .github/workflows/ci.yml
Add the conformance fixtures of each pack, with the project, the
manifest, and the expected scan, and check each release against the
fixtures of the release before it. This step needs the Sinter step
"Read JavaScript, OCaml, Rust, and TypeScript".

## Release the first packs
@scope index.jsonl, packs/*/pack.toml
Release javascript, ocaml, rust, and typescript at 0.1.0.

## Add the test runners
@scope packs/**, adapters/**, fixtures/**, tools/**, THIRD_PARTY.md, .github/workflows/**
Add the runner data of vitest and of alcotest's JUnit report, and the
adapter of cargo-nextest, with fixtures that hold real reports, and
release each pack again as a minor release. This step needs the
Sinter step "Import test evidence".
