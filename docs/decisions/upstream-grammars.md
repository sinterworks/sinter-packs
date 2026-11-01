<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 The Sinter Authors -->

# Take each grammar from its upstream release
@decision upstream-grammars
Each pack takes its grammars from the release assets of the upstream projects, pinned by SHA-256 and checked in CI, and a build from source is the documented fallback.

## Context

A pack holds tree-sitter grammars compiled to WebAssembly. The
upstream projects tree-sitter-javascript, tree-sitter-ocaml,
tree-sitter-rust, and tree-sitter-typescript publish such a file with
each release. Each file has a GitHub attestation: a signed record of
the repository, the commit, and the workflow that built it. The
upstream projects built the files with different versions of the
tree-sitter tools, and they do not state which. The newest release of
tree-sitter-typescript is from 2024. The release v0.26.0 of
tree-sitter-ocaml gives no syntax tree for a file with 4,675 nested
comments, and its fix is in no release yet. Sinter reports such a
file as a parse failure of that file and reads the rest of the
repository.

## Decision

- A pack takes each grammar file from an upstream release asset. The
  descriptor fixes the SHA-256 of the file.
- CI checks each grammar file:
  - its SHA-256 against the digest that GitHub publishes, or against
    the descriptor when GitHub publishes none;
  - its attestation, with `gh attestation verify`: the upstream
    repository, the release workflow of the tree-sitter organization,
    the tag, the commit that the tag names, and hosted runners only;
  - its imports, against the list of functions that the tree-sitter
    of the pinned Sinter gives a grammar;
  - its WebAssembly features and its ABI version, against the range
    of the pinned Sinter.
- The folder `licenses/` of a pack holds `Apache-2.0.txt`, one
  `<upstream repository>.LICENSE` for each upstream repository, copied
  as the upstream gives it, and a `NOTICE` that names the repository,
  the tag, the commit, the asset, and the SHA-256 of each grammar.
- `CONTRIBUTING.md` gives the recipe to build a grammar from source:
  the tree-sitter CLI with `build --wasm`, from the committed
  `src/parser.c`, with wasi-sdk and binaryen pinned by SHA-256.

## Alternatives considered

- **Build every grammar in this repository from a pinned commit,
  with a pinned toolchain.** Not chosen: the toolchain is about 300 MB
  for each host and version, it needs its own updates and a proof that
  two builds give the same bytes, and the upstream projects never
  tested the bytes that it makes.

## Consequences

A fix in a grammar reaches a pack only when the upstream project
releases it. A later upstream file can call a function that only a
newer tree-sitter gives a grammar; CI then refuses the file until
Sinter's pin moves to that tree-sitter. The build from source stays
ready for a grammar whose upstream does not release in time.
