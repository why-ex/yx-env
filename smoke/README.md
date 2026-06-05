# Yocto/kas smoke projects

This directory contains small, real kas projects that use upstream Yocto Project
`poky` layers. They are intended to validate that a `yx-env` profile can run
kas and enter a BitBake-capable workspace.

The smoke projects are intentionally minimal:

- checkout upstream `poky` for the selected Yocto LTS branch;
- enable the standard `meta`, `meta-poky`, and `meta-yocto-bsp` layers;
- configure `qemux86-64`, `poky`, and `core-image-minimal`;
- support a no-build parser smoke test with `bitbake -p`.

## Run from a disposable workspace

`kas checkout` creates or updates source repositories. Run the smoke test from a
throwaway workspace, not from a production Yocto checkout.

```sh
mkdir -p /tmp/yx-env-smoke
cd /tmp/yx-env-smoke
nix develop /path/to/yx-env#yocto-scarthgap-kas52 --command \
  /path/to/yx-env/smoke/run-kas-smoke.sh scarthgap dump
```

Modes:

```sh
# Validate kas can parse and expand the config; no source checkout.
/path/to/yx-env/smoke/run-kas-smoke.sh scarthgap dump

# Checkout upstream poky for the selected release branch.
/path/to/yx-env/smoke/run-kas-smoke.sh scarthgap checkout

# Checkout and run a BitBake parser smoke test; no image build.
/path/to/yx-env/smoke/run-kas-smoke.sh scarthgap parse
```

Supported smoke configs:

- `scarthgap` -> `smoke/kas/scarthgap.yml`
- `kirkstone` -> `smoke/kas/kirkstone.yml`

Use `parse` for stronger validation before publishing a profile image. It is
still much cheaper than building `core-image-minimal`, but it requires network
access for the initial checkout.
