# AGENTS.md — BDK Comparo

Single entry point for any coding agent (Claude Code, Codex, Cursor) dropped into this repo.

## What this project is

**BDK Comparo** — pure-Swift macOS folder comparison and one-way sync utility. Dual-panel SwiftUI dark theme. Identifies files only in one folder, detects modifications, and can sync one direction.

Single-file architecture (intentional). Built as a personal utility and reference for SwiftUI macOS patterns.

## Source of truth

1. **[README.md](README.md)** — features, build instructions.
2. **Vault page:** `wiki/projects/bdk-comparo` in the Obsidian vault.

## Key paths

- Source is intentionally minimal — see the build script.
- `build.sh` — produces the `BDKComparo` binary.

## Build & verify

```bash
./build.sh
./BDKComparo
```

Requires macOS and a recent Swift toolchain.

## Working rules

- **Single-file architecture is a feature.** Don't split into a multi-file project structure without explicit instruction.
- Pure SwiftUI, no third-party dependencies.
- One-way sync — never silently bidirectional. Destination-clobbering operations require a confirmation step.
- No emojis in UI per global design rules.

## Related work elsewhere

- Could serve as a helper during the workspace reorganization migration when verifying file moves preserved content. See `~/Desktop/REORG_PROTOCOL.md`.
