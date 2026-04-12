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
# yocto-kirkstone-kas52.nix
# Profile for the yocto build environment.
{ pkgs }:

let
  kasInit = pkgs.writeScriptBin "container-entrypoint"
    (builtins.readFile ../contrib/kas/container-entrypoint);

  oeGitProxy = pkgs.writeShellScriptBin "oe-git-proxy"
    (builtins.readFile ../contrib/kas/oe-git-proxy);

  common-yocto = import ./common-yocto.nix { inherit pkgs; };
in
{
  name = "yocto-kirkstone-kas52";

  pkgs = import ./pkgs-yocto-kirkstone-kas52.nix { inherit pkgs; }
    ++ common-yocto ++ [ kasInit oeGitProxy ];

  enableToolchain = true;
  extraEntryPoint = "/bin/container-entrypoint";
  extraEnvironVars = [
    "GIT_PROXY_COMMAND=oe-git-proxy"
    "NO_PROXY=*"
  ];
}
