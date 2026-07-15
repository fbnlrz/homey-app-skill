---
name: homey-app
description: >
  Build, scaffold, debug, and publish apps for the Homey smart home platform using the Homey Apps SDK v3.
  Use this skill whenever the user mentions Homey, Homey Pro, Homey Cloud, Homey app development,
  Homey CLI, Homey Compose, Homey Flow cards, Homey device drivers, Homey capabilities, Homey widgets,
  Homey pairing, or any smart home app development targeting the Homey platform. Also trigger when
  the user wants to integrate a device brand or cloud service with Homey, create Flow automations,
  build dashboard widgets, or publish to the Homey App Store. Even if the user just says "I want to
  make a Homey app" or mentions a device they want to control with Homey, use this skill.
---

# Homey Apps SDK — Skill Guide

This skill helps you build apps for the Homey smart home platform. A Homey app is a Node.js bundle
that runs locally on Homey Pro (or in the cloud on Homey Cloud). Apps add **Devices**, **Flow cards**,
**Widgets**, and more to the Homey ecosystem.

## Key Concepts

**SDK version**: Always use SDK v3 (`"sdk": 3` in the manifest). SDK v3 is async/await everywhere.

**Node.js**: As of Homey v12.9.0, all platforms run Node.js 22.

**Homey Compose**: The build system that splits the monolithic `app.json` manifest into smaller
`*.compose.json` files. Never edit `/app.json` directly — edit the compose files instead.

**Three core classes** you extend in every app:
- `Homey.App` — exported from `/app.js`, instantiated once on app start
- `Homey.Driver` — exported from `/drivers/<id>/driver.js`, manages pairing and all device instances
- `Homey.Device` — exported from `/drivers/<id>/device.js`, represents a single paired device

**Homey CLI** (`npx homey`) is the primary development tool:
- `homey app create` — scaffold a new app
- `homey app run` — run & debug live on a Homey (uninstalls on quit)
- `homey app install` — install persistently for testing
- `homey app publish` — publish to the Homey App Store
- `homey app driver create` — interactively add a driver
- `homey app flow create` — interactively add a Flow card
- `homey app validate` — check manifest validity

## Project Structure (Homey Compose)

```
com.example.myapp/
├─ .homeycompose/
│  ├─ app.json                         # Core manifest properties
│  ├─ capabilities/
│  │  └─ <custom_cap_id>.json          # Custom capability definitions
│  ├─ flow/
│  │  ├─ triggers/<id>.json            # App-level Flow trigger cards
│  │  ├─ conditions/<id>.json          # App-level Flow condition cards
│  │  └─ actions/<id>.json             # App-level Flow action cards
│  ├─ discovery/
│  │  └─ <id>.json                     # LAN discovery strategies (mDNS, SSDP, MAC)
│  └─ locales/
│     └─ en.json                       # App-level translations
├─ assets/
│  ├─ icon.svg                         # App icon (SVG)
│  └─ images/
│     ├─ small.png (250x175)
│     ├─ large.png (500x350)
│     └─ xlarge.png (1000x700)
├─ drivers/
│  └─ <driver_id>/
│     ├─ assets/
│     │  ├─ icon.svg                   # Driver icon
│     │  └─ images/ (small, large, xlarge)
│     ├─ device.js                     # Device class
│     ├─ driver.js                     # Driver class
│     ├─ driver.compose.json           # Driver manifest
│     ├─ driver.flow.compose.json      # Driver-specific Flow cards (optional)
│     └─ driver.settings.compose.json  # Device settings (optional)
├─ widgets/
│  └─ <widget_id>/
│     ├─ public/
│     │  └─ index.html                 # Widget frontend
│     ├─ api.js                        # Widget API handlers
│     ├─ widget.compose.json           # Widget definition
│     ├─ preview-dark.png              # Widget preview (dark)
│     └─ preview-light.png             # Widget preview (light)
├─ locales/
│  ├─ en.json
│  └─ nl.json
├─ settings/
│  └─ index.html                       # App settings page (optional)
├─ api.js                              # App Web API (optional, Pro only)
├─ app.js                              # App class
├─ env.json                            # Secret environment variables (gitignored!)
├─ README.txt                          # App Store long description (plain text, no markdown)
└─ .homeyignore                        # Files to exclude from publishing
```

