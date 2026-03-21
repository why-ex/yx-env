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
# packages.nix
# Core nix packages for the yocto build environment.
{ pkgs }: with pkgs; [
  bashInteractive
  bzip2
  hello
  chrpath
  coreutils
  cpio
  diffstat
  diffutils
  file
  findutils
  gawk
  git
  # Make glibc high priority so its zdump wins over tzdata's version:
  (lib.hiPrio glibc)
  (lib.hiPrio glibc.bin)
  (lib.hiPrio glibc.dev) # glibc wins the conflict
  glibcLocalesUtf8
  gnugrep
  gnulib
  gnumake
  gnused
  gnutar
  gzip
  hostname
  iproute2
  less
  libtinfo
  libxcrypt
  locale
  patch
  perl
  python3
  rpcsvc-proto
  strace
  texinfo
  tmux
  tzdata
  util-linux
  vim
  wget
  which
  xz
  zlib
  zstd
]
