{
  description = "Camoufox browser package and development shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems =
        f:
        nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            inherit system;
            pkgs = nixpkgs.legacyPackages.${system};
          }
        );

      releaseFor =
        system:
        {
          x86_64-linux = {
            version = "150.0.2-alpha.26";
            url = "https://github.com/daijro/camoufox/releases/download/v150.0.2-beta.25/camoufox-150.0.2-alpha.26-lin.x86_64.zip";
            hash = "sha256-sUa5iwwsQQI3Fv7vNkUfMZpTQwn3LFRYSksLiGcPUQs=";
          };
          aarch64-linux = {
            version = "150.0.2-alpha.25";
            url = "https://github.com/daijro/camoufox/releases/download/v150.0.2-beta.25/camoufox-150.0.2-alpha.25-lin.arm64.zip";
            hash = "sha256-socK+M2Zch1BvUjwzOD5SUSat1NkuA7j04m9NZU+ohM=";
          };
        }
        .${system};
    in
    {
      packages = forAllSystems (
        { system, pkgs }:
        let
          release = releaseFor system;

          runtimeLibs = with pkgs; [
            alsa-lib
            at-spi2-atk
            at-spi2-core
            cairo
            cups
            dbus
            expat
            fontconfig
            freetype
            gdk-pixbuf
            glib
            gtk3
            libGL
            libdrm
            libevent
            libffi
            libglvnd
            libjpeg
            libnotify
            libpulseaudio
            libva
            libvdpau
            libwebp
            libxkbcommon
            mesa
            nspr
            nss
            pango
            pipewire
            sqlite
            stdenv.cc.cc
            udev
            vulkan-loader
            wayland
            libice
            libsm
            libx11
            libxscrnsaver
            libxcomposite
            libxcursor
            libxdamage
            libxext
            libxfixes
            libxi
            libxrandr
            libxrender
            libxt
            libxtst
            libxcb
            libxshmfence
            zlib
          ];

          fontPackages = with pkgs; [
            dejavu_fonts
            liberation_ttf
            noto-fonts
            noto-fonts-cjk-sans
            noto-fonts-color-emoji
          ];

          fontconfigFile = pkgs.makeFontsConf {
            fontDirectories = fontPackages;
          };
        in
        rec {
          camoufox = pkgs.stdenvNoCC.mkDerivation {
            pname = "camoufox";
            inherit (release) version;

            src = pkgs.fetchurl {
              inherit (release) url hash;
            };

            nativeBuildInputs = with pkgs; [
              autoPatchelfHook
              makeWrapper
              patchelfUnstable
              unzip
            ];

            buildInputs = runtimeLibs;
            patchelfFlags = [ "--no-clobber-old-sections" ];

            dontConfigure = true;
            dontBuild = true;
            dontStrip = true;

            unpackPhase = ''
              runHook preUnpack

              mkdir source
              unzip -q "$src" -d source
              cd source

              runHook postUnpack
            '';

            installPhase = ''
              runHook preInstall

              mkdir -p "$out/lib/camoufox" "$out/bin"
              cp -R . "$out/lib/camoufox/"
              chmod -R u+w "$out/lib/camoufox"

              runHook postInstall
            '';

            postFixup = ''
              for program in camoufox camoufox-bin; do
                if [ -x "$out/lib/camoufox/$program" ]; then
                  makeWrapper "$out/lib/camoufox/$program" "$out/bin/$program" \
                    --set FONTCONFIG_FILE "${fontconfigFile}" \
                    --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath runtimeLibs}" \
                    --prefix PATH : "${pkgs.lib.makeBinPath [ pkgs.xdg-utils ]}" \
                    --prefix XDG_DATA_DIRS : "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}:${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.hicolor-icon-theme}/share"
                fi
              done

              if [ ! -e "$out/bin/camoufox" ] && [ -e "$out/bin/camoufox-bin" ]; then
                ln -s "$out/bin/camoufox-bin" "$out/bin/camoufox"
              fi
            '';

            meta = with pkgs.lib; {
              description = "Camoufox, a Firefox fork built for AI agents";
              homepage = "https://camoufox.com";
              license = licenses.mpl20;
              platforms = supportedSystems;
              mainProgram = "camoufox";
              sourceProvenance = [ sourceTypes.binaryNativeCode ];
            };
          };

          default = camoufox;
        }
      );

      devShells = forAllSystems (
        { pkgs, ... }:
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              aria2
              cacert
              curl
              git
              go
              jq
              msitools
              nodejs_22
              p7zip
              pkg-config
              python3
              python3Packages.build
              python3Packages.pip
              rustup
              sqlite
              unzip
              wget
              xvfb-run
              zip
            ];

            shellHook = ''
              export MOZBUILD_STATE_PATH="''${MOZBUILD_STATE_PATH:-$HOME/.mozbuild}"
              export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
            '';
          };
        }
      );
    };
}
