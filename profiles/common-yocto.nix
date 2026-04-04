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
# common-yocto.nix
# Profile for the yocto build environment.
{ pkgs }:

let
  lib = pkgs.lib;

  # Wrapper for a missing executable required in Yocto:
  lz4C = pkgs.writeShellScriptBin "lz4c" ''
    exec ${pkgs.lz4.out}/bin/lz4 "$@"
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

in
  [ lz4C (lib.hiPrio rpcgen-wrapper) ]
