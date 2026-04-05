# biome-vcs-integration

Configure Biome to respect `.gitignore` via VCS integration, avoiding
format/lint errors on local-only files.

## Problem

Biome does not automatically skip `.gitignore`'d files. This causes CI failures
and false positives when local-only files don't match Biome's formatting rules.

## Usage

This plugin provides a skill that triggers when you encounter Biome errors on
gitignored files. It walks you through enabling Biome's VCS integration and
cleaning up redundant manual exclusions.

## Installation

Install from the claude-toolbox marketplace:

```
/install-plugin jaeyeom/claude-toolbox biome-vcs-integration
```
