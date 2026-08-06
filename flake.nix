/*
   Copyright 2026 Samo Pogačnik

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/
{
  description = "A flake to build yx environments";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";

    # Dedicated package set that is known to provide kas 5.2.  Keep this
    # independent from the main nixpkgs input so kas52 profiles are not
    # affected by unrelated package-set drift.
    nixpkgs-kas52.url = "github:nixos/nixpkgs/5cde78eacb5b519c0b711a7cec1ab1f0dd577183";

    # Pi agent sandbox/runtime used by devShells.${system}.agent.
    pi-en.url = "github:u2up/pi-en";
    pi-en.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-kas52, pi-en }: let
    system = "x86_64-linux"; # Containers must be built for Linux
    config = {
      # Disable docs/manpages globally
      documentation = {
        enable = false;
        doc = false;
        info = false;
        man = false;
      };
    };
    pkgs = nixpkgs.legacyPackages.${system};
    kas52Pkgs = import nixpkgs-kas52 { inherit system config; };
    lib = pkgs.lib;

    yxEnvVer = "0.1.6";

    # Create a custom etc/os-release file for the yx environment:
    osRelease = pkgs.writeTextDir "etc/os-release" ''
      PRETTY_NAME="Why-Ex Environment"
      NAME="yx-env"
      ID="yxenv"
      VERSION_ID="${yxEnvVer}"
    '';

    fakeSudo = pkgs.writeScriptBin "sudo" ''
      #!/bin/sh
      exec "$@"
    '';

    mkEnv = profile:
    let
      yxPkgs = profile.pkgs ++ yxExtraPkgs;

      toolchain = import ./lib/yx-toolchain.nix {
        inherit pkgs;
        inputPkgs = yxPkgs;
      };
      isGcc = pkg: builtins.match "^gcc.*" pkg.name != null;
      fhsInputPkgs =
        if profile.enableToolchain then
          /* Remove original gcc from the list because it
           * will be replaced by toolchain.cc wrapper. */
          builtins.filter (pkg: !isGcc pkg) yxPkgs
        else
          yxPkgs;

      yxInit = pkgs.writeScriptBin "yx-init" ''
        #!/usr/bin/env bash
        echo "[yxenv] Running fhs-init..."
        /bin/fhs-init
        if [ -n "${profile.extraEntryPoint}" ]; then
          exec ${profile.extraEntryPoint} "$@"
        fi
        exec "$@"
      '';

      fhs = import ./lib/fhs-compat.nix {
        inherit pkgs;
        extraPkgs = fhsInputPkgs
          ++ [ fakeSudo osRelease yxInit ];
      };

      envName = "${yxEnvVer}-" + profile.name + (if builtins.length yxExtraPkgs > 0 then yxExtendName else "");

      extraExportLines = builtins.concatStringsSep "\n" (
        map (v: "export ${v}") profile.extraEnvironVars
      );

    in {
      # Creating a FHS compatible shell
      devShell = pkgs.buildFHSEnv {
        name = "yx-env:${envName}";
        targetPkgs = pkgs:
          fhs.allPkgs
          ++ [ fhs.init ]
          ++ pkgs.lib.optional profile.enableToolchain toolchain.cc;

        # This script runs when the shell (or nix develop) starts
        profile = ''
          export LANG=en_US.UTF-8
          export LC_ALL=en_US.UTF-8
          export YXENV=1
          export YXENV_VERSION=${yxEnvVer}
          export YXENV_PROFILE=${profile.name}
          export YXENV_BACKEND=devshell
          export YX_LAYER=env
          ${extraExportLines}
        '';

        runScript = "bash";
      };

      # Creating a FHS compatible container
      container = pkgs.dockerTools.buildLayeredImage {
        name = "yx-env";
        tag = envName;
        # This (now) breaks reproducibility:
        #created = "now";

        # Contents to include in the image root
        contents = [
          fhs.rootfs
          fhs.init
          pkgs.dockerTools.binSh
          pkgs.dockerTools.usrBinEnv
          pkgs.dockerTools.caCertificates
        ]
        ++ pkgs.lib.optional profile.enableToolchain toolchain.cc;

        maxLayers = 2;
        enableFakechroot = true;
        fakeRootCommands = ''
          #!${pkgs.runtimeShell}
          ${pkgs.dockerTools.shadowSetup}
          # Add custom commands here (privileged?):
          # ---- ld.so.cache ----
          # provide linker config
          ${pkgs.coreutils}/bin/cat > /etc/ld.so.conf <<EOF
${pkgs.lib.concatStringsSep "\n" fhs.libDirs}
EOF
          ${pkgs.glibc.bin}/bin/ldconfig -f /etc/ld.so.conf -C /etc/ld.so.cache
          ${pkgs.glibc.bin}/bin/ldconfig -p -C /etc/ld.so.cache
          ${pkgs.coreutils}/bin/touch --reference=/etc/os-release /etc/ld.so.conf
          ${pkgs.coreutils}/bin/touch --reference=/etc/os-release /etc/ld.so.cache
          # Provide different default 'passwd' and 'group' files instead
          # of using 'pkgs.dockerTools.fakeNss'.
          ${pkgs.coreutils}/bin/cat > /etc/passwd <<EOF
root:x:0:0:root user:/var/empty:/bin/sh
nobody:x:65534:65534:nobody:/var/empty:/bin/sh
builder:x:1001:1001::/home/myuser:/bin/sh
EOF
          ${pkgs.coreutils}/bin/cat > /etc/group <<EOF
root:x:0:
nobody:x:65534:
builder:x:1001:
EOF
          mkdir /builder
          mkdir /tmp
          chmod a+rwx,+t /tmp
          mkdir -p /var/tmp
          chmod a+rwx,+t /var/tmp
        '';

        config = {
          Entrypoint = [ "/bin/yx-init" ];
          Cmd = [ "bash" ];
          Env = [
            "LANG=en_US.UTF-8"
            "LC_ALL=en_US.UTF-8"
            "YXENV=1"
            "YXENV_VERSION=${yxEnvVer}"
            "YXENV_PROFILE=${profile.name}"
            "YXENV_BACKEND=container"
            "YX_LAYER=env"
          ] ++ profile.extraEnvironVars;
          Labels = {
            "org.opencontainers.image.title" = "yx-env";
            "org.opencontainers.image.description" = "Reproducible Nix/FHS environments for Yocto and kas builds";
            "org.opencontainers.image.version" = yxEnvVer;
            "org.opencontainers.image.ref.name" = envName;
            "org.opencontainers.image.source" = "https://github.com/why-ex/yx-env";
            "org.opencontainers.image.licenses" = "Apache-2.0";
          };
        };
      };
    };

    yxProfileSet = {
      minimal = import ./profiles/minimal.nix { inherit pkgs; };
      yocto = import ./profiles/yocto.nix { inherit pkgs; };
      yocto-scarthgap = import ./profiles/yocto-scarthgap.nix { inherit pkgs; };
      yocto-scarthgap-kas52 = import ./profiles/yocto-scarthgap-kas52.nix { inherit pkgs kas52Pkgs; };
      yocto-kirkstone = import ./profiles/yocto-kirkstone.nix { inherit pkgs; };
      yocto-kirkstone-kas52 = import ./profiles/yocto-kirkstone-kas52.nix { inherit pkgs kas52Pkgs; };
    };

    # Works for multiple packages set to YXENV_EXTRA:
    # TODO: How to deal with packages like 'acl.bin'?
