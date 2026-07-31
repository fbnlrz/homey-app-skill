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
- Generates Flow cards (triggers, conditions, actions) with the full argument-type reference
- Implements OAuth2 cloud pairing (with the redirect-URI and pair-session pitfalls handled)
- Builds dashboard widgets (native theming, API layer, dynamic pickers, previews)
- Models Homey Energy correctly (approximation, cumulative meters, batteries, solar, EV chargers)
- Covers both runtimes — Node.js **and** the Python runtime (`homey` package, Python 3.14)
- Enforces Homey Apps SDK v3 best practices and critical rules
- Guides publishing to the Homey App Store (icons, localization, the build → test → certify lifecycle)
- Sets up CI/CD with Athom's official GitHub Actions (validate / version / publish)
- Covers the differences between Homey Pro, Homey Self-Hosted Server and Homey Cloud

### Sourcing

The reference library is built from — and cross-checked against — three authoritative sources:

1. Every page of <https://apps.developer.homey.app> (all 71 pages, fetched as Markdown).
2. The JavaScript SDK v3 API reference (<https://apps-sdk-v3.developer.homey.app>) and the Python SDK
   reference (<https://python-apps-sdk-v3.developer.homey.app>).
3. [`athombv/node-homey-lib`](https://github.com/athombv/node-homey-lib) — the package the Homey CLI
   validator itself uses. Its JSON Schemas and asset definitions are the final word on manifest keys,
   the 184 system capabilities, the 75 device classes and the 13 permissions, and they win wherever
   the prose documentation disagrees.

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

`SKILL.md` is the concise entry point and carries a routing table; the deep material lives in
`references/`, one file per topic so only what a task needs gets loaded:

**Core**

- **`app-and-manifest.md`** — App class, every manifest field, Homey Compose (incl. `$extends`
  templating), i18n, permissions, persistent storage, platform feature detection
- **`drivers-and-devices.md`** — Driver/Device classes and every method, `driver.compose.json`,
  all 75 device classes, device settings schema, availability & warnings
- **`capabilities.md`** — the complete table of all 184 system capabilities, capability options,
  sub-capabilities, custom capabilities, migration when adding a capability
- **`energy.md`** — the `energy` object, Homey Energy, cumulative meters, batteries, solar, EV chargers
- **`pairing.md`** — pair/repair/unpair, every system view, `PairSession`, custom pairing HTML
- **`flow-cards.md`** — triggers/conditions/actions, every argument type, autocomplete, tokens,
  Advanced Flow
- **`widgets.md`** — widget manifest, settings & pickers, the full CSS variable set, previews, debugging
- **`custom-views-and-settings.md`** — app settings pages, the frontend `Homey` object, the HTML/CSS
  styleguide

**Connectivity**

- **`wireless-lan-discovery.md`** — Wi-Fi/LAN, mDNS-SD / SSDP / MAC discovery strategies
- **`wireless-zwave.md`** · **`wireless-zigbee.md`** — mesh drivers, clusters/command classes, OTA
- **`wireless-rf-infrared.md`** — 433/868 MHz signals, IR remotes, `homey-rfdriver`
- **`wireless-ble-matter.md`** — Bluetooth LE, Matter, Thread
- **`cloud-oauth-webhooks.md`** — OAuth2 pairing, `homey-oauth2app`, webhooks
- **`web-api-and-realtime.md`** — `api.js`, app-to-app calls, realtime events

**Everything else**

- **`advanced-features.md`** — images & cameras, videos, LED ring, Insights, and the remaining managers
- **`cli-and-tooling.md`** — the complete Homey CLI reference, validation levels, TypeScript, ESM
- **`python-apps.md`** — the Python runtime: `homey_export`, snake_case API map, dependencies, typing
- **`ecosystem-and-ci.md`** — Athom's official libraries, example apps, GitHub Actions CI/CD, ESLint,
  Sentry logging
- **`publishing.md`** — the complete App Store guidelines, asset specs, certification, updates
- **`migration-and-breaking-changes.md`** — SDK v2→v3, Node 22, compatibility ranges, safe deprecation
- **`homey-cloud.md`** — Homey Cloud restrictions and multi-tenancy
- **`sdk-api-index.md`** — a dense signature index of the whole SDK v3 API surface

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md), or open an
[issue](https://github.com/fbnlrz/homey-app-skill/issues) / PR on this fork.

## License

[MIT](LICENSE)
