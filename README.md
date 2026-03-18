# yx-env

yx-env provides a reproducible, Nix-based container and FHS-compatible environment for building Yocto Project images.

It enables consistent builds across systems by packaging all required dependencies into a container image or a local FHS environment—without polluting your host system.

---

## Container Image (Recommended)

### Build

Build the flake output:

```sh
nix build .#container
```

### Load and Run

- Docker
```sh
docker load < result
docker run --rm -ti yx-env:latest
```

- Podman
```sh
podman load < result
podman run --rm -ti yx-env:latest
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
  yx-env:latest
```
Then source your Yocto environment script and run `bitbake`.

---

## Local FHS environment: buildFHSEnv

### Build and enter

```sh
nix develop
```
Then navigate to your Yocto project directory, source its environment script and run `bitbake`.

---

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
- Supports both containerized and local development workflows
- Powered by Nix flakes

---

## Notes

- Running containers as your host user `(-u $(id -u):$(id -g))` avoids permission issues
- Mounting `/etc/passwd` and `/etc/group` improves user resolution inside the container
- Additional capabilities (`NET_ADMIN`, `/dev/net/tun`) are only needed for advanced networking use cases
