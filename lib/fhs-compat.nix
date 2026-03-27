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
, extraPkgs ? []
, ldSoCachePath ? "/tmp/fhs-env-ld.so.cache"
}:

let
  lib = pkgs.lib;

  fhsBasePkgs = [
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

  fhsCommonPkgs = fhsBasePkgs ++ extraPkgs;

  fhsInit = pkgs.writeScriptBin "fhs-init" ''
    #!/bin/sh
    set -e
    CACHE=${ldSoCachePath}
    echo "[fhs-init] Generating ld.so.cache at $CACHE"
    # Ensure directory exists
    mkdir -p "$(dirname "$CACHE")"

    ldconfig -f /etc/ld.so.conf -C "$CACHE"
  '';

  # Extract lib directories automatically
  fhsLibDirs = lib.flatten (map (p:
    let libPath = "${p}/lib";
    in if builtins.pathExists libPath then [ libPath ] else []
  ) fhsCommonPkgs);

  fhsGenLDFlags = pkg: ''
    if [ -d ${pkg}/lib ]; then
      echo -L${pkg}/lib >> $out/nix-support/cc-ldflags
    fi
  '';

  fhsAllLDFlags = builtins.concatStringsSep "\n" (map fhsGenLDFlags fhsCommonPkgs);

  fhsCC = pkgs.wrapCCWith {
    cc = pkgs.stdenv.cc.cc;
    bintools = pkgs.binutils;
    libc = pkgs.glibc;
    extraBuildCommands = ''
      mkdir -p $out/lib
      ${fhsAllLDFlags}
      #echo "-lcrypt" >> $out/nix-support/cc-ldflags
    '';
  };

  fhsAllPkgs = fhsCommonPkgs ++ [ fhsInit fhsCC ];

  # Define the "FHS-like" environment
  fhsEnvBase = pkgs.buildEnv {
    name = "fhs-env-base";
    # List all packages you want in the standard paths
    paths = fhsAllPkgs;

    # Either package priority or this (see glibc.dev in packages.nix)
    #ignoreCollisions = true;
  };

 in {
  allPkgs = fhsAllPkgs;
  packages = pkgs.runCommand "fhs-env" {
    #nativeBuildInputs = [ pkgs.breakpointHook ];
  } ''
    echo "Setting up FHS sysroot..."
    set -x
    mkdir -p $out

    # Copy base environment
    cp -r ${fhsEnvBase}/* $out/

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
    ln -sf ${ldSoCachePath} $out/etc/ld.so.cache
    chmod 555 $out/etc

    echo "[fhs-env] Populating /usr/lib from container closure..."
    # Symlink all shared libraries
    for libdir in ${lib.concatStringsSep " " fhsLibDirs}; do
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
}
