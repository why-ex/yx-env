# Supported Yocto and kas versions

`yx-env` pins the host/tool environment with Nix. It does **not** pin the
Yocto source repositories for a project. Yocto source revisions remain the
responsibility of the kas project configuration and its lock files.

## Current support matrix

| Profile | Intended Yocto release line | kas support | Release-specific host notes |
| --- | --- | --- | --- |
| `minimal` | none | none | Basic FHS/container smoke profile only. |
| `yocto` | generic/current Yocto host tools | none | Common Yocto host tools with the default wrapped compiler. |
| `yocto-scarthgap` | Yocto Project 5.0 LTS (`scarthgap`) | none | Common Scarthgap-compatible host tools. |
| `yocto-scarthgap-kas52` | Yocto Project 5.0 LTS (`scarthgap`) | **kas 5.2 exactly** | Adds kas, `gosu`, PAM-less `shadow`, `socat`, and kas-compatible entrypoint/proxy helpers. |
| `yocto-kirkstone` | Yocto Project 4.0 LTS (`kirkstone`) | none | Adds Kirkstone compatibility packages such as `gcc13`, `python311`, and `file.dev`. |
| `yocto-kirkstone-kas52` | Yocto Project 4.0 LTS (`kirkstone`) | **kas 5.2 exactly** | Adds kas 5.2 plus Kirkstone compatibility packages and kas-compatible entrypoint/proxy helpers. |

## Exact kas behavior

Profiles ending in `kas52` import `profiles/kas-5_2.nix`, which asserts that
the selected nixpkgs package is kas `5.2`. Evaluation fails if nixpkgs provides
a different kas version.

Verify with:

```sh
nix develop .#yocto-scarthgap-kas52 -c kas --version
nix develop .#yocto-kirkstone-kas52 -c kas --version
```

## Exact Yocto source revisions

The supported Yocto release lines are exact at the branch/LTS-line level:

- Scarthgap: Yocto Project 5.0 LTS, upstream branch `scarthgap`
- Kirkstone: Yocto Project 4.0 LTS, upstream branch `kirkstone`

Patch-level Yocto source revisions must be pinned by your project. Use pinned
Git revisions in kas files or generate and commit kas lock files. `yx-env` can
make the host tools reproducible, but it cannot make an unpinned Yocto checkout
reproducible by itself.

The smoke configs under `smoke/kas/` use the upstream LTS branches to validate
profile compatibility. Production projects should lock their own remotes and
revisions.

## Adding another release line

A new Yocto release line should get all of the following before being considered
supported:

1. a dedicated profile under `profiles/`;
2. a package list documenting release-specific host-tool choices;
3. a smoke kas config under `smoke/kas/` when kas is supported;
4. an entry in this support matrix;
5. CI coverage for at least container image evaluation/build, and preferably a
   `kas dump`/parser smoke job.
