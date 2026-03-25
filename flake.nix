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

    yxInit = pkgs.writeScriptBin "yx-init" ''
      #!/usr/bin/env bash
      echo "[yx-env] Re-generating ld.so.cache..."
      ldconfig -f /etc/ld.so.conf -C /tmp/yx-env-ld.so.cache
      exec "$@"
    '';

    # Create a custom etc/oe-release file for the yx environment:
    osRelease = pkgs.writeTextDir "etc/os-release" ''
      PRETTY_NAME="Why-Ex Environment"
      NAME="yx-env"
      ID="yxenv"
      VERSION_ID="0.0.1"
    '';

    fakeSudo = pkgs.writeScriptBin "sudo" ''
      #!/bin/sh
      exec "$@"
    '';

    lz4C = pkgs.writeScriptBin "lz4c" ''
      #!/bin/sh
      exec "lz4 $@"
    '';

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

    yxCommonPkgs = import ./packages.nix { inherit pkgs; };

    # Extract lib directories automatically
    yxLibDirs = lib.flatten (map (p:
      let libPath = "${p}/lib";
      in if builtins.pathExists libPath then [ libPath ] else []
    ) yxCommonPkgs);

    yxGenLDFlags = pkg: ''
      if [ -d ${pkg}/lib ]; then
        echo -L${pkg}/lib >> $out/nix-support/cc-ldflags
      fi
    '';

    yxAllLDFlags = builtins.concatStringsSep "\n" (map yxGenLDFlags yxCommonPkgs);

    yxCC = pkgs.wrapCCWith {
      cc = pkgs.stdenv.cc.cc;
      bintools = pkgs.binutils;
      libc = pkgs.glibc;
      extraBuildCommands = ''
        mkdir -p $out/lib
        ${yxAllLDFlags}
        #echo "-lcrypt" >> $out/nix-support/cc-ldflags
      '';
    };

    yxAllPkgs = yxCommonPkgs ++ [ fakeSudo lz4C (lib.hiPrio rpcgen-wrapper) osRelease yxInit yxCC ];

    # Creating a FHS shell
    yxFHSEnv = pkgs.buildFHSEnv {
      name = "yx-fhs-env";
      targetPkgs = pkgs: yxAllPkgs ++ [
        # Create a Python environment that includes the missing module
        (pkgs.python3.withPackages (ps: with ps; [
          argcomplete
          # add other modules here
       ]))
      ];

      # This script runs when the shell (or nix develop) starts
      profile = ''
        export LANG=en_US.UTF-8
        export LC_ALL=en_US.UTF-8
      '';

      runScript = "bash";
    };

    # Define the "FHS-like" environment
    yxEnvBase = pkgs.buildEnv {
      name = "yx-env-root-layout";
      # List all packages you want in the standard paths
      paths = yxAllPkgs;

      # Either package priority or this (see glibc.dev in packages.nix)
      #ignoreCollisions = true;
    };

    yxEnv = pkgs.runCommand "yx-env-sysroot" {
      #nativeBuildInputs = [ pkgs.breakpointHook ];
    } ''
      set -x
      mkdir -p $out

      # Copy base environment
      cp -r ${yxEnvBase}/* $out/

      echo "Setting up FHS sysroot..."
      # ---- Create FHS structure ----
      mkdir -p $out/usr/include
      mkdir -p $out/usr/lib
      mkdir -p $out/usr/bin

      # ---- Headers ----
      ln -sf ${pkgs.glibc.dev}/include/* $out/usr/include/

      # ---- Locale archive (CRITICAL) ----
      rm -rf $out/usr/lib/locale
      mkdir -p $out/usr/lib/locale
      ln -sf ${pkgs.glibc}/lib/locale/* $out/usr/lib/locale/
      ln -sf ${pkgs.glibcLocalesUtf8}/lib/locale/locale-archive \
         $out/usr/lib/locale/

      # ---- ld.so.cache ----
      chmod 777 $out/etc
      # provide linker config
      cat > $out/etc/ld.so.conf <<EOF
/usr/lib
/lib
/lib64
EOF
cat $out/etc/ld.so.conf
      ln -sf /tmp/yx-env-ld.so.cache $out/etc/ld.so.cache
      chmod 555 $out/etc

      echo "[yx-env] Populating /usr/lib from container closure..."
      # Symlink all shared libraries
      for libdir in ${lib.concatStringsSep " " yxLibDirs}; do
        if [ -d "$libdir" ]; then
          for f in $libdir/*.so*; do
            [ -e "$f" ] || continue
            ln -sf "$f" $out/usr/lib/
          done
        fi
      done
      mkdir -p $out/lib64
      ln -sf ${pkgs.nix-ld}/libexec/nix-ld $out/lib64/ld-linux-x86-64.so.2
      mkdir -p $out/run/current-system/sw/share/nix-ld/lib
      ln -sf ${pkgs.glibc.bin}/bin/ld.so $out/run/current-system/sw/share/nix-ld/lib/
      ln -sf ${pkgs.zlib}/lib/*.so* $out/run/current-system/sw/share/nix-ld/lib/

      # ---- Binaries ----
      cp -pP $out/bin/* $out/usr/bin/
    '';

  in {
    # Creating a FHSEnv shell
    devShells.${system}.default = yxFHSEnv.env;

    packages.${system} = {
      yxEnv = yxEnv;

      container = pkgs.dockerTools.buildImage {
        name = "yx-env";
        tag = "latest";
        # This (now) breaks reproducibility:
        #created = "now";

        # Contents to include in the image root
        copyToRoot = [
          yxEnv
          pkgs.dockerTools.binSh
          pkgs.dockerTools.usrBinEnv
          pkgs.dockerTools.caCertificates
          pkgs.dockerTools.fakeNss
        ];

        extraCommands = ''
          # Optional: remove leftover docs
          rm -rf $out/share/{man,doc,info}
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
  };
}
