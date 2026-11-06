<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 The Sinter Authors -->

# Test the queries of each pack on small files
@decision query-tests
Each grammar of each pack has small test files, and CI compares the captures that `sinter parse --query` prints for them with the expected captures.

## Context

The checks of the step "Check packs" compile each query on an empty
file. They do not show that a query finds the right comments,
definitions, and tests. The scan fixtures show it, but the step that
adds them needs the Sinter step "Read JavaScript, OCaml, Rust, and
TypeScript", which is not done. Until then, a wrong query could merge
and stay wrong. The command `sinter parse --query` prints each capture
of a query as one line of canonical JSON.

## Decision

- For each grammar of a pack, the folder `tests/<pack>/<grammar>/`
  holds small files of the language and, for each query file, the
  captures that `sinter parse --query` must print for each of them.
- A tool in `tools/` runs the queries with the pinned Sinter and
  compares the output byte for byte. CI runs it on each pull request.
- The tests stay when the scan fixtures arrive.

## Alternatives considered

- **No tests of the queries until the scan fixtures.** Not chosen: a
  wrong query could merge, and a change of a query would be checked
  only by hand until the scan fixtures exist.

## Consequences

A change of a query shows in the expected captures, in the same pull
request. A change of the output of `sinter parse` in a new pin of
Sinter needs new expected captures.
