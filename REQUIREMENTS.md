# yx-env Requirements

`yx-env` provides reproducible Nix-based FHS-compatible environments and container images for Yocto/kas builds.

This file is specific to the `yx-env` project. Common requirements are in `../REQUIREMENTS.md`.

## Project Scope Requirements

### YXENV-SCOPE-001: Environment factory role

`yx-env` MUST prepare reproducible environments. It MUST NOT become the primary Yocto workflow frontend. User workflow orchestration belongs in `yx`.

Verification:

- `yx-env` exposes Nix dev shells and container images.
- kas/BitBake workflow commands are not implemented as first-class `yx-env` CLI commands beyond entering/building environments.

### YXENV-SCOPE-002: Supported environment forms

`yx-env` MUST support both:

- local FHS-compatible development shells via `buildFHSEnv`;
- OCI/Docker-compatible container images via `dockerTools.buildLayeredImage`.

Verification:

```sh
cd yx-env
nix develop .#yocto -c true
nix build .#yocto
```

## Flake Requirements

### YXENV-FLAKE-001: Flake outputs

`yx-env` MUST expose one dev shell and one container package per supported profile:

```nix
devShells.x86_64-linux.<profile>
packages.x86_64-linux.<profile>
```

Verification:

```sh
cd yx-env
nix flake show
```

### YXENV-FLAKE-002: Version output

`yx-env` MUST expose its version as:

```nix
lib.version
```

Verification:

```sh
cd yx-env
nix eval --raw .#lib.version
```

Current expected value:

```text
0.1.4
```

### YXENV-FLAKE-003: Linux container system

Container packages MUST be built for `x86_64-linux` unless multi-system container support is explicitly added.

Verification:

- Inspect `flake.nix` for `system = "x86_64-linux"`.
- Build a container package on a compatible builder.

### YXENV-FLAKE-004: Reproducible image creation time

Container images MUST NOT use a non-reproducible creation timestamp such as `created = "now"`.

Verification:

- Inspect `flake.nix` and confirm `created = "now"` is not active.

## Profile Requirements

### YXENV-PROF-001: Supported profiles

`yx-env` MUST provide at least these profiles:

- `minimal`
- `yocto`
- `yocto-scarthgap`
- `yocto-scarthgap-kas52`
- `yocto-kirkstone`
- `yocto-kirkstone-kas52`

Verification:

```sh
cd yx-env
nix flake show | grep -E 'minimal|yocto|yocto-scarthgap|yocto-kirkstone'
```

### YXENV-PROF-002: Profile schema

Each profile MUST define:

- `name`
- `pkgs`
- `enableToolchain`
- `extraEntryPoint`
- `extraEnvironVars`

Verification:

- Inspect files under `profiles/*.nix`.
- Evaluate all dev shells or packages.

### YXENV-PROF-003: Common Yocto helpers

Yocto profiles MUST include common Yocto helper wrappers:

- `lz4c`, mapping to the Nix-provided `lz4` binary;
- high-priority `rpcgen` wrapper that sanitizes `CPP` when Yocto passes a command string.

Verification:

```sh
cd yx-env
nix develop .#yocto -c which lz4c
nix develop .#yocto -c which rpcgen
```

### YXENV-PROF-004: Yocto host tools

Yocto profiles MUST include the common host tools required by supported Yocto releases. At minimum they SHOULD include:

- shell/core tools: `bashInteractive`, `coreutils`, `findutils`, `gnugrep`, `gnused`, `gawk`, `which`
- archive/compression tools: `bzip2`, `cpio`, `gzip`, `lz4`, `xz`, `zstd`, `gnutar`
- build tools: `gnumake`, `patch`, `diffutils`, `diffstat`, `chrpath`, `file`, `texinfo`
- VCS/network/debug tools: `git`, `wget`, `iproute2`, `hostname`, `strace`
- language/runtime tools: `perl`, `python3` or release-specific Python
- Yocto-specific native helpers: `rpcsvc-proto`

Verification:

- Inspect `profiles/pkgs-yocto*.nix`.
- Enter profile and check representative tools with `which`.

### YXENV-PROF-005: Release-specific packages

Release-specific profiles MAY include release-specific package versions, such as `gcc13`, `python311`, or `file.dev` for Kirkstone compatibility.

Verification:

- Inspect `profiles/pkgs-yocto-kirkstone*.nix`.

### YXENV-PROF-006: kas profiles

Profiles with `kas` in the name MUST include:

- the `kas` package;
- `gosu`;
- `shadow` with PAM disabled;
- a kas-compatible container entrypoint package;
- `oe-git-proxy` if `GIT_PROXY_COMMAND=oe-git-proxy` is exported.

Verification:

```sh
cd yx-env
nix develop .#yocto-scarthgap-kas52 -c which kas
nix develop .#yocto-scarthgap-kas52 -c which gosu
nix develop .#yocto-scarthgap-kas52 -c which oe-git-proxy
```

