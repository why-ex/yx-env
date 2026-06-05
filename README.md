# yx-env

yx-env provides a reproducible, Nix-based container and FHS-compatible environment for building Yocto Project images.

It enables consistent builds across systems by packaging all required dependencies into a container image or a local FHS environment—without polluting your host system.

---

## Container Image (Recommended)

Prebuilt release images are published to GitHub Container Registry. See
[`docs/images.md`](docs/images.md) for tag names and Docker/Podman examples.

### Build

Build the flake output for the yocto profile:

```sh
./yxenv image yocto
```

### Load and Run

- Docker
```sh
docker load < result
docker run --rm -ti yx-env:yocto
```

- Podman
```sh
podman load < result
podman run --rm -ti yx-env:yocto
```

### Running the Container (example)

#### Using Your Current Directory as Full Workspace

Useful for Yocto builds where absolute paths matter:

```sh
docker run --rm -ti \
  -u $(id -u):$(id -g) \
  -v $(pwd):$(pwd):rw \
  -v /tmp:/tmp:rw \
  -v /var/tmp:/var/tmp:rw \
  -v /etc/group:/etc/group:ro \
  -v /etc/passwd:/etc/passwd:ro \
  --workdir=$(pwd) \
  yx-env:yocto
```
Then source your Yocto environment script and run `bitbake`.

---

## Local FHS environment: buildFHSEnv

### Build and enter the nix shell with yocto profile:

```sh
./yxenv shell yocto
```
Then navigate to your Yocto project directory, source its environment script and run `bitbake`.

---

## Smoke validation

Small upstream Yocto/kas smoke projects are available under [`smoke/`](smoke/).
They can validate `kas dump`, `kas checkout`, and a no-build BitBake parser run
(`bitbake -p`) for the supported LTS profiles.

Example:

```sh
mkdir -p /tmp/yx-env-smoke
cd /tmp/yx-env-smoke
/path/to/yx-env/yxenv shell yocto-scarthgap-kas52 --command \
  /path/to/yx-env/smoke/run-kas-smoke.sh scarthgap parse
```

## When to Use Which Environment

### Container (Recommended)

Best choice for Yocto builds in CI/CD or reproducible environments.

- Container acts as a fixed root filesystem
- Fully reproducible builds
- Works well with Docker/Podman
- Ideal for teams and automation

---

### buildFHSEnv

Best for local development workflows:

- Provides a “classic” Linux filesystem layout (/bin, /usr/lib, etc.)
- No need for sudo or mount tricks
- Easier debugging and interactive use

---

## Why yx-env?

- Reproducible Yocto Project builds
- No host contamination
- Works with multiple Yocto LTS versions (e.g. Kirkstone, Scarthgap)
- Documents exact supported release lines and kas versions in
  [`docs/support-matrix.md`](docs/support-matrix.md)
- Supports both containerized and local development workflows
- Powered by Nix flakes

---

## Notes

- Running containers as your host user `(-u $(id -u):$(id -g))` avoids permission issues
- Mounting `/etc/passwd` and `/etc/group` improves user resolution inside the container
- Additional capabilities (`NET_ADMIN`, `/dev/net/tun`) are only needed for advanced networking use cases
