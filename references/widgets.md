# Widgets Reference

## Table of Contents
1. [Overview](#overview)
2. [Widget Structure](#widget-structure)
3. [Widget Manifest](#widget-manifest)
4. [Sizing: height, aspect ratio, and column width](#sizing)
5. [Native Styling with Homey CSS Variables](#styling)
6. [Widget Frontend (index.html)](#widget-frontend)
7. [Widget API (api.js)](#widget-api)
8. [Widget Settings](#widget-settings)
9. [Dynamic Device Pickers (autocomplete)](#dynamic-pickers)
10. [Rendering History (Insights is write-only)](#history)
11. [Previews & Validation](#previews)

---

## Overview

Widgets are dashboard components that display information from your app on the Homey dashboard.
Each widget is a folder under `/widgets/<widget_id>/` containing an HTML frontend, a JSON manifest,
an optional API layer, and preview images. The **folder name is the widget id** — you never declare
`id` inside `widget.compose.json`.

Widget development requires Docker (the widget frontend is served from a container during
`homey app run`, which shows a refresh button for live-reloading the HTML).

---

## Widget Structure

```
widgets/
└─ my-widget/                # <-- this folder name IS the widget id
   ├─ public/
   │  └─ index.html          # Widget frontend
   ├─ api.js                 # Widget API handler (optional)
   ├─ widget.compose.json    # Widget definition
   ├─ preview-dark.png       # Preview image (dark mode) — REQUIRED
   └─ preview-light.png      # Preview image (light mode) — REQUIRED
```

---

## Widget Manifest

`/widgets/<widget_id>/widget.compose.json`:

```json
{
  "name": { "en": "My Widget" },
  "height": 200,
  "transparent": false,
  "settings": [
    {
      "id": "refreshInterval",
      "type": "number",
      "title": { "en": "Refresh Interval" },
      "value": 30,
      "hint": { "en": "Seconds between refreshes" }
    }
  ],
  "api": {
    "getStatus": { "method": "GET", "path": "/" },
    "setMode":   { "method": "PUT", "path": "/" }
  }
}
```

### Properties:
- `name` — Translation object for the widget name
- `height` — Default size (see [Sizing](#sizing) below — a number and a percentage string mean different things)
- `transparent` — Whether the widget background is transparent
- `settings` — Array of settings the user can configure
- `api` — Named endpoints the frontend can call (maps a method name → `{ method, path }`)
- `deprecated` — `true` hides the widget from the picker while keeping existing instances working

> There is **no `id` field** in `widget.compose.json` — the id is the folder name, and that is the
> string you pass to `this.homey.dashboards.getWidget('<widget_id>')`.

---

## Sizing

App widgets always fill the **width of the dashboard column** they are placed in — a widget
**cannot set its own width**. `height` is therefore the only sizing lever, and it behaves in two
completely different ways depending on the value type:

- **A number is absolute pixels.** `"height": 200` → 200 px tall, regardless of column width.
- **A percentage string is an ASPECT RATIO** (height relative to the widget's width).
  `"height": "100%"` makes a **square** widget; `"height": "50%"` makes it half as tall as it is wide.

```json
{ "name": { "en": "Square Tile" }, "height": "100%" }
```

Heights are cached after the first render to avoid layout shift, so prefer a stable height. You can
override the manifest height at runtime from the frontend: `Homey.ready({ height: 240 })`.

---

## Styling

Homey injects **CSS custom properties** that adapt to the user's light/dark theme automatically.
**Never hardcode colors** — always reference these variables so the widget matches the native UI in
both themes. The documented variables include:

```css
.card {
  background: var(--homey-background-color);
  color: var(--homey-text-color);
  border: 1px solid var(--homey-line-color);
  border-radius: var(--homey-border-radius-default);
  padding: var(--homey-su-2);                 /* spacing scale */
  font-size: var(--homey-font-size-default);
  font-weight: var(--homey-font-weight-medium);
}
.value.up   { color: var(--homey-color-green); }
.value.down { color: var(--homey-color-red); }
.subtitle   { color: var(--homey-text-color-light); }
```

Key groups (use the exact names):
- **Spacing:** `--homey-su`, `--homey-su-1` … `--homey-su-8`
- **Background / text:** `--homey-background-color`, `--homey-text-color`, `--homey-text-color-light`,
  `--homey-text-color-white`, `--homey-text-color-{blue,green,orange,red}`
- **Accent colors:** `--homey-color-blue`, `--homey-color-green`, `--homey-color-orange`,
  `--homey-color-red`, `--homey-color-white`, plus a mono scale `--homey-color-mono-000` …
  `--homey-color-mono-1000`
- **Lines:** `--homey-line-color`, `--homey-line-color-light`
- **Font size:** `--homey-font-size-{xxlarge,xlarge,large,default,small}`
- **Font weight:** `--homey-font-weight-{bold,medium,regular}`
- **Border radius:** `--homey-border-radius-small`, `--homey-border-radius-default`
- **Icons:** `--homey-icon-color-{dark,light,white,blue,green,orange,red}`,
  `--homey-icon-size-{medium,regular,small}`

---

## Widget Frontend

`/widgets/<widget_id>/public/index.html`. The page must define a **global `onHomeyReady(Homey)`
function** — Homey calls it once the bridge is ready. Call `Homey.ready()` inside it or the widget
stays stuck on the loading state.

```html
<!DOCTYPE html>
<html>
<head>
  <style>
    body { margin: 0; padding: var(--homey-su-2); color: var(--homey-text-color); }
  </style>
</head>
<body>
  <div id="status">…</div>

  <script type="text/javascript">
    function onHomeyReady(Homey) {
      // Read instance settings — SYNCHRONOUS, returns the settings object
      const settings = Homey.getSettings();
      const refresh = settings.refreshInterval || 30;

      // A `devices`/autocomplete setting arrives as an OBJECT (or array of objects),
      // not a plain string — read it defensively.
      const device = settings.device;
      const deviceId = (device && typeof device === 'object') ? device.id : device;

      async function fetchStatus() {
        try {
          const result = await Homey.api('GET', `/?device=${encodeURIComponent(deviceId || '')}`);
          document.getElementById('status').textContent = result.status;
        } catch (err) {
          console.error('API error:', err);
        }
      }

      fetchStatus();
      setInterval(fetchStatus, refresh * 1000);

      // Listen for events pushed from the app
      Homey.on('status_update', (data) => {
        document.getElementById('status').textContent = data.status;
      });

      // Signal ready LAST (optionally override height)
      Homey.ready();
    }
  </script>
</body>
</html>
```

### Homey frontend API:
- `Homey.ready()` / `Homey.ready({ height })` — Signal the widget is loaded (call it, always)
- `Homey.getSettings()` — **Synchronous**; returns this instance's settings object
- `Homey.getWidgetInstanceId()` — Unique ID for this widget instance
- `Homey.getDeviceIds()` — IDs of devices chosen in a `devices` setting
- `Homey.api(method, path, body?)` — Call a widget API endpoint (routes to `api.js`)
- `Homey.on(event, callback)` — Listen for events emitted by the app
- `Homey.__(key, tokens?)` — Translate a string
- `Homey.hapticFeedback()` — Trigger haptic feedback (only within a touch-event window)

> **Injected `<script>` does not execute.** Setting `element.innerHTML = '<script>…</script>'`
> inserts the markup but the browser never runs it. If you must run logic against markup you build
> dynamically (e.g. in a sandboxed sub-context), don't rely on the tag firing — embed the logic by
> stringifying a named function and invoking it:
> ```javascript
> function render(root, data) { /* ...build DOM... */ }
> const boot = `(${render.toString()})(document.getElementById('app'), ${JSON.stringify(data)});`;
> // then run `boot` in the target context instead of injecting a <script> tag
> ```

---

## Widget API

`/widgets/<widget_id>/api.js`. Each handler receives `{ homey, query, body, params }` and typically
delegates straight to a method on the app instance (`homey.app.<method>()`):

```javascript
'use strict';

module.exports = {
  async getStatus({ homey, query }) {
    // query holds the parsed querystring from Homey.api('GET', '/?device=…')
    return homey.app.getWidgetStatus(query.device);
  },

  async setMode({ homey, body }) {
    await homey.app.setMode(body.mode);
    return { success: true };
  },
};
```

The handler names must match the keys in the `api` block of `widget.compose.json`:

```json
{
  "api": {
    "getStatus": { "method": "GET", "path": "/" },
    "setMode":   { "method": "PUT", "path": "/" }
  }
}
```

---

## Widget Settings

Settings are declared in `widget.compose.json` under `settings`. Types: `text`, `textarea`,
`number`, `dropdown`, `checkbox`, `autocomplete`, `devices`.

### Device picker (`devices`):
```json
{
  "id": "devices",
  "type": "devices",
  "title": { "en": "Devices" },
  "min": 1,
  "max": 5,
  "scope": "driver",
  "filter": { "class": "light|socket", "capabilities": "onoff" }
}
```
- `scope` — `"driver"` (only this app's devices) or `"global"` (all Homey devices; needs `homey:manager:api`)
- Read the chosen IDs with `Homey.getDeviceIds()` in the frontend.

---

## Dynamic Pickers

An `autocomplete` setting lets the user search a list you generate at runtime. Register the listener
in the **app's `onInit`** via `ManagerDashboards`. Older firmware may not expose
`this.homey.dashboards`, so wrap the registration in try/catch so the app still boots:

```json
{ "id": "device", "type": "autocomplete", "title": { "en": "Device" } }
```

```javascript
// app.js onInit()
try {
  this.homey.dashboards
    .getWidget('my-widget')                 // widget id = folder name
    .registerSettingAutocompleteListener('device', async (query, settings) => {
      const devices = await this.getSelectableDevices();
      return devices
        .filter(d => d.name.toLowerCase().includes(query.toLowerCase()))
        .map(d => ({ name: d.name, id: d.id }));   // objects, not strings
    });
} catch (err) {
  this.error('Dashboards manager unavailable (old firmware?):', err);
}
```

The listener returns an array of `{ name, id, … }` objects, and the chosen value is stored as that
**object** — which is why the frontend must read `settings.device.id` defensively (see the frontend
example above).

---

## History

You often want a widget to show a trend (a sparkline of the last N samples). **You cannot pull this
from Insights** — at runtime the App SDK's Insights API is write-only (see
`references/drivers-and-devices.md` → Insights). `insights: true` on a capability logs values but
gives the app no way to read them back.

Keep your own **bounded rolling buffer** instead — sample each poll, cap the length, store it in the
device store, and hand it to the widget through `api.js`:

```javascript
// device.js — append a capped history sample each poll
async recordSample(value) {
  const history = this.getStoreValue('history') || [];
  history.push({ t: Date.now(), v: value });
  while (history.length > 96) history.shift();          // e.g. keep ~last 96 samples
  await this.setStoreValue('history', history);
}
```

```javascript
// api.js — serve it to the widget
async getHistory({ homey, query }) {
  return homey.app.getDeviceHistory(query.device);      // returns the capped array
}
```

---

## Previews

`preview-light.png` and `preview-dark.png` are shown in the widget picker and **both are required**
— publishing validation fails with an `ENOENT` if either is missing:

```
✖ ... ENOENT: no such file or directory, open '.../widgets/my-widget/preview-light.png'
```

Guidance:
- Provide a light and a dark variant so the picker looks right in both themes.
- Keep them simple — schematic shapes, no screenshots, no text. A Figma template is available from
  the Homey docs.
- Use square images (a 1024×1024 export is a safe choice); export before running
  `homey app validate --level publish`.
