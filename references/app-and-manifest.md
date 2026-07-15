# App & Manifest Reference

## Table of Contents
1. [App Class](#app-class)
2. [App Manifest (.homeycompose/app.json)](#app-manifest)
3. [Settings (App-level)](#app-settings)
4. [Persistent Storage](#persistent-storage)
5. [Internationalization](#internationalization)
6. [Permissions](#permissions)
7. [Environment Variables](#environment-variables)
8. [Homey Compose Details](#homey-compose)

---

## App Class

The `/app.js` file exports a class extending `Homey.App`. It is instantiated once when the app starts.

```javascript
'use strict';

const Homey = require('homey');

class MyApp extends Homey.App {

  async onInit() {
    // Called when the app is initialized
    this.log('App initialized');

    // Register app-level Flow cards here
    const myAction = this.homey.flow.getActionCard('do_something');
    myAction.registerRunListener(async (args, state) => {
      // Handle the action
    });

    // Access app settings
    const apiKey = this.homey.settings.get('apiKey');
  }

  async onUninit() {
    // Called when the app is destroyed (important for Homey Cloud)
    // Clean up connections, clear intervals, etc.
  }
}

module.exports = MyApp;
```

### Key patterns:
- Access the App instance from a Device or Driver: `this.homey.app`
- Shared state (like API clients) should live on the App instance
- Register app-level Flow card listeners in `onInit()`
- Clean up resources in `onUninit()` for Homey Cloud compatibility

---

## App Manifest

The `/.homeycompose/app.json` contains core app metadata. This gets merged into the generated `/app.json`.

```json
{
  "id": "com.example.myapp",
  "version": "1.0.0",
  "compatibility": ">=5.0.0",
  "platforms": ["local"],
  "sdk": 3,
  "brandColor": "#FF6B35",
  "name": {
    "en": "My App"
  },
  "description": {
    "en": "Adds support for Example devices."
  },
  "category": "appliances",
  "tags": {
    "en": ["example", "smart home"]
  },
  "images": {
    "small": "/assets/images/small.png",
    "large": "/assets/images/large.png",
    "xlarge": "/assets/images/xlarge.png"
  },
  "permissions": [],
  "author": {
    "name": "John Doe",
    "email": "john@example.com"
  }
}
```

### Required fields:
- `id` — Reverse domain notation (e.g. `com.company.product`). You may not use the **Homey or Athom
  name as the identity** of the id (don't impersonate them / claim `com.athom.*`), but this is not a
  literal substring ban — `com.you.homeyfin` (a Jellyfin app) is valid. **The id is effectively
  permanent:** after the first publish, changing it creates a brand-new App Store listing that loses
  all existing installs and reviews, so settle on the final id *before* you first publish.
- `version` — Semver (no pre-release suffixes like `-rc.1`)
- `compatibility` — Semver range for Homey firmware (use `>=5.0.0` for SDK v3)
- `sdk` — Must be `3`
- `name` — Translation object. **Max 4 words**; use the brand name; no company names, no protocol
  names (Zigbee, Z-Wave, 433 MHz…), and no "Homey"/"Athom". See the App Store naming rules in
  `references/publishing.md`.
- `description` — Translation object holding a single **one-liner / catchy tagline**, not a
  paragraph. Don't repeat the app name or reuse text from the README, and avoid generic phrasings
  like "Adds support for X" or "Integrates X with Homey".
- `category` — One of: `lights`, `video`, `music`, `appliances`, `security`, `climate`, `tools`, `internet`, `localization`, `energy`
- `images` — Paths to `small` (250×175), `large` (500×350), optionally `xlarge` (1000×700)
- `author` — Object with `name` (required) and `email` (optional)

### Optional fields:
- `platforms` — Array of `"local"` and/or `"cloud"` (defaults to `["local"]`). **Target `["local"]`
  (Homey Pro) unless you have an Athom-approved developer account** — see the warning below.
- `runtime` — `"nodejs"` (default) or `"python"`. Python also requires `pythonVersion` (`"3.14"`) and
  `pythonDependencies` (managed via `homey app dependencies …`).
- `brandColor` — HEX color string (mandatory for the store; not too bright)
- `tags` — Translation object of arrays for App Store search
- `permissions` — Array of permission strings
- `platformLocalRequiredFeatures` — Array of `"nfc"`, `"ledring"`, `"speaker"`, `"matter"`; makes the
  app uninstallable on Homey Pro models lacking a listed feature.
- `contributors` — `{ developers: [...], translators: [...] }`, each entry needs a `name` (the
  correct place to credit people — not the README).
- `contributing.donate` — `{ paypal | bunq | patreon | githubSponsors: { username } }` (shows a
  Donate button for non-verified devs).
- `bugs.url` — URL to bug tracker
- `source` — URL to source code (must start with `https://`)
- `homepage` — URL to homepage
- `support` — URL or `mailto:` — **mandatory for Verified Developers**
- `homeyCommunityTopicId` — Number (topic ID from community forum URL)

> The generated `/app.json` must **exist** for `homey app validate`/`run`/`build` (the CLI generates
> it from `.homeycompose/` + `*.compose.json`); never hand-edit it. Pre-release versions like
> `1.0.0-rc.1` are rejected.

> **⚠️ Default to `"platforms": ["local"]`.** Publishing a **Homey Cloud** app requires an
> Athom-approved (Verified/"Official") developer account — that subscription is intended for
> companies/brands. If you include `"cloud"` without it, `homey app publish` is rejected with
> *"Your account is not eligible to publish apps for Homey Cloud."* Regular developers should target
> **Homey Pro only** (`["local"]`). Note `platforms` (where the app can run) is independent of a
> driver's `connectivity` (how a device talks) — a local-only app can still integrate a cloud API.

---

## App Settings

App-level settings are managed through `this.homey.settings` (ManagerSettings):

```javascript
// Get a setting
const value = this.homey.settings.get('myKey');

// Set a setting
this.homey.settings.set('myKey', 'myValue');

// Listen for changes
this.homey.settings.on('set', (key) => {
  if (key === 'myKey') {
    // React to change
  }
});
```

To create a user-facing settings page, add `/settings/index.html`. This is an HTML page that
communicates with the Homey API. Most apps shouldn't need app-level settings — prefer device settings
instead. **Custom app settings views are not allowed on Homey Cloud.**

Include the Homey bridge and define `onHomeyReady` (the view stays hidden until you call `Homey.ready()`):
```html
<head><script src="/homey.js" data-origin="settings"></script></head>
<script>
  function onHomeyReady(Homey) {
    Homey.get('username', (err, val) => { /* … */ });
    Homey.ready();
  }
</script>
```
Settings-page `Homey.*` API (callback-style; promises also supported): `ready()`,
`get([name,] cb)` / `set(name, value, cb)` / `unset(name, cb)`, `on(event, cb)` (system events
`settings.set` / `settings.unset`), `api(method, path, body, cb)` (calls the app Web API under
`/api/app/<id>`), `alert(msg, cb)`, `confirm(msg, cb)`, `popup(url[, {width,height}])`,
`openURL(url)`, and `__(key[, tokens])` (+ `data-i18n` attributes). A Homey Style Library
(`.homey-form-*`, `.homey-button-*`, …) is available for native-looking pages.

### ⚠️ Settings pages are sandboxed — delivering a file to the user

The settings page runs in a **sandboxed iframe**. In practice this means `window.open`,
`window.print`, and browser downloads are blocked. So if the page needs to hand the user a file
(e.g. a generated printable report), you cannot pop it up or download it directly. Instead, **serve
it over the LAN from the app and open it with `Homey.openURL(url)`**:

```javascript
// app.js — serve the report over the LAN (Homey Pro only — Homey Cloud has no LAN access)
const http = require('http');

async serveReport(html) {
  const token = this.generateToken();                 // random one-time token
  const server = http.createServer((req, res) => {
    if (req.url !== `/report?token=${token}`) { res.writeHead(403); return res.end(); }
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(html);
  });
  await new Promise(r => server.listen(0, r));         // 0 = any free port
  const port = server.address().port;
  const address = await this.homey.cloud.getLocalAddress();  // e.g. "192.168.1.20:80"
  const host = address.split(':')[0];
  this.homey.setTimeout(() => server.close(), 5 * 60 * 1000); // short TTL, then tear down
  return `http://${host}:${port}/report?token=${token}`;
}
```

```javascript
// settings/index.html — open it externally (works on desktop AND mobile)
const url = await Homey.api('POST', '/report');       // your api.js returns the LAN URL
Homey.openURL(url);
```

Three traps to avoid:
- **Don't branch on the return value of `window.open`.** On **desktop** a blocked `window.open`
  returns `null` (easy to detect), but in the **mobile** Homey app it returns a **non-null but
  invisible** window — so `if (win) { win.document.write(html) }` silently swallows the content and
  the feature looks broken *only on mobile*. Use the LAN + `Homey.openURL(url)` path
  **unconditionally** instead.
- **`homey app run` uses Docker bridge networking**, so a LAN port the app opens is unreachable from
  your phone or PC. The same code works under `homey app install` (production networking). Test
  LAN-served content with `install`, not `run`.
- **Secure anything you serve.** It's plain HTTP on the local network, so gate it behind a generated
  one-time token/password, give it a short TTL, and tear the server down afterward (as above).

---

## Persistent Storage

There are three persistence tiers:
- **App settings** — `this.homey.settings` (ManagerSettings): JSON-serializable key/values, survive
  reboots, deleted only on uninstall.
- **Device store** — per-device back-end values:
  ```javascript
  const value = this.getStoreValue('myKey');
  await this.setStoreValue('myKey', 'newValue');
  ```
  (Device *settings* are the user-visible front-end equivalent.)
- **App userdata** — `/userdata/` (Homey Pro, writable) for binary/non-JSON files.

> **⚠️ `/userdata/` is publicly served** at `https://<homey>/app/<app.id>/userdata/`. Use
> **unguessable UUID filenames** (e.g. `a656d380-…​.jpg`, not `image1.jpg`) and store the mapping in
> App Settings. Note also: paths differ (`/` is the sandboxed app dir on Pro, the Linux root on
> Cloud) — always `require('./…')` or `path.join(__dirname, …)`, never absolute paths.

---

## Internationalization

Translation files live in `/locales/<lang>.json`:

```json
{
  "greeting": "Hello!",
  "errors": {
    "not_found": "Device not found"
  }
}
```

Access translations in code:
```javascript
const msg = this.homey.__('greeting');
const err = this.homey.__('errors.not_found');
```

### Supported language codes:
`en`, `nl`, `de`, `fr`, `it`, `sv`, `no`, `es`, `da`, `ru`, `pl`, `ko`, `ar`

Variable substitution in translation strings uses **double underscores**: `"Hello, __name__"`
with `this.homey.__('greeting', { name: 'Bob' })`. IDs support dot notation (`settings.title`). Apps
work in **Celsius internally** — Homey auto-converts to °F; a custom number capability needs
`"units": "°C"` for that conversion. Arabic (`ar`) is RTL — built-in views handle it; custom views use
CSS `:dir(rtl)`. Auto-translate with `homey app translate` (OpenAI).

English (`en`) is always required and is the fallback for every other language. Athom (Homey's
maker) is Dutch and Dutch has a large user base, so **`en` + `nl` (+ `de`)** is a sensible default
set to translate.

There are **four distinct localization mechanisms**, each with its own file convention:

1. **In-app strings** — `/locales/<lang>.json`, read via `this.homey.__('key')`. The `name`,
   `description`, `title`, `hint`, `label`, `units`, etc. inside manifest/compose files are
   translation objects (`{ "en": "…", "nl": "…" }`) resolved at build time.

2. **App Store description** — `/README.txt` (English fallback) plus per-language
   `/README.<lang>.txt` (e.g. `README.nl.txt`, `README.de.txt`). Homey auto-selects by the user's
   language. Plain text only (no markdown/HTML/URLs — see `references/publishing.md`).

3. **Publish changelog** — `/.homeychangelog.json`, keyed by version then language:
   ```json
   {
     "1.0.0": { "en": "Initial release.", "de": "Erste Version.", "nl": "Eerste versie." },
     "1.1.0": { "en": "Added widgets." }
   }
   ```
   `en` is required per entry; other languages fall back to it. The CLI appends to this file when you
   answer the "What's new?" prompt during `homey app publish`.

4. **Settings pages** — localize `settings/index.html` with `data-i18n` attributes backed by
   `/locales/*.json`, plus `Homey.__()` in the page script for dynamic strings:
   ```html
   <h1 data-i18n="settings.title">Settings</h1>
   <script>
     function onHomeyReady(Homey) {
       document.getElementById('hint').textContent = Homey.__('settings.hint');
       Homey.ready();
     }
   </script>
   ```

---

## Permissions

Permissions are declared in the manifest `permissions` array:

| Permission | Description |
|---|---|
| `homey:manager:api` | ManagerApi / Homey Web API — controls **all** devices & Flows. Tools-type apps only (HomeyScript, Device Groups…); rejected if used by a branded device app; **not allowed on Homey Cloud** |
| `homey:manager:speech-output` | Text-to-speech (ManagerSpeechOutput) |
| `homey:manager:ledring` | Control the LED ring (Homey Pro 2016–2019) |
| `homey:manager:geolocation` | Access Homey's location (ManagerGeolocation) |
| `homey:wireless:433` | Transmit/receive 433 MHz signals |
| `homey:wireless:868` | Transmit/receive 868 MHz signals (Pro 2019 or earlier) |
| `homey:wireless:ir` | Transmit/receive infrared signals |
| `homey:wireless:ble` | Bluetooth LE (ManagerBLE) |
| `homey:wireless:nfc` | Scanned NFC tags (ManagerNFC) |
| `homey:app:<appId>` | App-to-app communication (Pro only; e.g. `homey:app:com.athom.example`) |

> A missing permission makes the manager's methods **throw**. New permissions added in an update do
> **not** auto-apply to existing installs.

---

## Environment Variables

Secret keys go in `/env.json` (add to `.gitignore`!):

```json
{
  "CLIENT_ID": "abc123",
  "CLIENT_SECRET": "secret_value"
}
```

Access anywhere: `Homey.env.CLIENT_ID`. Keys must be uppercase strings.

---

## Homey Compose

Homey Compose splits the app manifest across multiple files that get merged at build time.

### Driver templates
Share common driver properties via `/.homeycompose/drivers/templates/<template_id>.json`:

```json
{
  "images": {
    "small": "{{driverAssetsPath}}/images/small.png",
    "large": "{{driverAssetsPath}}/images/large.png"
  },
  "capabilities": [],
  "class": "other"
}
```

Extend from a driver: `"$extends": ["defaults"]` in `driver.compose.json`.

### Template variables
- `{{driverAssetsPath}}` — resolves to `/drivers/<driver_id>/assets`

### Flow cards in Compose
- App-level: `/.homeycompose/flow/triggers/<id>.json`, `conditions/<id>.json`, `actions/<id>.json`
- Driver-level: `/drivers/<driver_id>/driver.flow.compose.json`

### Capabilities in Compose
Custom capabilities: `/.homeycompose/capabilities/<id>.json`

### Discovery in Compose
Discovery strategies: `/.homeycompose/discovery/<id>.json`
