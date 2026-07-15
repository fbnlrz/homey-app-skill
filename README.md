# homey-app-skill

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Agent Skills](https://img.shields.io/badge/Agent_Skills-compatible-blue)](https://agentskills.io)

A Claude **skill** — a [`SKILL.md`](SKILL.md) plus a `references/` library — that teaches Claude to
**build, run, and publish Homey Pro apps** (Homey Apps SDK v3, Homey Compose). It works with the
**Claude Code** CLI (and desktop/VS Code) and with agents built on the **Claude Agent SDK** that load
filesystem skills.

> This is a fork of [`dvflw/homey-app-skill`](https://github.com/dvflw/homey-app-skill), extended with
> deep reference material (OAuth2 cloud pairing, widgets, insights, publishing, and more) learned from
> shipping a real-world Homey app. Improvements welcome — see [Contributing](#contributing).

## Installation

### Prerequisites

- **[Node.js](https://nodejs.org/)** 18+ (Homey apps themselves run on Node 22).
- **Homey CLI** — `npm install -g homey` (docs: <https://apps.developer.homey.app/the-basics/getting-started>).
- A **Homey developer account** — <https://tools.developer.homey.app/> (free for Homey Pro).
- **Claude Code** — <https://docs.claude.com/en/docs/claude-code>.

A Claude Code skill is just a folder named after the skill containing a `SKILL.md` at its root:
`…/.claude/skills/homey-app/SKILL.md`. Installing it is copying this repo's `SKILL.md` and
`references/` into that folder.

### Install for a single project (recommended)

From the project where you want to build a Homey app:

```sh
git clone https://github.com/fbnlrz/homey-app-skill.git /tmp/homey-app-skill
mkdir -p .claude/skills/homey-app
cp -r /tmp/homey-app-skill/SKILL.md /tmp/homey-app-skill/references .claude/skills/homey-app/
```

You should end up with `.claude/skills/homey-app/SKILL.md` and
`.claude/skills/homey-app/references/`. Commit `.claude/skills/` to share the skill with your team.

### Install globally (all projects)

Same layout, under your home directory:

```sh
git clone https://github.com/fbnlrz/homey-app-skill.git /tmp/homey-app-skill
mkdir -p ~/.claude/skills/homey-app
cp -r /tmp/homey-app-skill/SKILL.md /tmp/homey-app-skill/references ~/.claude/skills/homey-app/
```

### Install from the `.skill` bundle

The repo also ships a prebuilt [`homey-app.skill`](homey-app.skill) — a gzipped tarball whose top
folder is already `homey-app/`. Extract it straight into a skills directory:

```sh
# project-level
tar -xzf homey-app.skill -C .claude/skills/
# or global
tar -xzf homey-app.skill -C ~/.claude/skills/
```

This yields `.claude/skills/homey-app/SKILL.md` directly.

### Verify & invoke

Restart Claude Code (or start a new session) so it re-scans skills, then:

- Type `/` and confirm **`homey-app`** appears in the skills list, or ask Claude *"what skills are
  available?"*.
- Claude **auto-invokes** the skill when your prompt mentions Homey; you can also invoke it
  explicitly with `/homey-app`.

A good first prompt:

> "Build a Homey Pro app that polls the Foobar cloud API and exposes a thermostat device."

### Update

```sh
cd /path/to/your/clone && git pull
# then re-copy SKILL.md + references/ into the skills folder (as above)
```

### Uninstall

Delete the skill folder: `rm -rf .claude/skills/homey-app` (or `~/.claude/skills/homey-app`).

### Note on `npx skills` / marketplaces

Third-party ecosystems such as [agentskills.io](https://agentskills.io) offer a CLI
(`npx skills add …`) that can install Agent Skills into Claude Code and other tools. Those are
community-maintained, not an official Anthropic install path — the copy/extract steps above are the
canonical way to install a Claude Code skill. Claude Code's own official distribution mechanism for
bundling skills is [plugins](https://docs.claude.com/en/docs/claude-code) (`/plugin marketplace add`
+ `/plugin install`); this repo is packaged as a standalone skill, not a plugin.

## What It Does

This skill gives Claude deep knowledge of Homey app development:

- Scaffolds new Homey apps with the correct Homey Compose project structure
- Creates drivers, devices, and custom capabilities
- Generates Flow cards (triggers, conditions, actions)
- Implements OAuth2 cloud pairing (with the redirect-URI and pair-session pitfalls handled)
- Builds dashboard widgets (native theming, API layer, dynamic pickers, previews)
- Enforces Homey Apps SDK v3 best practices and critical rules
- Guides publishing to the Homey App Store (icons, localization, the build → test → certify lifecycle)
- Covers the differences between Homey Pro and Homey Cloud

## Compatibility

Works with any agent that loads filesystem [Agent Skills](https://agentskills.io) from
`.claude/skills/`:

- Claude Code (CLI, desktop, VS Code / JetBrains)
- Agents built on the Claude Agent SDK
- Other Agent-Skills-compatible tools ([many more](https://agentskills.io))

## Usage

The skill activates automatically when you mention Homey-related topics. Try things like:

- "Create a new Homey app for controlling my LED strip"
- "Add a driver for a Zigbee temperature sensor"
- "Set up OAuth2 cloud pairing for a Google service"
- "Build a dashboard widget that shows today's total"
- "What's the difference between Homey Pro and Cloud for app development?"

## What's Inside

`SKILL.md` is the concise entry point; the deep material lives in `references/`:

- **`references/app-and-manifest.md`** — App class, manifest, settings pages (LAN file delivery),
  environment, localization, permissions
- **`references/drivers-and-devices.md`** — Driver/Device classes, capabilities, custom capabilities,
  Insights (write-only), settings, pairing, discovery
- **`references/flow-cards.md`** — Triggers, conditions, actions, arguments, tokens, device Flow cards
- **`references/widgets.md`** — Widget manifest, sizing, native CSS variables, frontend/API contract,
  dynamic pickers, previews
- **`references/wireless-and-cloud.md`** — LAN discovery, OAuth2 cloud pairing, webhooks, Z-Wave,
  Zigbee, RF/IR, BLE, Matter/Thread, firmware OTA, Homey Cloud restrictions
- **`references/advanced-features.md`** — App Web API, realtime & app-to-app, images & image Flow
  tokens, videos, LED ring, speech/geolocation/clock/NFC, manager quick-map
- **`references/cli-and-migration.md`** — Homey CLI surface, validation levels, debugging,
  TypeScript/Python runtimes, ESM, Node 22, breaking-changes & SDK v2→v3 migration
- **`references/publishing.md`** — Complete App Store guidelines (1.1–3.4), icons, images,
  localization, publishing lifecycle, pre-certification checklist

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md), or open an
[issue](https://github.com/fbnlrz/homey-app-skill/issues) / PR on this fork.

## License

[MIT](LICENSE)
