<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 The Sinter Authors -->

# Lay out the packs, their checks, and their releases
@decision packs-repository
@cites upstream-grammars
This repository holds the packs javascript, ocaml, rust, and typescript, writes their queries, checks them with a Sinter built from a pinned commit, and releases each pack from a line of `index.jsonl` that its pull request adds.

## Context

Sinter fetches each language pack, except markdown, from this
repository. The pack specification of Sinter gives the format of a
pack, of the index, and of a release. Sinter has no released binary
yet: the release of the binaries is the last step of its first
version. The first useful version of Sinter reads JavaScript, OCaml,
Rust, and TypeScript, and binds the results of their tests.

## Decision

- The folder `packs/<name>/` is the pack root of the pack `<name>`.
  The conformance fixtures of a pack are outside the pack root, in
  `fixtures/<name>/<case>/`. CI checks each release against the
  fixtures of the release before it, read from that release's tag.
- CI builds Sinter from a pinned commit, with the pins of Sinter's
  own CI, and caches the build. The pin moves forward with the steps
  of Sinter that the packs need.
- The pull request that changes the version of a pack adds the line
  of the new release to `index.jsonl`. CI checks the line against the
  pack. The release job publishes the archive after the merge, and it
  never pushes to `main`.
- The queries of each pack are written here. Sinter's tests copy a
  pack folder from this repository as a fixture, pinned by its
  SHA-256.
- The first release of each pack is `0.1.0`.
- `javascript` is a pack of its own, with the grammar of
  tree-sitter-javascript, for `*.js`, `*.mjs`, `*.cjs`, and `*.jsx`.
- The test runners:
  - vitest for javascript and typescript, with the data of the
    default adapter in the descriptor;
  - for ocaml, the JUnit report that Sinter's JUnit writer gives for
    alcotest, with names that the data of the default adapter matches;
  - for rust, cargo-nextest, through an adapter module that this
    repository builds from `adapters/`.

## Alternatives considered

- **Release Sinter's binaries earlier, so that CI downloads a
  release.** Not chosen: the release of the binaries is the last step
  of Sinter's first version.
- **Keep the fixtures inside the pack root.** Not chosen: every change
  of a fixture would change the pack hash, and so force a new release
  and a new line in the lock file of every user.
- **Let the release job add the line to `index.jsonl`.** Not chosen:
  a bot would push to `main`, past the rules that protect it.
- **An adapter module for the OCaml runner.** Not chosen: a JUnit
  writer whose names the default adapter matches needs no module.
- **Write the queries in Sinter's test fixtures first, and move them
  here at the first release.** Not chosen: two copies of the queries
  would exist for a time and could drift apart.
- **First releases at `1.0.0`.** Not chosen: the first change of an
  extent hash would then need `2.0.0`.
- **Ship rust without test evidence in the first version.** Not
  chosen: the first version of Sinter checks code with test evidence.
- **No pack for JavaScript in the first version.** Not chosen: the
  first version needs JavaScript.
- **Let the typescript pack read JavaScript with the tsx grammar.**
  Not chosen: the facts of every JavaScript file would change when a
  javascript pack arrived.

## Consequences

The checks of a pack run before Sinter has a release, at the cost of a
build of Sinter in CI. A change of a query here needs a new fixture
copy in Sinter's tests. For a minute or two after a merge, the index
can name an archive that is still in publication.