## How to Use This Skill

When creating a Homey app, follow this workflow:

1. **Determine the integration type** — Is it a LAN device (Wi-Fi/mDNS/SSDP), cloud API (OAuth2/webhooks),
   or wireless protocol (Z-Wave, Zigbee, 433MHz, BLE, IR, Matter)?
2. **Read the relevant reference file** from `references/` for detailed patterns:
   - `references/app-and-manifest.md` — App class, manifest, settings, environment, i18n, permissions
   - `references/drivers-and-devices.md` — Driver/Device classes, pairing, capabilities, settings, discovery
   - `references/flow-cards.md` — Triggers, conditions, actions, arguments, tokens, device Flow cards
   - `references/widgets.md` — Dashboard widgets, widget settings, widget API
   - `references/wireless-and-cloud.md` — Wi-Fi/LAN discovery, OAuth2, webhooks, Z-Wave, Zigbee, BLE
   - `references/publishing.md` — Complete App Store guidelines (1.1–3.4), icons/images, localization, publishing lifecycle, certification checklist
3. **Scaffold the project** following the Homey Compose structure above
4. **Write the code** using SDK v3 patterns (async/await, `this.homey.*` managers)
5. **Validate** with `homey app validate --level=publish`

## Scaffolding a New App

When the user asks to create a new Homey app, generate the full file set. At minimum you need:

- `/.homeycompose/app.json` with id, version, compatibility, sdk, name, description, category, etc.
- `/app.js` extending `Homey.App`
- At least one driver with `driver.js`, `device.js`, and `driver.compose.json`
- `/locales/en.json` for any translated strings
- `README.txt`

The app ID must be in reverse domain notation (e.g., `com.example.mydevice`). Don't use the **Homey
or Athom name as the identity** of your id (you can't publish `com.athom.*` or otherwise pass your
app off as theirs) — but this is *not* a literal substring ban: an id like `com.you.homeyfin` (a
Jellyfin integration) is fine. **Choose the id carefully: it is effectively permanent** — after the
first publish, changing the id creates a *new* App Store listing that loses all installs and reviews,
so pick the final id before you ever publish.

### Minimal app.js

```javascript
'use strict';

const Homey = require('homey');

class MyApp extends Homey.App {
  async onInit() {
    this.log('MyApp has been initialized');
  }
}

module.exports = MyApp;
```

### Minimal driver.js

```javascript
'use strict';

const Homey = require('homey');

class MyDriver extends Homey.Driver {
  async onInit() {
    this.log('MyDriver has been initialized');
  }

  async onPairListDevices() {
    // Return an array of discovered devices
    return [];
  }
}

module.exports = MyDriver;
```

### Minimal device.js

```javascript
'use strict';

const Homey = require('homey');

class MyDevice extends Homey.Device {
  async onInit() {
    this.log('MyDevice has been initialized');

    // Register capability listeners
    this.registerCapabilityListener('onoff', async (value) => {
      // Handle the on/off command
      this.log('onoff changed to', value);
    });
  }

  async onAdded() {
    this.log('MyDevice has been added');
  }

  async onSettings({ oldSettings, newSettings, changedKeys }) {
    this.log('MyDevice settings changed');
  }

  async onDeleted() {
    this.log('MyDevice has been deleted');
  }
}

module.exports = MyDevice;
```

### Minimal driver.compose.json

```json
{
  "name": { "en": "My Device" },
  "class": "socket",
  "capabilities": ["onoff"],
  "platforms": ["local"],
  "connectivity": ["cloud"],
  "pair": [
    {
      "id": "list_devices",
      "template": "list_devices",
      "navigation": { "next": "add_devices" }
    },
    {
      "id": "add_devices",
      "template": "add_devices"
    }
  ]
}
```

## Critical Rules

1. **Never edit `/app.json` directly** — it is generated by Homey Compose from `*.compose.json` files.
   A **fresh Compose-only repo still needs an `app.json` to exist** before the CLI is happy; the CLI
   generates it on `homey app run/validate/build`. If you hit
   `ENOENT: no such file or directory, open 'app.json'`, run the app once (or `homey app build`) to
   generate it — commit a generated stub if needed, but never hand-edit it.