### YXENV-PROF-007: kas version naming

If a profile name contains a kas version suffix such as `kas52`, the implementation MUST either:

- pin/assert that exact kas version, or
- document that the suffix is compatibility-oriented rather than an exact package version.

Verification:

- Run `kas --version` inside the profile.
- Inspect documentation and/or Nix assertions.

### YXENV-PROF-008: Proxy helper dependency

If `oe-git-proxy` is installed and exported through `GIT_PROXY_COMMAND`, the profile MUST include `socat`, or the proxy command MUST not be enabled.

Verification:

```sh
cd yx-env
nix develop .#yocto-scarthgap-kas52 -c which socat
```

## FHS Compatibility Requirements

### YXENV-FHS-001: FHS-like root filesystem

`yx-env` MUST construct an FHS-like root filesystem for containers with standard directories such as:

- `/bin`
- `/usr/bin`
- `/usr/lib`
- `/usr/include`
- `/lib`
- `/lib64`
- `/tmp`
- `/var/tmp`

Verification:

- Build/load a container and inspect these paths.
- Inspect `lib/fhs-compat.nix`.

### YXENV-FHS-002: Locale support

Environments MUST set UTF-8 locale variables and provide glibc locale support.

Required environment variables:

```sh
LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8
```

Verification:

```sh
cd yx-env
nix develop .#yocto -c sh -c 'test "$LANG" = en_US.UTF-8 && test "$LC_ALL" = en_US.UTF-8'
```

### YXENV-FHS-003: Dynamic linker and library cache

Container root filesystems MUST provide the dynamic linker path and an `ld.so.cache` generated from the environment libraries.

Verification:

- Inspect built container for `/lib64/ld-linux-x86-64.so.2`.
- Inspect container for `/etc/ld.so.conf` and `/etc/ld.so.cache`.

### YXENV-FHS-004: Headers and libraries

The FHS root filesystem MUST expose glibc/libxcrypt headers and shared libraries under FHS-style include/library locations where needed by native Yocto tools.

Verification:

- Inspect `/usr/include`, `/usr/lib`, and `/lib` in built container.
- Compile or execute representative native Yocto helper checks where practical.

### YXENV-FHS-005: fake sudo

The environment MAY provide a fake `sudo` wrapper that executes the requested command directly. If provided, it MUST be clearly limited to environment compatibility and MUST NOT claim to provide privilege escalation.

Verification:

```sh
cd yx-env
nix develop .#yocto -c sudo true
```

## Toolchain Requirements

### YXENV-TC-001: Optional wrapped toolchain

Profiles with `enableToolchain = true` MUST use the wrapped toolchain provided by `lib/yx-toolchain.nix`.

Verification:

- Inspect `flake.nix`: profiles with `enableToolchain` include `toolchain.cc`.
- Enter profile and inspect compiler availability.

### YXENV-TC-002: GCC replacement behavior

When a profile enables the wrapped toolchain, original `gcc*` packages in the profile package list MUST be filtered out before creating the FHS package list, so the wrapped compiler wins.

Verification:

- Inspect `isGcc` filtering in `flake.nix`.
- Enter Kirkstone profile and verify expected compiler wrapper behavior.

### YXENV-TC-003: Include/library flags

The wrapped compiler SHOULD include needed library and include search paths from profile packages and common packages.

Verification:

- Inspect generated `$CC/nix-support/cc-ldflags` and `cc-cflags` where accessible.

## Environment Metadata Requirements

### YXENV-META-001: Environment markers in dev shells

Every dev shell MUST export:

```sh
YXENV=1
YXENV_VERSION=<version>
YXENV_PROFILE=<profile>
YXENV_BACKEND=devshell
YX_LAYER=env
```

Verification:

```sh
cd yx-env
nix develop .#yocto -c sh -c 'test "$YXENV" = 1 && test "$YXENV_PROFILE" = yocto && test "$YXENV_BACKEND" = devshell && test "$YX_LAYER" = env'
```

### YXENV-META-002: Environment markers in containers

Every container image MUST set:

```sh
YXENV=1
YXENV_VERSION=<version>
YXENV_PROFILE=<profile>
YXENV_BACKEND=container
YX_LAYER=env
```

Verification:

- Build/load a container and run `env` inside it.

### YXENV-META-003: os-release metadata

Containers SHOULD include `/etc/os-release` identifying the environment as `yx-env` with the current environment version.

Verification:

- Inspect `/etc/os-release` in a built container.

## Container Requirements

### YXENV-CONT-001: Entrypoint

Containers MUST use `/bin/yx-init` as the configured entrypoint. `yx-init` MUST run `/bin/fhs-init` before executing the profile-specific entrypoint or requested command.

Verification:

- Inspect image config.
- Run container and confirm `[yxenv] Running fhs-init...` and `[fhs] init...` messages or equivalent behavior.

### YXENV-CONT-002: Default command

