# genoffice-nix

<p align="center">
  <img src=".github/assets/build-pipeline.svg" width="920" alt="The latest GenOffice release tag enters nix build in the Nix sandbox, which applies the test patches, builds docs, sheets, slides, pdf, markdown and html plus the Rust xlsx sidecar, and runs the upstream test suite, producing the genoffice-app desktop app and the genoffice CLI; a daily workflow repeats this for each new tag and opens a pull request">
</p>

A Nix flake for [GenOffice](https://github.com/genspark-ai/genoffice), built from
upstream release tags. This repository contains no GenOffice source.

## Run it

```sh
nix run github:jakob1379/genoffice-nix#genoffice-app   # desktop app
nix run github:jakob1379/genoffice-nix -- --help        # CLI
```

Linux only (`x86_64`, `aarch64`).

| Output                         | What you get                                                  |
| ------------------------------ | ------------------------------------------------------------- |
| `packages.<system>.default`    | `bin/genoffice` (CLI) and `bin/genoffice-app` (Electron app)  |
| `apps.<system>.genoffice-app`  | The desktop app, for `nix run`                                |
| `checks.<system>.default`      | The same package, so `nix flake check` builds and tests it    |

The CLI finds the desktop app through `GENOFFICE_APP_BIN`, which defaults to the
packaged `genoffice-app`.

## What `nix build` does

`nix build` compiles every app (including the Rust xlsx sidecar) and runs the
full upstream test suite in the Nix sandbox. A release that fails its own tests
does not produce a package.

## Updating

npm dependencies come from upstream's `package-lock.json` via `importNpmLock`, so
there is no `npmDepsHash` to maintain. A daily workflow bumps the source to the
latest `v*` tag, builds and tests it, and opens a pull request.

By hand:

```sh
sed -i -E 's|(genspark-ai/genoffice/)v[0-9.]+|\1vX.Y.Z|; s|(version = ")[0-9.]+|\1X.Y.Z|' flake.nix
nix flake update genoffice-src
nix build -L
```

## Patches

`patches/` carries upstream test fixes not yet in a release
([genspark-ai/genoffice#1987](https://github.com/genspark-ai/genoffice/pull/1987)).
Delete them once a tag includes that change.
