# Sinter packs

Language packs for [Sinter](https://github.com/sinterworks/sinter), a
linter that keeps specs, plans, and code in sync.

A **pack** is the support for one language in Sinter. It holds the
grammar that parses the language, and the queries that find the
comments, definitions, and tests where Sinter reads tags. It also
holds a descriptor and the license texts. The
[pack specification](https://github.com/sinterworks/sinter/blob/main/spec/packs.md)
gives the format of a pack.

## Packs

| pack | files | grammars | test runners |
|---|---|---|---|
| `javascript` | `*.js`, `*.mjs`, `*.cjs`, `*.jsx` | tree-sitter-javascript: `javascript` | vitest |
| `ocaml` | `*.ml`, `*.mli` | tree-sitter-ocaml: `ocaml`, `ocaml_interface` | alcotest, with a JUnit report |
| `python` | `*.py`, `*.pyi` | tree-sitter-python: `python` | pytest, with a JUnit report |
| `rust` | `*.rs` | tree-sitter-rust: `rust` | cargo-nextest |
| `typescript` | `*.ts`, `*.mts`, `*.cts`, `*.tsx` | tree-sitter-typescript: `typescript`, `tsx` | vitest |

## Use a pack

Name the pack and its release line in the manifest `sinter.toml` of
your repository:

```toml
[scan.packs.rust]
version = "0.1"
files = ["**/*.rs"]
```

Then add the pack:

```
sinter pack add rust
```

Sinter fetches the newest release that meets the version, checks its
pack hash, keeps the pack in a cache of the user, and records it in
the lock file `sinter.lock`. Commit the lock file. On another machine,
`sinter pack fetch` fetches the packs that the lock file names.

## Releases

Each release of a pack is one GitHub release of this repository. Its
tag is `<name>-v<version>`, for example `rust-v0.1.0`. It holds one
archive, `<name>-<version>.tar.gz`, with the files of the pack.

The file `index.jsonl` lists each release with its pack hash. The
pack hash is the SHA-256 of a list of the files of the pack and of
their hashes.

## Licenses

The files that we write use the Apache-2.0 license: the descriptors,
the queries, and the tools of this repository. See the LICENSE file.
Each grammar keeps the license of its upstream project. The folder
`licenses/` of each pack holds those license texts, and a notice that
names the source of each grammar. We accept contributions under a
Developer Certificate of Origin (DCO). See the DCO file.