Containers MUST default to running `bash` when no explicit command is provided.

Verification:

- Run image interactively without a command and confirm a shell starts.

### YXENV-CONT-003: Minimal layer count

Container images SHOULD use a small number of layers. Current implementation uses `maxLayers = 2`.

Verification:

- Inspect `flake.nix`.

### YXENV-CONT-004: Basic passwd/group entries

Containers MUST provide basic `/etc/passwd` and `/etc/group` entries for `root`, `nobody`, and `builder`.

Verification:

- Inspect files in a built container.

### YXENV-CONT-005: Writable temporary directories

Containers MUST create `/tmp` and `/var/tmp` with world-writable sticky permissions.

Verification:

- Inspect permissions in a built container.

### YXENV-CONT-006: kas container entrypoint compatibility

kas profiles that use the kas-compatible entrypoint MUST preserve expected kas-container behaviors, including handling `USER_ID`, `GROUP_ID`, Git safe directories, optional copied SSH data, timezone, and rootless Docker workarounds.

Verification:

- Inspect `contrib/kas/container-entrypoint`.
- Run smoke tests with `USER_ID=$(id -u)` and `GROUP_ID=$(id -g)`.

### YXENV-CONT-007: `yx` command compatibility

If `yx-internal` is included in an environment, profile entrypoints MUST allow executing `yx` as the first command. kas-specific entrypoints MUST NOT reject `yx`.

Verification:

- Build a yx-enabled profile and run container command `yx --internal-handshake`.

## CLI Requirements

### YXENV-CLI-001: `yxenv` helper script commands

The `yxenv` helper script MUST support:

```sh
./yxenv image <profile> [extra-nix-packages] [extra-nix-options...]
./yxenv shell <profile> [extra-nix-packages] [extra-nix-options...]
./yxenv help
```

Verification:

```sh
cd yx-env
./yxenv help
./yxenv shell minimal --command true
./yxenv image minimal
```

### YXENV-CLI-002: Extra package behavior

The helper script MAY allow extra Nix packages through `YXENV_EXTRA` for local impure development. It MUST reject extra packages in CI.

Verification:

```sh
cd yx-env
CI=1 ./yxenv shell minimal hello
```

Expected: non-zero error.

### YXENV-CLI-003: Extra package impurity

When extra packages are requested, the helper script MUST pass `--impure` to Nix and append the configured extension suffix to the environment name.

Verification:

- Run with an extra package and inspect printed command/output.

## CI Requirements

### YXENV-CI-001: Build matrix

CI SHOULD build all supported profile container images.

Verification:

- Inspect `.github/workflows/nix.yml` matrix.

### YXENV-CI-002: Version tag check

For tag builds, CI MUST verify that the Git tag version matches `lib.version`.

Verification:

- Inspect `.github/workflows/nix.yml`.

### YXENV-CI-003: Container publish behavior

For tag builds, CI SHOULD load, tag, and push built images to GHCR with both versioned and latest-profile tags.

Verification:

- Inspect `.github/workflows/nix.yml`.

## Future Integration Requirements with `yx`

These requirements describe the intended integration point with the separate `yx` project.

### YXENV-YX-001: Include internal yx without depending on external yx

`yx-env` MAY include `yx-internal` in selected profiles. It MUST NOT depend on or include `yx-external` for internal environment execution.

Verification:

- Inspect profile package lists and flake inputs when integration is added.

### YXENV-YX-002: Internal yx path precedence

If `yx-internal` is included, the internal `yx` binary MUST appear before any host-mounted or externally installed `yx` in `PATH` inside the environment.

Verification:

```sh
which yx
yx --internal-handshake
```

### YXENV-YX-003: Pure extension mechanism

`yx-env` SHOULD expose a pure Nix extension mechanism for composing extra packages such as `yx-internal` into environments. This SHOULD avoid relying on impure `YXENV_EXTRA` for production/CI use.

Verification:

- Inspect flake outputs or exported library functions after implementation.

## Testing Requirements

### YXENV-TEST-001: Flake version evaluation

The version output MUST evaluate without building images:

```sh
cd yx-env
nix eval --raw .#lib.version
```

### YXENV-TEST-002: Dev shell smoke test

At least one minimal and one Yocto dev shell MUST enter successfully:

```sh
cd yx-env
nix develop .#minimal -c true
nix develop .#yocto -c true
```

### YXENV-TEST-003: Profile metadata smoke test

Each profile dev shell SHOULD report correct `YXENV_PROFILE`.

Example:

```sh
cd yx-env
nix develop .#yocto-scarthgap-kas52 -c sh -c 'test "$YXENV_PROFILE" = yocto-scarthgap-kas52'
```

### YXENV-TEST-004: Container smoke test

At least one container image SHOULD build and run a basic command:

```sh
cd yx-env
nix build .#minimal
docker load < result
docker run --rm yx-env:0.1.4-minimal env
```

The exact image tag MUST match the current environment name logic.
