{
  description = "Elastic Dashboard for Linux";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      webrtcHashes = {
        x86_64-linux = "796bd7655e6bea76f851f0420721f7f017fe35c5acbef46b49c908a0801949af";
        aarch64-linux = "423356747c674d6434627d0d6c28d978abf1f34f746624f77467d40018e6b5cd";
      };
      forLinux = nixpkgs.lib.genAttrs (builtins.attrNames webrtcHashes);

      desktopLibraries = pkgs: [
        pkgs.gtk3
        pkgs.libdrm
        pkgs.libgbm
        pkgs.libx11
        pkgs.libxcomposite
        pkgs.libxdamage
        pkgs.libxext
        pkgs.libxfixes
        pkgs.libxrandr
        pkgs.stdenv.cc.cc.lib
      ];
      audioLibraries = pkgs: [ pkgs.alsa-lib pkgs.libpulseaudio ];
      linuxFlutter = pkgs: pkgs.flutter347.override {
        supportedTargetFlutterPlatforms = [ "universal" "linux" ];
      };
    in
    {
      packages = forLinux (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          webrtcArch = if pkgs.stdenv.hostPlatform.isAarch64 then "arm64" else "x64";
          webrtcAsset = "libwebrtc-linux-${webrtcArch}-release";
          webrtcVersion = "libwebrtc.m144.7559.09";
          webrtcArchive = pkgs.fetchurl {
            url = "https://github.com/webrtc-sdk/libwebrtc/releases/download/${webrtcVersion}/${webrtcAsset}.zip";
            sha256 = webrtcHashes.${system};
          };
          pubspec = builtins.readFile ./pubspec.yaml;
          version = builtins.head (builtins.match ".*\nversion: ([^\n]+)\n.*" pubspec);
          buildFlutterApplication = pkgs.flutter347.buildFlutterApplication.override {
            flutter = linuxFlutter pkgs;
          };
        in
        {
          default = buildFlutterApplication {
            pname = "elastic-dashboard";
            inherit version;
            src = self;
            autoPubspecLock = ./pubspec.lock;

            # Stage the binary where the plugin's CMake script expects its cached download.
            customSourceBuilders.flutter_webrtc =
              { src, version, ... }:
              pkgs.runCommand "pub-flutter_webrtc-${version}-with-libwebrtc" {
                inherit (src) passthru;
                nativeBuildInputs = [ pkgs.autoPatchelfHook pkgs.unzip ];
                buildInputs = desktopLibraries pkgs;
              } ''
                cp -r "${src}" "$out"
                chmod -R u+w "$out"
                mkdir -p "$out/third_party/downloads"
                ln -s "${webrtcArchive}" "$out/third_party/downloads/${webrtcAsset}.zip"
                unzip -q "${webrtcArchive}" -d "$out/third_party"
                mv "$out/third_party/linux-${webrtcArch}-release" "$out/third_party/libwebrtc"
                autoPatchelf "$out/third_party/libwebrtc/lib"
              '';

            # Elastic selects an explicit button theme. Skip the unused GTK
            # theme lookup, which cannot read NixOS's file-db DConf profiles.
            customSourceBuilders.titlebar_buttons =
              { src, version, ... }:
              pkgs.runCommand "pub-titlebar_buttons-${version}-explicit-theme" {
                inherit (src) passthru;
              } ''
                cp -r "${src}" "$out"
                chmod u+w "$out/lib/src" "$out/lib/src/decorated_button.dart"
                substituteInPlace "$out/lib/src/decorated_button.dart" \
                  --replace-fail '    getTheme().then((value) => setState(() => theme = value));' \
                  '    if (widget.type == null || widget.type == ThemeType.auto) {
                      getTheme().then((value) {
                        if (mounted) setState(() => theme = value);
                      });
                    }'
              '';

            nativeBuildInputs = [ pkgs.autoPatchelfHook ];
            buildInputs = desktopLibraries pkgs;
            runtimeDependencies = audioLibraries pkgs;
            flutterBuildFlags = [
              "--dart-define=ELASTIC_WPILIB=false"
            ];
            meta.mainProgram = "elastic_dashboard";
          };
        }
      );

      devShells = forLinux (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          libraries = desktopLibraries pkgs;
        in
        {
          default = pkgs.mkShell {
            packages = [
              (linuxFlutter pkgs)
              pkgs.git
              pkgs.pkg-config
            ];
            buildInputs = libraries;
            LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (libraries ++ audioLibraries pkgs);
          };
        }
      );
    };
}
