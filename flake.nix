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
  };

  outputs = { self, nixpkgs }: let
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
    lib = pkgs.lib;

    # Yocto specifc:
    yxInit = pkgs.writeScriptBin "yx-init" ''
      #!/usr/bin/env bash
      echo "[yx-env] Running fhs-init..."
      /bin/fhs-init
      exec "$@"
    '';

    # Yocto specifc:
    # Create a custom etc/oe-release file for the yx environment:
    osRelease = pkgs.writeTextDir "etc/os-release" ''
      PRETTY_NAME="Why-Ex Environment"
      NAME="yx-env"
      ID="yxenv"
      VERSION_ID="0.0.1"
    '';

    # Yocto specifc:
    fakeSudo = pkgs.writeScriptBin "sudo" ''
      #!/bin/sh
      exec "$@"
    '';

    # Yocto specifc:
    lz4C = pkgs.writeScriptBin "lz4c" ''
      #!/bin/sh
      exec "lz4 $@"
    '';

    # Yocto specifc:
    # This wrapper fixes the "one giant filename" issue
    rpcgen-wrapper = pkgs.writeShellScriptBin "rpcgen" ''
      # CPP often looks like "gcc -E --sysroot=..."
      # which breaks rpcgen!
      if [ -n "$CPP" ]; then
        # Redefine CPP:
        CPP=$(echo $CPP | awk '{print $1}' | sed 's/gcc/cpp/')
      fi
      exec ${pkgs.rpcsvc-proto}/bin/rpcgen "$@"
    '';

    mkEnv = profile:
    let
      yxPkgs = profile.pkgs;

      fhs = import ./lib/fhs-compat.nix {
        inherit pkgs;
        extraPkgs = yxPkgs
          ++ [ fakeSudo lz4C (lib.hiPrio rpcgen-wrapper) osRelease yxInit ];
      };

      toolchain = import ./lib/yx-toolchain.nix {
        inherit pkgs;
        inputPkgs = yxPkgs;
      };

    in {
      # Creating a FHS compatible shell
      devShell = pkgs.buildFHSEnv {
        name = "yx-env-${profile.name}";
        targetPkgs = pkgs:
          fhs.allPkgs
          ++ [ fhs.init ]
          ++ pkgs.lib.optional profile.enableToolchain toolchain.cc;

        # This script runs when the shell (or nix develop) starts
        profile = ''
          export LANG=en_US.UTF-8
          export LC_ALL=en_US.UTF-8
        '';

        runScript = "bash";
      };

      # Creating a FHS compatible container
      container = pkgs.dockerTools.buildLayeredImage {
        name = "yx-env";
        tag = profile.name;
        # This (now) breaks reproducibility:
        #created = "now";

        # Contents to include in the image root
        contents = [
          fhs.rootfs
          fhs.init
          pkgs.dockerTools.binSh
          pkgs.dockerTools.usrBinEnv
          pkgs.dockerTools.caCertificates
          pkgs.dockerTools.fakeNss
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
        '';

        config = {
          Entrypoint = [ "/bin/yx-init" ];
          Cmd = [ "bash" ];
          Env = [
            "LANG=en_US.UTF-8"
            "LC_ALL=en_US.UTF-8"
          ];
        };
      };
    };

    minimalProfile = import ./profiles/minimal.nix { inherit pkgs; };
    yoctoProfile = import ./profiles/yocto.nix { inherit pkgs; };

  in {
    devShells.${system} = {
      minimal = (mkEnv minimalProfile).devShell.env;
      yocto = (mkEnv yoctoProfile).devShell.env;
    };

    packages.${system} = {
      minimal-container = (mkEnv minimalProfile).container;
      yocto-container = (mkEnv yoctoProfile).container;
    };

  };
}
