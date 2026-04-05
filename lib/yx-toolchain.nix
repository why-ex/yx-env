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
, inputPkgs ? []
}:

let
  lib = pkgs.lib;

  has = pkg: builtins.elem pkg inputPkgs;
  gcc =
    if has pkgs.gcc13 then (pkgs.overrideCC pkgs.stdenv pkgs.gcc13).cc.cc
    else pkgs.stdenv.cc.cc; # default (latest version)

  allPkgs = inputPkgs ++ ( import ./lib-common-pkgs.nix { inherit pkgs; } );

  # Collect lib paths
  libDirs = lib.flatten (map (p:
    let d = "${p}/lib";
    in if builtins.pathExists d then [ d ] else []
  ) allPkgs);

  ldFlags = lib.concatMapStrings (d: "-L${d} ") libDirs;

  # Collect include paths
  incDirs = lib.flatten (map (p:
    let d = "${p}/include";
    in if builtins.pathExists d then [ d ] else []
  ) [ pkgs.libxcrypt ]);

  cFlags = lib.concatMapStrings (d: "-I${d} ") incDirs;

in {
  cc = pkgs.wrapCCWith {
    cc = gcc;
    bintools = pkgs.binutils;
    libc = pkgs.glibc;

    extraBuildCommands = ''
      mkdir -p $out/nix-support
      echo "${ldFlags}" >> $out/nix-support/cc-ldflags
      echo "${cFlags}" >> $out/nix-support/cc-cflags
    '';
  };
}
