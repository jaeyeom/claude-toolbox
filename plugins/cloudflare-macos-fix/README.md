# Cloudflare macOS Fix Plugin

Fix sharp native module installation failure on macOS Apple Silicon when setting up Cloudflare Workers projects with wrangler.

## Components

| Component              | Type  | Description                                          |
| ---------------------- | ----- | ---------------------------------------------------- |
| `cloudflare-macos-fix` | Skill | Guides fix for sharp/wrangler native module failures |

## Installation

```bash
/plugin marketplace add jaeyeom/claude-toolbox

/plugin install cloudflare-macos-fix
```

## Usage

The skill activates automatically when it detects sharp or wrangler installation issues on macOS:

- "sharp install fails on my Mac"
- "wrangler native module error on Apple Silicon"
- "pnpm install fails with darwin-arm64 error"
- "Set up a Cloudflare Workers project"

## What It Covers

- **Root cause**: ABI mismatch between sharp 0.34.x prebuilt binaries and Node v25+
- **Pin sharp**: Override to 0.33.5 via pnpm/npm overrides
- **Platform config**: `.npmrc` settings for current-platform-only binary downloads
- **Source fallback**: `node-addon-api` devDependency for building from source
