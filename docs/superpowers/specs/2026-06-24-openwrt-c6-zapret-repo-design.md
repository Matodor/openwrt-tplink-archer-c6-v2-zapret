# OpenWrt C6 zapret repository design

## Goal

Organize the current working directory as a future git repository that preserves:

```text
firmware artifacts
router overlay scripts
recovery tooling
test scripts
session documentation
current router state
```

## Structure

The existing directory remains the repository root:

```text
/home/matodor/openwrt-builds/2026-06-24-openwrt-c6-v2-zapret
```

No files are moved. This avoids breaking paths already used in scripts and notes.

## Documentation

`README.md` is the entry point. `ARTIFACTS.md` documents firmware files. `docs/ROUTER-STATE.md` records the current verified router state.

`docs/UPSTREAMS.md` records source repositories, raw list URLs, Flowseal strategy source files, and the future update workflow for `zapret-tool`.

`docs/INSTALL-FROM-SCRATCH.md` records the full factory-to-OpenWrt installation flow for Archer C6 v2.

## Verification

Documentation links should point to existing files. `zapret-tool` tests should remain runnable through:

```sh
sh tests/test-zapret-tool.sh
```
