---
name: cloudflare-macos-fix
description: >
  Fix sharp native module installation failure on macOS Apple Silicon when
  setting up Cloudflare Workers projects using wrangler. Use when the user
  encounters "sharp", "wrangler install", "pnpm install" errors on macOS
  arm64/Apple Silicon with Node v25+, or when setting up a new Cloudflare
  Workers project on macOS. Trigger on keywords: "sharp", "wrangler",
  "cloudflare workers setup", "native module", "darwin-arm64",
  "prebuilt binary", "node-gyp", "ABI mismatch".
---

# Sharp Native Module Fix for macOS Apple Silicon

## Problem

The `sharp` package (transitive dependency of `wrangler`) fails to install on
macOS Apple Silicon (darwin-arm64) with Node v25+. Sharp 0.34.x ships prebuilt
binaries that have an ABI mismatch with Node v25's native `.node` files.

Typical error symptoms:
- `sharp` install fails during `pnpm install` / `npm install`
- Native module load errors referencing `darwin-arm64`
- `node-gyp` rebuild failures for sharp

## Fix (3 steps)

### 1. Pin sharp to 0.33.5 via pnpm override

Add to `package.json`:

```json
"pnpm": {
  "overrides": {
    "sharp": "0.33.5"
  }
}
```

For npm, use `overrides` at the top level instead:

```json
"overrides": {
  "sharp": "0.33.5"
}
```

### 2. Add `.npmrc` with platform-specific binary config

Create or update `.npmrc`:

```ini
shamefully-hoist=true
supportedArchitectures.os=current
supportedArchitectures.cpu=current
supportedArchitectures.libc=current
```

This tells pnpm to download prebuilt native binaries matching the current
platform only.

### 3. Add `node-addon-api` as a devDependency

```bash
pnpm add -D node-addon-api@^8.3.1
```

Fallback so sharp can compile from source if prebuilt binaries aren't available.

### 4. Reinstall

```bash
rm -rf node_modules pnpm-lock.yaml
pnpm install
```

## Environment

- **OS:** macOS Apple Silicon (arm64)
- **Node:** v25+
- **Package manager:** pnpm (also applicable to npm with adjusted override syntax)
- **Source:** `sharp` as transitive dependency via `wrangler`

## Reference

- https://sharp.pixelplumbing.com/install#cross-platform
