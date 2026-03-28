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
{ pkgs
, extraPkgs ? []     # additional packages to include in environment
, libDir ? "/run/current-system/sw/share/nix-ld/lib"
}:

let
  lib = pkgs.lib;

  # Canonical dynamic linker (always correct for stdenv)
  dynamicLinker =
    lib.fileContents "${pkgs.stdenv.cc}/nix-support/dynamic-linker";

  # --- Base packages required for FHS compatibility ---
  basePkgs = [
    #pkgs.stdenv.cc.cc #!!!Do not enable - breaks things!!!
    #pkgs.binutils #!!!Do not enable - breaks things!!!
    # Make glibc high priority so its zdump wins over tzdata's version:
    (lib.hiPrio pkgs.glibc)
    (lib.hiPrio pkgs.glibc.bin)
    (lib.hiPrio pkgs.glibc.dev) # glibc wins the conflict
    pkgs.glibcLocalesUtf8
    pkgs.libxcrypt
    pkgs.locale
    pkgs.nix-ld
    pkgs.zlib
  ];

  allPkgs = basePkgs ++ extraPkgs;

  # --- Collect all lib directories dynamically ---
  libDirs = lib.flatten (map (p:
    let d = "${p}/lib";
    in if builtins.pathExists d then [ d ] else []
  ) allPkgs);

  # --- Script to populate a directory with .so symlinks ---
  linkLibs = target: ''
    mkdir -p ${target}
    for libdir in ${lib.concatStringsSep " " libDirs}; do
      if [ -d "$libdir" ]; then
        for f in $libdir/*.so*; do
          [ -e "$f" ] || continue
          ln -sf "$f" ${target}/
        done
      fi
    done
  '';

  # --- Runtime init (for ld cache) ---
  fhsInit = pkgs.writeScriptBin "fhs-init" ''
    #!/bin/sh
    set -e
    echo "[fhs-init] ..."
  '';

  # --- Define the "FHS-like" environment ---
  envBase = pkgs.buildEnv {
    name = "fhs-env-base";
    # List all packages you want in the standard paths
    paths = allPkgs;

    # Either package priority or this (see glibc.dev in packages.nix)
    #ignoreCollisions = true;
  };

 in {
  # Packages usable in buildFHSEnv
  inherit allPkgs;

  # Full filesystem tree (for containers)
  rootfs = pkgs.runCommand "fhs-env-rootfs" {} ''
    echo "[fhs-rootfs] Setting up FHS sysroot..."
    set -e
    set -x
    mkdir -p $out

    echo "[fhs-rootfs] Copying base environment..."
    cp -r ${envBase}/* $out/

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

    # --- Populate /usr/lib ---
    echo "[fhs-rootfs] Populating /usr/lib..."
    ${linkLibs "$out/usr/lib"}

    # --- Cleanup-populate /lib ---
    echo "[fhs-rootfs] Cleanup-populate /lib..."
    chmod 777 $out/lib
    rm -f $out/lib/*[ch]
    ${linkLibs "$out/lib"}
    chmod 555 $out/lib

    # --- Dynamic linker (critical) ---
    mkdir -p $out/lib64
    ln -sf ${pkgs.nix-ld}/libexec/nix-ld $out/lib64/ld-linux-x86-64.so.2

    # --- nix-ld fallback library pool ---
    mkdir -p $out${libDir}
    ln -sf ${pkgs.glibc.bin}/bin/ld.so $out${libDir}/
    ${linkLibs "$out${libDir}"}

    # ---- Binaries ----
    cp -pP $out/bin/* $out/usr/bin/

    echo "[fhs-rootfs] Rootfs ready"
  '';

  # Runtime helper (to include into final environment)
  init = fhsInit;

  # Metadata (useful for debugging / versioning)
  meta = {
    inherit dynamicLinker libDir;
    pkgs = allPkgs;
    libDirs = libDirs;
  };
}
