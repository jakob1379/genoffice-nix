{
  description = "GenOffice - AI-native office suite, packaged from upstream release tags";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    genoffice-src = {
      url = "github:genspark-ai/genoffice/v0.11.564";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      genoffice-src,
    }:
    let
      version = "0.11.564";
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          src = genoffice-src;
          nodejs = pkgs.nodejs_22;
          lock = pkgs.lib.importJSON "${src}/package-lock.json";
          electron = pkgs."electron_${pkgs.lib.versions.major lock.packages."node_modules/electron".version}";
          fonts = pkgs.symlinkJoin {
            name = "fonts";
            paths = [
              pkgs.dejavu_fonts
              pkgs.liberation_ttf
            ];
          };
        in
        {
          default = pkgs.buildNpmPackage {
            pname = "genoffice";
            inherit version src nodejs;

            # shortcut: upstream test fixes (genspark-ai/genoffice#1987), drop once a release tag contains them
            patches = [
              ./patches/0001-test-electron-utils-stub-DNS-lookups-in-remote-image.patch
              ./patches/0002-test-docs-let-protect-dialog-submit-wait-for-the-tes.patch
            ];

            npmDeps = pkgs.importNpmLock { npmRoot = src; };
            npmConfigHook = pkgs.importNpmLock.npmConfigHook;

            cargoRoot = "apps/sheets/native/xlsx-engine";
            cargoDeps = pkgs.rustPlatform.importCargoLock {
              lockFile = "${src}/apps/sheets/native/xlsx-engine/Cargo.lock";
            };

            nativeBuildInputs = with pkgs; [
              cargo
              rustc
              rustPlatform.cargoSetupHook
              makeWrapper
            ];
            nativeCheckInputs = with pkgs; [
              git
              libxml2
            ];

            npmRebuildFlags = [ "--ignore-scripts" ];
            env = {
              ELECTRON_OVERRIDE_DIST_PATH = "${electron}/bin";
              CHROME_PATH = "${pkgs.chromium}/bin/chromium";
              FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ fonts ]; };
            };

            npmBuildScript = "build:all";
            postBuild = ''
              npm run notices
            '';

            doCheck = true;
            checkPhase = ''
              runHook preCheck
              (
                HOME=$(mktemp -d) || exit
                export HOME
                git init -q && git add -A || exit
                ln -s ${fonts}/share/fonts "$HOME/.fonts" || exit
                npm run fixtures -w @genoffice/sheets || exit
                export CI=1
                export VITEST_MAX_WORKERS=$((NIX_BUILD_CORES < 4 ? NIX_BUILD_CORES : 4))
                workspaces=$(node -p 'require("./package.json").scripts.test.match(/@genoffice\/[\w-]+/g).join(" ")') || exit
                for w in $workspaces; do
                  npm run test -w $w -- --testTimeout=120000 --hookTimeout=120000 || exit
                done
              ) && runHook postCheck || return $?
            '';

            installPhase = ''
              runHook preInstall
              mkdir -p "$out/lib"
              cp -r . "$out/lib/genoffice"
              (
                cd "$out/lib/genoffice" || exit 1
                npm prune --omit=dev
                sidecar=apps/sheets/native/xlsx-engine/target/release/xlsx-sidecar
                mv "$sidecar" "$TMPDIR/xlsx-sidecar"
                rm -rf .git .task apps/sheets/native/xlsx-engine/target apps/sheets/fixtures/generated \
                  node_modules/.vite-temp {apps,packages}/*/node_modules/.vite
                find apps packages -maxdepth 2 -type d -empty -delete
                install -Dm755 "$TMPDIR/xlsx-sidecar" "$sidecar"
              )
              makeWrapper ${electron}/bin/electron "$out/bin/genoffice-app" \
                --add-flags "$out/lib/genoffice/apps/shell"
              cli="$out/lib/genoffice/packages/cli"
              makeWrapper ${nodejs}/bin/node "$cli/bin/genoffice" \
                --add-flags "$cli/dist/genoffice.cjs" \
                --set-default GENOFFICE_APP_BIN "$out/bin/genoffice-app"
              ln -s "$cli/bin/genoffice" "$out/bin/genoffice"
              runHook postInstall
            '';

            meta = {
              description = "AI-native office suite (docs, sheets, slides, pdf, markdown, html)";
              homepage = "https://github.com/genspark-ai/genoffice";
              license = pkgs.lib.licenses.asl20;
              platforms = pkgs.lib.platforms.linux;
              mainProgram = "genoffice";
            };
          };
        }
      );

      checks = self.packages;

      apps = forAllSystems (system: {
        genoffice-app = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/genoffice-app";
          meta.description = "GenOffice desktop app";
        };
      });
    };
}