2. **In `onSettings({ oldSettings, newSettings, changedKeys })`, `this.getSetting()` still returns the
   OLD value** — settings persist only *after* the handler resolves. Always read new values from the
   `newSettings` argument (e.g. restart a poll timer from `newSettings.poll_interval`, not
   `getSetting('poll_interval')`).
3. **Default `"platforms": ["local"]`** (Homey Pro). Publishing a Homey Cloud app requires an
   Athom-approved developer account, or `homey app publish` is rejected with *"not eligible to
   publish apps for Homey Cloud."*
4. **Never overwrite constructors** on App, Driver, or Device — use `onInit()` instead.
5. **Use `this.homey.*` for timers** — call `this.homey.setInterval()` / `this.homey.setTimeout()` instead
   of the global versions, so timers are auto-cleared on app destroy (critical for Homey Cloud multi-tenancy).
6. **Device `data` must be immutable and unique** — use MAC addresses or serial numbers, never IP addresses.
   Store changing properties in the device store or settings.
7. **Always handle promise rejections** — unhandled rejections crash apps on Homey Cloud.
   Use `.catch(this.error)` for fire-and-forget promises.
8. **Access managers via `this.homey`** — e.g., `this.homey.flow`, `this.homey.settings`, `this.homey.drivers`.
9. **App instance from Device/Driver**: `this.homey.app` gives you the App instance.
10. **Environment variables**: defined in `/env.json`, accessed as `Homey.env.VARIABLE_NAME` (uppercase, string values only).
11. **Insights is write-only at runtime** — an app cannot read a capability's Insights history back
    (`ManagerInsights` has no entry-reading method). Keep your own capped buffer if you need history.
    See `references/drivers-and-devices.md`.
12. **ESM support**: Homey supports ES modules. See the ESM guide if using `import`/`export` syntax.

## Homey Cloud Considerations

> **Publishing to Homey Cloud requires an Athom-approved (Verified) developer account** — intended
> for companies/brands. Regular developers should keep `"platforms": ["local"]` (Homey Pro only);
> otherwise `homey app publish` fails with *"not eligible to publish apps for Homey Cloud."*

When targeting Homey Cloud (`"platforms": ["local", "cloud"]`, approved accounts only):
- No local Wi-Fi (no mDNS/SSDP/MAC discovery)
- No App Web API (`api.js`) — so no LAN `http.createServer` (see the settings-page file-delivery note)
- No app-to-app communication
- No `homey:manager:api` permission
- Must handle multi-tenancy: no global state, use `this.homey.*` for timers
- Apps run in Docker; `homey app run` requires Docker for cloud testing
- Unhandled promise rejections will crash the app

## Quick Reference: Common Patterns

### Polling a Cloud API
```javascript
async onInit() {
  this.pollInterval = this.homey.setInterval(() => {
    this.pollDevice().catch(this.error);
  }, 30000);
}

async onUninit() {
  this.homey.clearInterval(this.pollInterval);
}
```

### Setting Capability Values (Device → Homey)
```javascript
await this.setCapabilityValue('measure_temperature', 22.5);
// For custom boolean capabilities, this auto-triggers Flow cards
```

### Listening for Capability Changes (Homey → Device)
```javascript
this.registerCapabilityListener('target_temperature', async (value, opts) => {
  await this.api.setTemperature(value);
});
```

### Firing a Flow Trigger
```javascript
// In app.js onInit():
const myTrigger = this.homey.flow.getDeviceTriggerCard('my_event');
// Later, from a device:
await this.driver.myTrigger.trigger(this, { token_key: 'value' }, {});
```

### Using Device Discovery (mDNS)
Read `references/wireless-and-cloud.md` for the full discovery pattern including
`onDiscoveryResult`, `onDiscoveryAvailable`, and `onDiscoveryAddressChanged`.

---

For detailed documentation on any topic, read the relevant reference file listed above.
The official documentation lives at https://apps.developer.homey.app/ and the SDK v3
API reference at https://apps-sdk-v3.developer.homey.app/.
