# genoffice-nix

A Nix flake for [GenOffice](https://github.com/genspark-ai/genoffice), built from
upstream release tags. This repository contains no GenOffice source.

```sh
nix run github:jakob1379/genoffice-nix#genoffice-app   # desktop app
nix run github:jakob1379/genoffice-nix -- --help        # CLI
```

`nix build` compiles every app (including the Rust xlsx sidecar) and runs the
full upstream test suite in the Nix sandbox. Linux only (`x86_64`, `aarch64`).

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
