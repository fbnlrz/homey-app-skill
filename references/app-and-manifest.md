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
- `id` — Reverse domain notation (e.g. `com.company.product`). Cannot contain "homey" or "athom".
- `version` — Semver (no pre-release suffixes like `-rc.1`)
- `compatibility` — Semver range for Homey firmware (use `>=5.0.0` for SDK v3)
- `sdk` — Must be `3`
- `name` — Translation object
- `description` — One-liner translation object
- `category` — One of: `lights`, `video`, `music`, `appliances`, `security`, `climate`, `tools`, `internet`, `localization`, `energy`
- `images` — Paths to `small` (250×175), `large` (500×350), optionally `xlarge` (1000×700)
- `author` — Object with `name` (required) and `email` (optional)

### Optional fields:
- `platforms` — Array of `"local"` and/or `"cloud"` (defaults to `["local"]`). **Target `["local"]`
  (Homey Pro) unless you have an Athom-approved developer account** — see the warning below.
- `brandColor` — HEX color string (not too bright)
- `tags` — Translation object of arrays for App Store search
- `permissions` — Array of permission strings
- `contributing.donate` — Object with `paypal` field (shows Donate button for non-verified devs)
- `bugs.url` — URL to bug tracker
- `source` — URL to source code (must start with `https://`)
- `homepage` — URL to homepage
- `support` — URL or `mailto:` for support
- `homeyCommunityTopicId` — Number (topic ID from community forum URL)

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
communicates with the Homey API. Most apps shouldn't need app-level settings — prefer device settings instead.

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

Apps can use persistent storage that survives reboots via `this.homey.settings` (for simple key-value data)
or the device store (for per-device data).

For device-level persistence, use the device store:
```javascript
// In device.js
const value = this.getStoreValue('myKey');
await this.setStoreValue('myKey', 'newValue');
```

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
`en`, `nl`, `de`, `fr`, `it`, `sv`, `no`, `es`, `da`, `ru`, `pl`, `ko`, `ja`, `zh-cn`, `zh-tw`

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
| `homey:manager:api` | Use ManagerApi and the Homey Web API (Pro only) |
| `homey:manager:speech-output` | Use text-to-speech |
| `homey:manager:speech-input` | Listen for voice commands |
| `homey:manager:ledring` | Control the LED ring (Homey Pro 2016-2019) |
| `homey:manager:geolocation` | Access Homey's location |
| `homey:wireless:433` | Transmit/receive 433MHz signals |
| `homey:wireless:868` | Transmit/receive 868MHz signals |
| `homey:wireless:ir` | Transmit/receive infrared signals |

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
