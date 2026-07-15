# CLI, Tooling & Migration Reference

## Table of Contents
1. [Homey CLI](#homey-cli)
2. [Validation levels](#validation-levels)
3. [Debugging](#debugging)
4. [TypeScript & Python runtimes](#runtimes)
5. [ESM (ES modules)](#esm)
6. [Node.js versions](#node)
7. [Breaking changes & migration](#migration)

---

## Homey CLI {#homey-cli}

Install: `npm install --global homey` (the CLI needs **Node.js 24+**; the apps it builds run on
Node 22 — see [Node versions](#node)). Docker is required for `homey app run`/`install`.

### App lifecycle
- `homey app create` — scaffold an app (interactive; app ID must be reverse-DNS).
- `homey app run [--clean|-c] [--remote|-r] [--skip-build|-s] [--link-modules|-l a,b] [--network|-n host]`
  — build + run in local Docker, stream console; **Ctrl+C uninstalls**. `--clean` wipes
  userdata/devices/settings. Default networking is Docker **bridge** (a LAN port you open is
  unreachable from your phone/PC — use `install` to test LAN features).
- `homey app install [--clean] [--skip-build]` — install and leave it installed (production
  networking; no log stream).
- `homey app build` / `homey app publish` / `homey app manage` / `homey app view`.
- `homey app compose` — migrate a monolithic `app.json` into `.homeycompose/`.
- `homey app version <patch|minor|major|x.y.z> [--changelog.<lang> "…"] [--commit]`.

### Scaffolding subcommands
- `homey app driver create` · `homey app driver capabilities` · `homey app driver flow`
- `homey app driver firmware --driver <path> --firmware <file>` (Zigbee/Z-Wave OTA)
- `homey app flow create` · `homey app widget create` · `homey app discovery create`
- `homey app add-types` (jsconfig/tsconfig) · `homey app add-github-workflows`

### AI helpers
- `homey app translate [--languages <csv>] [--api-key …] [--model gpt-4o] [--file …]` — auto-translate
  `locales/*.json` + `README.txt` (uses `OPENAI_API_KEY`; typically < $1/app).
- `homey app review [--type new|update] [--model <provider>/<model>] [--json] [--verbose]` — AI review
  (OpenAI or Anthropic; uses `OPENAI_API_KEY` / `ANTHROPIC_API_KEY`).

### Direct Homey API
- `homey api schema` · `homey api diagnose` (tests discovery/local-address/mDNS/cloud tunnel — useful
  when `homey app run` can't reach the Homey) · `homey api raw --path </…> [-X GET] [-H "n:v"] [--body …]`
  · `homey api <manager> <operation>`.

### Auth & selection
- `homey login` / `homey logout` / `homey whoami` — OAuth2, credentials stored in `~/.homey/`
  (CI uses the `HOMEY_PAT` env var).
- `homey list` / `homey select [--id|--name]` / `homey select current` / `homey unselect`.
- `homey tools` / `homey docs` / `homey completion` (bash/zsh/fish).
- Global flags: `--help`, `--version|-v`, `--path|-p`, `--json`, `--jq "<expr>"`.
- Env vars: `HOMEY_PAT`, `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`.

### Python dependency management
`homey app dependencies install|add|remove|list` (e.g. `add [dev] <pkg>[@<ver>]`).

---

## Validation levels {#validation-levels}

`homey app validate --level <debug|publish|verified>`:
- **debug** — relaxes optional fields; for local development.
- **publish** — the Homey Pro App Store bar (default for most).
- **verified** — adds requirements (`platforms`, `connectivity`, `support`) — the default for
  Verified Developers and required for Homey Cloud apps.

---

## Debugging {#debugging}

- App logs: use `this.log(...)` / `this.error(...)` (never `console.log`); `homey app run` streams
  them. Use `.catch(this.error)` on fire-and-forget promises.
- Widgets/custom views run in a **webview**. Inspect on Android via Chrome `chrome://inspect/#devices`
  (or Edge `edge://inspect/#devices`) → "WebView in app.homey…" → Inspect. On iOS via Safari →
  Develop → [device] → [app].
- Dev tools portal: `tools.developer.homey.app` (Zigbee, BLE, Matter, Images, Webhooks…).

---

## TypeScript & Python runtimes {#runtimes}

- `runtime` in the manifest is `nodejs` (default) or `python`.
- **TypeScript:** source files use `.mts`; `homey app add-types` configures type checking/autocomplete.
- **Python:** `.py` files; `pythonVersion` is `3.14`; dependencies go in `pythonDependencies` and are
  managed with `homey app dependencies …` (a `/.python_cache/` holds pre-compiled deps). Type stubs:
  `pip install homey-stubs pyright`. App entry `homey_export = App`; managers are snake_case
  (`self.homey.settings.get(...)`, `self.homey.translate(...)`).

---

## ESM (ES modules) {#esm}

- Supported since **Homey v12.0.1** — bump `compatibility` to `>=12.0.1`.
- Opt in **per file** by using the `.mjs` extension (CJS and ESM can coexist). `require`/
  `module.exports` → `import`/`export default`.
- No `require()` in ESM — load CJS via dynamic `await import('cjs-module')`. No `__dirname`/
  `__filename` — derive with `fileURLToPath(import.meta.url)` + `dirname(...)`.
- Benefits: top-level `await`, strict mode by default, async loading.

---

## Node.js versions {#node}

All Homey platforms run **Node.js 22** as of Homey **v12.9.0**. Older matrix:
- Homey Pro 2016–2019: `<7.4.0` → Node 12; `>=7.4.0 && <12.9.0` → Node 16; `>=12.9.0` → Node 22.
- Homey Pro (Early 2023) & Pro mini: `<12.9.0` → Node 18; `>=12.9.0` → Node 22.
- Homey Cloud: Node 22 (`>=12.9.0`); Cloud apps migrate to Node 22 only after publishing a new
  version after **2025-12-02**.

Node 22 gotchas: `node-fetch` `ECONNRESET`/"socket hang up" → provide a keep-alive `http(s).Agent`
or switch to the built-in global `fetch`; Node 20 requires a `Host` header (400 otherwise); update
`node-homey-api` to `3.14.17+` to avoid a "Maximum call stack size exceeded" on socket close.

---

## Breaking changes & migration {#migration}

Breaking changes to capabilities/drivers/Flow cards are generally **not allowed** — most users
auto-update. Prefer additive, guarded migrations run in `onInit`.

### Add a capability
Add it to `driver.compose.json` (new pairings) **and** migrate existing devices — guarded, once:
```javascript
async onInit() {
  if (!this.hasCapability('measure_power')) await this.addCapability('measure_power');
}
```
Never call `addCapability` unconditionally on every init.

### Remove a capability
Preferred: just remove it from the manifest (paired devices keep working) and **keep its capability
listener**. Only call `this.removeCapability('x')` (guarded with `hasCapability`) when the behaviour
is truly gone — removing a capability that has Flow cards **removes those cards and breaks user Flows**.

### Deprecate a Flow card
Add `"deprecated": true` to the card JSON (hidden from new Flows; existing Flows keep working) and
**keep its run listener**. Create a new card for the new behaviour.

### Change device class
```javascript
if (this.getClass() !== 'light') this.setClass('light').catch(this.error);
```
Guard it, don't run every init; some Flow cards depend on class and may break.

### Deprecate a whole driver
Add `"deprecated": true` to the driver manifest — existing devices keep working; the driver becomes
unselectable for new pairings.

### SDK v2 → v3 essentials
- Introduced in Homey 5.0.0; set `"sdk": 3`, `"compatibility": ">=5.0.0"`.
- Managers moved from `require('homey')` to `this.homey.*`. The `homey` module now exports only
  `Homey.App`/`Homey.Driver`/`Homey.Device`, plus `Homey.env` and `Homey.manifest`.
- Everything is promise-only (callbacks removed). `onPair(session)` uses a `PairSession` with
  `setHandler`; `onPairListDevices` is async and returns the list.
- `onInit` order: `App#onInit()` → each `Driver#onInit()` → its `Device#onInit()`. You **cannot**
  access drivers from `App#onInit()`.
- SDK v2 libraries are incompatible: `homey-meshdriver` → `homey-zwavedriver`; update
  `homey-oauth2app`, `homey-rfdriver`, `homey-log`.
