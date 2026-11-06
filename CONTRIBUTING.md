# Contributing to Sinter packs

## Writing

The rules of the section "Writing" of
[Sinter's CONTRIBUTING.md](https://github.com/sinterworks/sinter/blob/main/CONTRIBUTING.md#writing)
apply to every text of this repository: the documents, the comments,
the commit messages, the pull requests, and the messages that the
tools print. The text uses Simplified Technical English (ASD-STE100)
in the style of Simple English Wikipedia.

Some text comes from elsewhere: the license texts, the DCO, and the
license files of the grammars. That text stays exactly as it is in the
source.

### Code comments

A comment is permitted only in these cases (record
[`code-comments`](https://github.com/sinterworks/sinter/blob/main/docs/decisions/code-comments.md)
of Sinter):

- Sinter reads it: a tag block, with the prose that follows the tags
  as their description. A choice that rests on a decision record cites
  it with a tag line: `# @cites <slug>` in shell, YAML, and TOML,
  `; @cites <slug>` in a query file, and `// @cites <slug>` in Rust.
- The community of the language expects it: the API comment on an
  exported value in Rust (`///` and `//!`), and the license header of
  a file.

A permitted comment states what the code takes, what it gives, what
it guarantees, and what can go wrong. It never states why the code is
as it is, what it replaced, or what else was possible. Reasons go in
decision records and in commit messages.

The rule applies to every file of code: shell, the CI workflows, the
TOML files, the query files, Rust, and the tests. Write no other
comment.

### Messages that the tools print

An error message or a help text addresses the person who runs the
tool. It says what is wrong and, when useful, what to do. It never
names a repository file or a document section, and it never explains
the tool's internal reasons.

## New files

A new file needs an SPDX header with the license Apache-2.0, and the
line `Copyright <year> The Sinter Authors`:

<!-- REUSE-IgnoreStart -->
- YAML, TOML, and shell: `# SPDX-License-Identifier: Apache-2.0`
- query files: `; SPDX-License-Identifier: Apache-2.0`
- Rust: `// SPDX-License-Identifier: Apache-2.0`
- Markdown in `docs/`: `<!-- SPDX-License-Identifier: Apache-2.0 -->`
<!-- REUSE-IgnoreEnd -->

These files carry no header, and `REUSE.toml` gives each its license:
the files at the repository root; files whose format has no comment,
such as JSON; files that a tool generates, such as `Cargo.lock`; the
plan files under `.plans/`; the grammars and the license files of the
upstream projects; and the cases of the query tests and their expected
captures under `tests/`. Keep the two ignore markers around the list
above. The markers stop the `reuse` tool from reading the examples as
license tags for this file.

## Checks

The file `tools/sinter.pin` holds the commit of Sinter that CI builds.
Build Sinter at that commit from
[its repository](https://github.com/sinterworks/sinter), as its
CONTRIBUTING.md says. The checks below name two of its parts:

- `SINTER`: the built `sinter`, `_build/default/bin/main.exe`.
- `CRATE`: the folder of the source of the crate `tree-sitter` that
  the bridge of Sinter uses. In the checkout of Sinter, this command
  prints the path of the file `Cargo.toml` of that crate, and `CRATE`
  is the folder of that file:

  ```
  cargo metadata --format-version 1 --locked --manifest-path bridge/Cargo.toml |
    jq -r '.packages[] | select(.name == "tree-sitter") | .manifest_path'
  ```

Before you commit, check that these pass at the repository root:

- `reuse lint`. Install the tool once, for example with
  `pipx install reuse`.
- `SINTER check --gate review`.
- `shellcheck -s sh -x -P SCRIPTDIR` on each file `*.sh` under
  `tools/`.
- The tests of the tools:
  `sh tools/test/run.sh -s SINTER -t CRATE -g GRAMMARS`. `GRAMMARS` is
  a folder that holds the files of `tools/test/grammars.txt`. Each
  line of that file gives a file, its SHA-256, and its address.
  Download each file and check its SHA-256. With `-u`, the tests also
  call GitHub with `gh`.
- The checks of the packs, on each folder under `packs/`:
  1. `tools/check-grammars.sh -t CRATE packs/*/`
  2. `tools/check-queries.sh -s SINTER packs/*/`
  3. `tools/check-licenses.sh packs/*/`
  4. `tools/check-upstream.sh packs/*/`, which calls GitHub with `gh`
  5. `tools/check-index.sh -b origin/main`
  6. `tools/check-query-tests.sh -s SINTER`, which runs the query
     tests

Each tool prints its checks and its exit codes with `-h`. CI runs all of
them in the workflow `ci`, and the license checks in the workflow
`licensing`.

## Commits

- Sign off every commit with `git commit -s`. The line certifies that
  your contribution satisfies the Developer Certificate of Origin; the
  DCO file holds the full text. CI rejects a commit that has no
  sign-off.
- Use an imperative subject line and a short body that says what
  changed and why.
- End the message with the trailers of the record
  [`commit-messages`](https://github.com/sinterworks/sinter/blob/main/docs/decisions/commit-messages.md)
  of Sinter, before the sign-off:
  1. One line that names what allows the change: `Step: <plan>/<step>`
     for a step of a plan in `.plans/`, for example
     `Step: packs/check-packs`; `Record: <slug>` for a decision record;
     or `Issue: gh/<number>` for an issue.
  2. One `Meets: <tag> <slug>` line for each promise of the step that
     the commit carries out.
  3. One `Delivers: <plan>/<step> <hash>` line for each step that the
     commit completes. Take the line from the field `delivery` of the
     record of the step that `sinter scan` prints. A step without
     promises needs the line too. Sinter reads every line of a message
     that starts with `Delivers: `, so start no other line with those
     words.
  4. The trailer that names an agent, then the sign-off.
- When an agent wrote a large part of a change, name the agent with a
  trailer: `Assisted-by: Claude Code`, when the human is the author, or
  `Co-Authored-By: Claude Code <noreply@anthropic.com>`, when the agent
  is a co-author. The human who runs the agent signs off the commit,
  and is the contributor of record. Do not sign off code that you did
  not review.

## Pull requests

Every change reaches `main` through a pull request. The maintainer
reviews and merges. A pull request description names the plan step,
with its plan file, or the issue that the change carries out.

## Adding a pack

A pack lives in the folder `packs/<name>/`, its pack root. The
[pack specification](https://github.com/sinterworks/sinter/blob/main/spec/packs.md)
gives the files of a pack. Each grammar comes from a release asset of
its upstream project (record `upstream-grammars`).

1. Take the release of the upstream project that you add. Find the
   commit that its tag names:
   `gh api repos/<owner>/<repository>/commits/<tag> --jq .sha`. Do
   not take the object of the tag ref: an annotated tag is an object
   of its own, and its hash is not the commit.
2. Download the asset `.wasm` of the grammar from that release. Put it
   at `packs/<name>/grammars/<grammar>.wasm`.
3. Compute the SHA-256 of the file, with `sha256sum` or
   `shasum -a 256`. Compare it with the digest that GitHub gives for
   the asset:
   `gh api repos/<owner>/<repository>/releases/tags/<tag> --jq '.assets[] | select(.name == "<asset>") | .digest'`.
   The digest has the form `sha256:<hash>`. When GitHub gives no
   digest, the command prints `null`, and the SHA-256 in the
   descriptor is the only record of the file.
4. Check its attestation:

   ```
   gh attestation verify packs/<name>/grammars/<grammar>.wasm \
     --repo <owner>/<repository> \
     --signer-workflow tree-sitter/workflows/.github/workflows/release.yml \
     --source-ref refs/tags/<tag> \
     --source-digest <commit> \
     --deny-self-hosted-runners
   ```

5. Write the descriptor `packs/<name>/pack.toml`. Give each grammar the
   SHA-256 of its file. The top-level `license` is `Apache-2.0`, the
   license of the descriptor and the query files. The `license` of
   each grammar is the license of its upstream project. Each `license`
   value is an SPDX expression of licenses on this list: `0BSD`,
   `Apache-2.0`, `BSD-2-Clause`, `BSD-3-Clause`, `ISC`, `MIT`,
   `MPL-2.0`, `Unlicense`. Any other license needs a decision of the
   maintainer. Write the descriptor in the plain form of TOML that the
   tools read: no dotted key, no inline table, no multi-line string,
   and each value on the line of its key.
6. Fill the folder `packs/<name>/licenses/`:
   - `Apache-2.0.txt`: the text of `LICENSES/Apache-2.0.txt`, for the
     files that this repository writes.
   - `<repository>.LICENSE` for each upstream repository, for example
     `tree-sitter-rust.LICENSE`: the license file of the repository
     at the tag, exactly as the upstream gives it.
   - `NOTICE`: the form below.
7. Give each grammar and each upstream license file its upstream
   license in `REUSE.toml`, with the copyright line of the upstream
   license file, and add a row for each grammar to `THIRD_PARTY.md`.
8. Write the query files under `packs/<name>/queries/<grammar>/`.
9. Write the query tests (record `query-tests`) of each grammar in the
   folder `tests/<name>/<grammar>/`. A case is a small file of the
   language, `<case>.<ext>`. For each query file `<query>.scm` of the
   grammar, the file `<case>.<query>.jsonl` holds the captures that
   `sinter parse --query` prints for the case. Give each grammar cases
   for every form that its queries find, and for forms that they must
   not find. Then run `tools/check-query-tests.sh -u -s SINTER`. With
   `-u`, the tool writes the files `<case>.<query>.jsonl`. Read each
   file that it writes, line by line, and check each capture against
   the case. Do not commit a file that no person has read. Without
   `-u`, the tool compares the output with each file, as CI does.

The file `licenses/NOTICE` starts with two lines: `<name> pack of
Sinter` and `Copyright <year> The Sinter Authors`. Then it holds one
block for each grammar, in the order of the descriptor. A blank line
stands before each block. Each block holds these six lines, in this
order:

| line | value |
|---|---|
| `grammar: <grammar>` | the name of the grammar in the descriptor |
| `repository: <owner>/<repository>` | the upstream repository on GitHub |
| `tag: <tag>` | the tag of the release |
| `commit: <commit>` | the commit that the tag names, as 40 lowercase hex digits |
| `asset: <asset>` | the name of the release asset |
| `sha256: <hash>` | the SHA-256 of the file, as 64 lowercase hex digits |

Example:

```
rust pack of Sinter
Copyright 2026 The Sinter Authors

grammar: rust
repository: tree-sitter/tree-sitter-rust
tag: v0.24.2
commit: 77a3747266f4d621d0757825e6b11edcbf991ca5
asset: tree-sitter-rust.wasm
sha256: <the SHA-256 of grammars/rust.wasm>
```

### Releases of a pack

The first release of a pack is `0.1.0`. Each change of the files of a
pack that has a release needs a new release: raise `version` in
`pack.toml` by the rules of release numbers of the pack
specification, and add the line of the new release to `index.jsonl`
in the same pull request. The line holds the pack hash of the folder,
which `tools/pack-hash.sh packs/<name>` prints.
After the merge, CI publishes the archive of the release.

### A grammar built from source

When an upstream project does not release a fix in time, a grammar can
be built from its source, from the file `src/parser.c` that the
upstream project commits. The tree-sitter CLI of the build is the
release of `tree-sitter/tree-sitter` whose version is the version of
the crate `tree-sitter` in `bridge/Cargo.lock` of the pinned commit
of Sinter.

1. Download the CLI from that release. Check its SHA-256 against the
   digest of the asset, and check its attestation with
   `gh attestation verify`.
2. Download the wasi-sdk release that this version of the CLI uses,
   and for tree-sitter 0.27 and later also the binaryen release. Check
   the SHA-256 of each archive against the value that its release
   publishes. Set `TREE_SITTER_WASI_SDK_PATH` and
   `TREE_SITTER_BINARYEN_PATH` to the unpacked folders, so that the
   CLI uses them and downloads nothing itself.
3. Check out the upstream repository at the commit. Do not run
   `tree-sitter generate`: the build reads the committed
   `src/parser.c`.
4. Run `tree-sitter build --wasm --output <grammar>.wasm <folder>`,
   where `<folder>` holds the `tree-sitter.json` of the grammar.
5. Check that the file holds no absolute path of the machine that
   built it.
6. Write the block of the grammar in `licenses/NOTICE`. The lines
   `tag:` and `commit:` name the source. The line `asset:` holds
   `none`. After the six lines, add one line for each archive of the
   build, in the form `<tool>: <version> <SHA-256 of the archive>`:
   `tree-sitter-cli:`, `wasi-sdk:`, and, when the build uses it,
   `binaryen:`.

A grammar built from source has no release asset and no attestation
of its upstream project, so the checks of CI refuse it. Ask the
maintainer before you add one.
