# yx-env container images

Release builds publish OCI-compatible images to GitHub Container Registry (GHCR).

## Image naming

```text
ghcr.io/why-ex/yx-env:<version>-<profile>
ghcr.io/why-ex/yx-env:<profile>
```

Examples:

```text
ghcr.io/why-ex/yx-env:0.1.5-minimal
ghcr.io/why-ex/yx-env:0.1.5-yocto-scarthgap-kas52
ghcr.io/why-ex/yx-env:yocto-scarthgap-kas52
```

The `<profile>` tag is the latest released image for that profile. Use the
`<version>-<profile>` tag when you need a stable, reproducible reference in CI.

## Pull an image

```sh
docker pull ghcr.io/why-ex/yx-env:0.1.5-yocto-scarthgap-kas52
# or
podman pull ghcr.io/why-ex/yx-env:0.1.5-yocto-scarthgap-kas52
```

## Run with a Yocto/kas workspace

Mount the workspace at the same absolute path inside the container. This avoids
path surprises in Yocto build state and sstate-cache metadata.

```sh
docker run --rm -ti \
  -u "$(id -u):$(id -g)" \
  -v "$(pwd):$(pwd):rw" \
  -v /tmp:/tmp:rw \
  -v /var/tmp:/var/tmp:rw \
  -v /etc/group:/etc/group:ro \
  -v /etc/passwd:/etc/passwd:ro \
  --workdir="$(pwd)" \
  ghcr.io/why-ex/yx-env:0.1.5-yocto-scarthgap-kas52
```

For kas-container compatible profiles, you may also pass `USER_ID` and
`GROUP_ID` so the kas entrypoint creates and uses the matching `builder` user:

```sh
docker run --rm -ti \
  -e USER_ID="$(id -u)" \
  -e GROUP_ID="$(id -g)" \
  -v "$(pwd):$(pwd):rw" \
  --workdir="$(pwd)" \
  ghcr.io/why-ex/yx-env:0.1.5-yocto-scarthgap-kas52 kas --version
```

## Local image builds

A locally built image uses the same tag shape with the local `yx-env` repository
name:

```sh
./yxenv image yocto-scarthgap-kas52
docker load < result
docker run --rm -ti yx-env:0.1.5-yocto-scarthgap-kas52
```