/*
    resolve = path:
      let
        parts = builtins.filter (x: x != ".")
          (builtins.split "\\." path);
      in
      builtins.foldl'
        (acc: key: acc.${key})
        pkgs
        parts;
    yxExtraPkgs = map resolve (builtins.filter (x: x != []) (builtins.split " " (builtins.getEnv "YXENV_EXTRA")));
    yxExtraPkgs = map (name: pkgs.${name}) (map resolve (builtins.filter (x: x != []) (builtins.split " " (builtins.getEnv "YXENV_EXTRA"))));
*/
    yxExtraPkgs = map (name: pkgs.${name}) (builtins.filter (x: x != "") (builtins.filter (x: x != []) (builtins.split " " (builtins.getEnv "YXENV_EXTRA"))));
    yxExtendName = builtins.getEnv "YXENV_EXTEND";

  in {
    lib.version = yxEnvVer;

    devShells.${system} = (builtins.mapAttrs (name: profile:
      (mkEnv profile).devShell.env
    ) yxProfileSet) // {
      agent = pi-en.lib.mkPiShell {
        inherit pkgs;

        # Set to true if this repository will use pi-en's Git-backed
        # coordination helpers (pien coord ..., pien roles ...).
        includeCoordinationHelpers = true;

        # Add project-specific command-line tools that Pi should be able to run
        # inside the Bubblewrap sandbox.  pi-en already provides its core
        # runtime tools (bash, git, jq, rg, fd, node, etc.).
        extraPackages = with pkgs; [
        ];

        shellHook = ''
          echo "Pi agent shell loaded. Use 'pien' or 'pien shell'."
        '';
      };
    };

    packages.${system} = builtins.mapAttrs (name: profile:
      (mkEnv profile).container
    ) yxProfileSet;

  };
}
