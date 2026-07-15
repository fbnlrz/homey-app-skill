# Wireless & Cloud Reference

## Table of Contents
1. [Wi-Fi / LAN Devices](#wifi-lan)
2. [Discovery Strategies](#discovery-strategies)
3. [OAuth2](#oauth2)
4. [Webhooks](#webhooks)
5. [Homey Cloud restrictions](#homey-cloud-restrictions)
6. [Z-Wave](#z-wave)
7. [Zigbee](#zigbee)
8. [Bluetooth LE](#bluetooth-le)
9. [433 MHz / 868 MHz](#433-868-mhz)
10. [Infrared](#infrared)
11. [Matter](#matter)
12. [Firmware updates (Z-Wave & Zigbee OTA)](#firmware-updates-z-wave--zigbee-ota)

---

## Wi-Fi / LAN Devices {#wifi-lan}

For devices on the local network, use Homey's Discovery system to find them automatically.
Apps that require users to manually enter an IP address will be rejected from the App Store
if discovery could have been used instead.

Homey can talk to the internet (cloud APIs) without extra permissions. For local network
access, use the Discovery system.

**Important**: Homey Cloud (Bridge) does NOT support local Wi-Fi connections. mDNS, SSDP,
and MAC discovery are not available. Cloud apps must use cloud APIs instead.

### Making HTTP requests:
Use Node.js built-in `fetch` (Node 22) or popular libraries like `axios` or `node-fetch`.
```javascript
const response = await fetch(`http://${address}/api/status`);
const data = await response.json();
```

---

## Discovery Strategies

Discovery strategies are defined in `/.homeycompose/discovery/<id>.json` and linked to drivers
by adding `"discovery": "<strategy_id>"` to the driver manifest.

### mDNS-SD (most common):
```json
{
  "type": "mdns-sd",
  "mdns-sd": {
    "name": "mydevice",
    "protocol": "tcp"
  },
  "id": "{{txt.serialnumber}}",
  "conditions": [
    [
      {
        "field": "txt.manufacturer",
        "match": { "type": "string", "value": "MyBrand" }
      }
    ]
  ]
}
```

- `name` — The mDNS service name (e.g., `_http._tcp` → name: `http`)
- `protocol` — `tcp` or `udp`
- `id` — Template for the unique device identifier (use `{{txt.xxx}}` for TXT record fields)
- `conditions` — Optional filters (arrays of AND rules, multiple arrays = OR)
- A resulting `DiscoveryResult` exposes `txt` (TXT record values, keys lowercased), `address` (IP),
  and `id`.

**`conditions` semantics:** an array of one-or-more arrays of rule objects. All rules *within* an
inner array must match (**AND**); multiple inner arrays are **OR**ed. Match `type` is `"string"`
(exact, case-insensitive) or `"regex"` — in a regex the backslashes must be **double-escaped** in
JSON. Fields can interpolate discovered values with `{{fieldName}}`.

### SSDP:
```json
{
  "type": "ssdp",
  "ssdp": {
    "search": "urn:schemas-upnp-org:device:MediaRenderer:1"
  },
  "id": "{{headers.usn}}"
}
```
The `DiscoveryResult` exposes `headers` (HTTP header values, keys lowercased), `address`, and `id`.
Use `{{headers.*}}` in the `id` template.

### MAC Address (ARP):
```json
{
  "type": "mac",
  "mac": {
    "manufacturer": [[0, 36, 109], [0, 36, 110]]
  }
}
```
`mac.manufacturer` is an array of the first three MAC bytes (the OUI) in **decimal** (JSON has no hex).
The MAC becomes the device ID automatically; the `DiscoveryResult` exposes `address`.

### Standalone discovery (outside a driver):
```javascript
const strategy = this.homey.discovery.getStrategy('<strategy_id>');
const results = strategy.getDiscoveryResults();   // map of id → DiscoveryResult
strategy.on('result', (result) => { /* new result */ });
```

### Using discovery in the Driver:
```javascript
class MyDriver extends Homey.Driver {
  async onPairListDevices() {
    const discoveryStrategy = this.getDiscoveryStrategy();
    const results = discoveryStrategy.getDiscoveryResults();
    return Object.values(results).map(result => ({
      name: result.txt?.name || result.address,
      data: { id: result.id },
    }));
  }
}
```

### Using discovery in the Device:
```javascript
class MyDevice extends Homey.Device {
  onDiscoveryResult(discoveryResult) {
    // Return true if this result belongs to this device
    return discoveryResult.id === this.getData().id;
  }

  async onDiscoveryAvailable(discoveryResult) {
    // Device found — connect
    this.address = discoveryResult.address;
    await this.connectToDevice();
    // If this throws, device becomes unavailable
  }

  async onDiscoveryAddressChanged(discoveryResult) {
    // IP changed — reconnect
    this.address = discoveryResult.address;
    await this.reconnectToDevice();
  }

  onDiscoveryLastSeenChanged(discoveryResult) {
    // Device was seen again (heartbeat)
  }
}
```

When using Discovery with a Driver, Homey manages device availability automatically.

---

## OAuth2

OAuth2 cloud pairing is one of the trickiest parts of a Homey app. Read this whole section — the
three pitfalls below each cost real debugging time. Two working paths exist:

1. **`homey-oauth2app`** — the official helper library. Prefer it: it wires the `login_oauth2` view,
   token storage, and refresh-on-401 for you.
2. **Manual `this.homey.cloud.createOAuth2Callback()`** — full control, and worth understanding even
   if you use the library, because the callback URL and pair-session rules below apply either way.

### How Homey's OAuth2 callback works

Homey Pro sits behind the user's router with no fixed public URL, so it cannot be the OAuth redirect
target directly. Instead Athom hosts a fixed redirect endpoint that relays the `code` back to your
app over Homey's cloud connection. The callback is created with:

```javascript
// (async — you MUST await it)
const oauthCallback = await this.homey.cloud.createOAuth2Callback(authorizeUrl);
oauthCallback
  .on('url', (url) => { /* show this URL to the user (login popup) */ })
  .on('code', (code) => { /* code is `string | Error` — exchange it for tokens */ });
```

### ⚠️ Pitfall 1 — `createOAuth2Callback` does NOT append `redirect_uri`

`createOAuth2Callback(authorizeUrl)` uses the URL you give it **verbatim**. It does not add a
`redirect_uri`. So the `authorizeUrl` you build must already contain:

```
redirect_uri=https://callback.athom.com/oauth2/callback
```

and that **exact** URI must be registered as an authorized redirect URI on the provider's OAuth
client. If you omit it, Google (and most providers) reject the request:

```
Error 400: invalid_request — Missing required parameter: redirect_uri
```

`https://callback.athom.com/oauth2/callback` is the correct Athom callback host for cloud pairing
(it is also the default `REDIRECT_URL` used by `homey-oauth2app`).

### ⚠️ Pitfall 2 — `emit('authorized')` must come BEFORE `session.done()`

In both **pair** and **repair** handlers, signal success to the view first, then close the session.
`session.done()` destroys the pair session; if you call it before emitting `authorized`, any
subsequent emit/navigation targets a session that no longer exists and you get:

```
404 Not Found: PairSession with ID … not found
```

So the order is always: exchange the code → store tokens → `await session.emit('authorized')` →
(only then, if you close it manually) `session.done()`. In the standard `login_oauth2` flow the
built-in view advances to the device list on `authorized`, so you usually don't call `done()`
yourself at all.

### ⚠️ Pitfall 3 — the `login_oauth2` event protocol & the "started" latch

The `login_oauth2` pair view speaks a small protocol with your driver:
1. The view triggers the login; your driver emits **`url`** → the view opens that URL in a popup.
2. The user signs in; Athom relays the **`code`** back → your driver exchanges it for tokens.
3. Your driver emits **`authorized`** (success) or **`error`** (failure) → the view advances or shows the error.

If you guard the exchange with a "started" flag to avoid double-runs, **reset it in the catch
branch** so a failed code exchange can be retried within the same pair session (otherwise the user
must cancel and restart pairing).

### Minimal manual pairing + repair (driver.js)

```javascript
'use strict';

const Homey = require('homey');

const CLIENT_ID = Homey.env.CLIENT_ID;
const REDIRECT_URI = 'https://callback.athom.com/oauth2/callback';
const SCOPES = [
  // A write scope does NOT imply read — request read scopes explicitly.
  'https://www.googleapis.com/auth/fitness.activity.read',
];

class MyDriver extends Homey.Driver {

  buildAuthorizeUrl() {
    const params = new URLSearchParams({
      client_id: CLIENT_ID,
      redirect_uri: REDIRECT_URI,          // Pitfall 1: must be present here
      response_type: 'code',
      scope: SCOPES.join(' '),
      access_type: 'offline',              // ask for a refresh token
      prompt: 'consent',                   // force the refresh token even on re-auth
    });
    return `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`;
  }

  async _handleOAuth2(session) {
    let started = false;                   // Pitfall 3: single-run latch
    const callback = await this.homey.cloud.createOAuth2Callback(this.buildAuthorizeUrl());

    callback
      .on('url', (url) => session.emit('url', url))
      .on('code', async (code) => {
        if (started) return;
        started = true;
        try {
          if (code instanceof Error) throw code;
          const tokens = await this.exchangeCode(code);   // POST to the token endpoint
          this._tokens = tokens;
          await session.emit('authorized');                // Pitfall 2: BEFORE any done()
        } catch (err) {
          started = false;                                 // allow a retry in this session
          await session.emit('error', err.message || 'Login failed');
        }
      });
  }

  async onPair(session) {
    session.setHandler('showView', async (viewId) => {
      if (viewId === 'login_oauth2') await this._handleOAuth2(session);
    });

    session.setHandler('list_devices', async () => {
      // Use the freshly obtained tokens to enumerate accounts/devices
      const accounts = await this.listAccounts(this._tokens);
      return accounts.map(a => ({
        name: a.name,
        data: { id: a.id },
        store: { tokens: this._tokens },   // persist per-device tokens in the store
      }));
    });
  }

  // Repair reuses the same OAuth2 flow, then writes fresh tokens back to the device store.
  async onRepair(session, device) {
    session.setHandler('showView', async (viewId) => {
      if (viewId !== 'login_oauth2') return;
      let started = false;
      const callback = await this.homey.cloud.createOAuth2Callback(this.buildAuthorizeUrl());
      callback
        .on('url', (url) => session.emit('url', url))
        .on('code', async (code) => {
          if (started) return;
          started = true;
          try {
            if (code instanceof Error) throw code;
            const tokens = await this.exchangeCode(code);
            await device.setStoreValue('tokens', tokens);
            await session.emit('authorized');              // BEFORE done()
          } catch (err) {
            started = false;
            await session.emit('error', err.message || 'Re-authentication failed');
          }
        });
    });
  }
}

module.exports = MyDriver;
```

Pair (and repair) definitions in `driver.compose.json`:

```json
{
  "pair": [
    { "id": "login_oauth2", "template": "login_oauth2" },
    { "id": "list_devices", "template": "list_devices", "navigation": { "next": "add_devices" } },
    { "id": "add_devices", "template": "add_devices" }
  ],
  "repair": [
    { "id": "login_oauth2", "template": "login_oauth2" }
  ]
}
```

### Token refresh pattern

- Request a **refresh token** up front: add `access_type=offline` **and** `prompt=consent` to the
  authorize URL (Google only returns a refresh token when consent is forced).
- **Refresh on 401 and retry once.** On a 401, exchange the refresh token for a new access token,
  save it, replay the request one time; if it 401s again, surface an auth error (and call
  `device.setUnavailable()` so the user is prompted to repair).
- **Scopes are not implied.** A write scope does **not** grant read — request `…readonly` scopes
  explicitly for a read-only integration.

```javascript
async apiFetch(device, path, init = {}, retried = false) {
  let tokens = device.getStoreValue('tokens');
  const res = await fetch(`https://api.example.com${path}`, {
    ...init,
    headers: { ...init.headers, Authorization: `Bearer ${tokens.access_token}` },
  });

  if (res.status === 401 && !retried) {
    tokens = await this.refreshTokens(tokens.refresh_token);   // POST refresh_token to TOKEN_URL
    await device.setStoreValue('tokens', tokens);
    return this.apiFetch(device, path, init, true);            // retry exactly once
  }
  if (!res.ok) throw new Error(`API ${res.status}`);
  return res.json();
}
```

### Prefer `homey-oauth2app` when you can

The library wires the `login_oauth2` view, token storage, and the exact refresh-on-401-retry-once
logic above for you:

```bash
npm install homey-oauth2app
```

```javascript
// app.js
const { OAuth2App } = require('homey-oauth2app');
class MyApp extends OAuth2App {
  static OAUTH2_CLIENT = MyOAuth2Client;
  async onOAuth2Init() { /* register Flow cards, etc. */ }
}
```

```javascript
// lib/MyOAuth2Client.js
const { OAuth2Client } = require('homey-oauth2app');
class MyOAuth2Client extends OAuth2Client {
  static API_URL = 'https://api.example.com';
  static TOKEN_URL = 'https://oauth2.googleapis.com/token';
  static AUTHORIZATION_URL = 'https://accounts.google.com/o/oauth2/v2/auth';
  static REDIRECT_URL = 'https://callback.athom.com/oauth2/callback';
  static SCOPES = ['https://www.googleapis.com/auth/fitness.activity.read'];

  // Built in: refresh when the API returns 401, then retry the request once.
  async onShouldRefreshToken({ status }) { return status === 401; }

  async getData() { return this.get({ path: '/data' }); }
}
```

```javascript
// drivers/<id>/driver.js
const { OAuth2Driver } = require('homey-oauth2app');
class MyDriver extends OAuth2Driver {
  async onPairListDevices({ oAuth2Client }) {
    const accounts = await oAuth2Client.getData();
    return accounts.map(a => ({ name: a.name, data: { id: a.id } }));
  }
}
```

The library still redirects through `https://callback.athom.com/oauth2/callback`, so the redirect
URI and scope rules above apply unchanged.

Environment variables for OAuth2 go in `/env.json` (gitignored):
```json
{
  "CLIENT_ID": "your_client_id",
  "CLIENT_SECRET": "your_client_secret"
}
```

---

## Webhooks

Homey can receive external webhooks even behind a router:

```javascript
const webhookData = { some: 'identifier' };
const webhook = await this.homey.cloud.createWebhook(
  Homey.env.WEBHOOK_ID,
  Homey.env.WEBHOOK_SECRET,
  webhookData
);

webhook.on('message', (message) => {
  // message.headers, message.query, message.body
  this.log('Webhook received:', message.body);
});
```

Register a webhook ID + secret at `https://tools.developer.homey.app/webhooks`, store them in
`/env.json` (`WEBHOOK_ID`, `WEBHOOK_SECRET`). Athom forwards matching webhooks to your Homey. Two
routing options (a third, "Cloud Function", is legacy/read-only):

- **Query parameter (dynamic):** get the Homey's id and build a URL the provider posts to:
  ```javascript
  const homeyId = await this.homey.cloud.getHomeyId();
  const url = `https://webhooks.athom.com/webhook/${Homey.env.WEBHOOK_ID}?homey=${homeyId}`;
  ```
  With a `homey` query param the `data` argument to `createWebhook()` isn't needed.
- **Key path (static URL):** pass `data` containing `$key` or `$keys` (e.g. `{ $keys: ['aaa','bbb'] }`);
  the key path is an ECMAScript-style expression over `body`/`headers`/`query`
  (`headers['X-Device-Id']`), case-sensitive. All Homeys with matching data receive the message.

---

## Homey Cloud restrictions

Targeting `"platforms": ["cloud"]` (or `["local","cloud"]`) requires a Verified Developer
subscription and imposes a stricter runtime. Validate with `homey app validate --level verified`.

- **SDK v3 only.** Add `"platforms"` to App, Driver, **and** Flow manifests; drivers also set
  `connectivity`.
- **`connectivity` values:** `lan` and `rf868` are **not** possible on Homey Bridge; supported:
  `cloud` (OAuth/Webhooks), `ble`, `zwave`, `zigbee`, `infrared`, `rf433`. Matter and LAN discovery
  (mDNS/SSDP/MAC) are local/Pro-only.
- **Multi-tenancy:** many app instances share one Node.js process — **no global mutable variables**;
  keep state on `this.` (App/Driver/Device instances).
- **Cleanup:** implement `onUninit()` on App/Driver/Device and use `this.homey.setTimeout`/
  `setInterval` so timers auto-clear. **Unhandled promise rejections crash the app** — always
  `.catch(this.error)`.
- **Unsupported on Cloud:** the App Web API (`api.js` REST; webhooks still work), app-to-app comms
  (`homey:app:<appId>`), `homey:manager:api` (so "Tools"-category apps are generally rejected),
  custom App Settings views, and `ManagerCloud#getLocalAddress()`.

---

## Z-Wave

Use `homey-zwavedriver` (SDK v3; the SDK v2 predecessor was `homey-meshdriver`):

```bash
npm install homey-zwavedriver
```

Base classes: `ZwaveDevice`, `ZwaveLightDevice`.

```javascript
const { ZwaveDevice } = require('homey-zwavedriver');

class MyZwaveDevice extends ZwaveDevice {
  async onNodeInit({ node }) {
    this.registerCapability('onoff', 'SWITCH_BINARY');
    this.registerCapability('dim', 'SWITCH_MULTILEVEL');
    this.registerCapability('measure_power', 'METER');
  }
}
```

Command classes are structured Command Class → Command in three categories: **set** / **report** /
**get** (e.g. `COMMAND_CLASS_BASIC` → `BASIC_SET`, `BASIC_GET`, `BASIC_REPORT`). The exhaustive
`registerCapability` option matrix (`get`, `set`, `report`, `getParser`, `setParser`,
`reportParser`, `getOpts.getOnStart`, `pollInterval`, …) lives in the apidoc `ZwaveDevice.html`.

### driver.compose.json `zwave` object:
- `manufacturerId` (number), `productTypeId` (array), `productId` (array).
- `learnmode` / `unlearnmode` — each `{ image, instruction }`.
- `requireSecure` (boolean) — opt into S0/S2 security.
- `defaultConfiguration` — array of `{ id, size, value }`.
- `associationGroups` (array of group numbers) + `associationGroupsOptions`;
  `associationGroupsMultiChannel` for pre-v13.2.0 compatibility.
- `wakeUpInterval` — seconds, range **30–16777215**.
- `multiChannelNodes` — endpoint defs (`name`, `class`, `capabilities`, `icon`, `settings`).

### Config-parameter settings (`driver.settings.compose.json` `zwave` object):
- `index` (parameter number), `size` (1/2/4 bytes), `signed` (**defaults to signed/true**).

### Security & associations:
- **S2** (modern): Homey grants all requested keys. **S0** (legacy) needs `"requireSecure": true`.
  Homey Pro 2016–2019 grants only the *highest* requested key.
- Homey is auto-added to **group 1 (Lifeline)**; multi-channel associations are automatic from v13.2.0+.

Manifest: `"connectivity": ["zwave"]`. Devices pair through Homey's built-in inclusion. Firmware OTA
is possible via `driver.firmware.compose.json` (see the firmware note below).

---

## Zigbee

Use `homey-zigbeedriver` with its `zigbee-clusters` peer dependency (the ZCL implementation):

```bash
npm install --save homey-zigbeedriver zigbee-clusters
```

Base classes: `ZigBeeDevice`, `ZigBeeLightDevice` (lights), `ZigBeeDriver`. `zigbee-clusters` exports
`ZCLNode`, `CLUSTER`, `BoundCluster`.

```javascript
const { ZigBeeDevice } = require('homey-zigbeedriver');
const { CLUSTER } = require('zigbee-clusters');

class MyZigbeeDevice extends ZigBeeDevice {
  async onNodeInit({ zclNode }) {
    this.registerCapability('onoff', CLUSTER.ON_OFF);
    this.registerCapability('dim', CLUSTER.LEVEL_CONTROL);

    // Attribute reporting listener
    zclNode.endpoints[1].clusters.onOff
      .on('attr.onOff', (value) => {
        this.setCapabilityValue('onoff', value).catch(this.error);
      });
  }
}
```

- **Lifecycle:** `onNodeInit({ zclNode })` (primary) or low-level `onInit()`; `isFirstInit()` detects
  the first init after pairing. **Do NOT initiate communication with the node during
  `onInit`/`onNodeInit`.** Always `.catch()` promises in `onNodeInit`.
- `registerCapability(capability, CLUSTER.NAME, opts)` maps capability → cluster;
  `configureAttributeReporting([{ endpointId, cluster, attributeName, minInterval, maxInterval, minChange }])`.
- Send a command: `zclNode.endpoints[1].clusters.onOff.toggle()`; read:
  `.readAttributes(['onOff'])`. Receive incoming commands by binding a `BoundCluster` subclass:
  `zclNode.endpoints[1].bind(CLUSTER.NAME, boundClusterInstance)`.
- Debug: `const { debug } = require('zigbee-clusters'); debug(true);`.

### driver.compose.json `zigbee` object:
- `manufacturerName` (required), `productId` (required; **array** for multiple variants).
- `endpoints` — per endpoint: `clusters` (implemented as client — send/read) and `bindings`
  (implemented as server — receive).
- `learnmode` — `{ image, instruction }`.
- `devices` — optional **sub-device** definitions (needs Homey v5.0.0+ and `homey-zigbeedriver@1.6.0+`);
  read `this.getData().subDeviceId` and split logic with `Driver#onMapDeviceClass()`.

**Gotchas:** IAS Zone (cluster `1280`) auto-enrolls from Homey v13.1.2+ (zone id `0`;
`onZoneEnrollRequest` no longer forwarded). Group-broadcast listening differs by model (Pro 2016–2019
& Bridge listen to all groups; Pro 2023+/mini only to group `0` and Touchlink groups). Manifest:
`"connectivity": ["zigbee"]`.

---

## Bluetooth LE

Permission `homey:wireless:ble`. Advertisement subscriptions require the `ble-advertisements` feature
— check `this.homey.hasFeature('ble-advertisements')` (supported on Homey Pro Early-2023, Pro mini,
Pro 2026, and Self-Hosted Server). GATT hierarchy:
**Advertisement → Peripheral → Service → Characteristic → Descriptor**.

```javascript
class MyDevice extends Homey.Device {
  async onInit() {
    const advertisement = await this.homey.ble.find(this.getData().uuid);
    const peripheral = await advertisement.connect();
    await peripheral.discoverServices();
    const value = await peripheral.read(SERVICE_UUID, CHAR_UUID);
    // ...then peripheral.disconnect() when done
  }
}
```

- **ManagerBLE** (`this.homey.ble`): `discover()` / `discover(serviceUuids)`, `find(uuid)`,
  `subscribeToAdvertisements(uuid, options, cb)` / `unsubscribeFromAdvertisements(uuid)`.
- **BlePeripheral**: `read(svc, char)`, `write(svc, char, data)`, `discoverServices()`,
  `getService(uuid)`, `disconnect()`. **BleCharacteristic**: `read()`, `write(data)`,
  `subscribeToNotifications(cb)` / `unsubscribeFromNotifications()`.
- Advertisement props: `uuid`, `rssi`, `connectable`, `state`, `address`, `addressType` (always
  present); `localName`, `serviceUuids`, `serviceData` (optional).
- **Gotchas:** subscribe to advertisements for near-realtime data without opening a GATT connection;
  since Homey 6.0 peripherals no longer auto-disconnect after 60 s, and BLE notifications are
  available; handle-based read/write and Included Services are **not** supported; some devices reject
  multiple connections — don't hold connections needlessly. BLE is Homey Pro only. Manifest:
  `"connectivity": ["ble"]`.

---

## 433 MHz / 868 MHz {#433-868-mhz}

Use `homey-rfdriver` (`npm install homey-rfdriver`). Base classes: `RFSignal`, `RFDriver`,
`RFDevice`. Statics: Signal `static FREQUENCY = '433' | '868' | 'ir'`, Driver `static SIGNAL`,
Device `static CAPABILITIES`.

- **Permissions:** `homey:wireless:433`; `homey:wireless:868` (**Homey Pro 2019 or earlier only**).
- **Signal definitions:** `/.homeycompose/signals/<433|868>/<id>.json`. Fields (times in µs) include
  `sof`, `eof`, `words` (data words), `interval` (5–32767, default **5000**), `sensitivity`
  (0.0–0.5, default **0.3**), `repetitions` (1–255, default **10**), `minimalLength`/`maximalLength`,
  `agc`, `manchesterUnit`, `prefixData`/`postfixData`, `cmds` (name → int array), `toggleSof`,
  `toggleBits`, `packing` (default false), `txOnly` (default false), `carrier` (Hz), and a
  `modulation` object (`type` `'ASK'|'FSK'|'GFSK'` default ASK, `channelSpacing`, `channelDeviation`,
  `baudRate`).
- **Radio defaults:** 433 MHz carrier 433890000 Hz; 868 MHz carrier 868300000 Hz (Pro 2016–2019 only).
- **Runtime:** `this.homey.rf.getSignal433(id)` / `getSignal868` / `getSignalInfrared`; then
  `signal.enableRX()` / `disableRX()`, `signal.tx(bits)`, `signal.cmd(name)`,
  `signal.on('payload', cb)`.
- **Limits:** ≤ 256 time-interval arrays per signal; total duration 5 µs – 1 s; filter bandwidth is a
  shared resource and can't be changed.

---

## Infrared

Also `homey-rfdriver`, with Signal `static FREQUENCY = 'ir'`. Permission `homey:wireless:ir`.

- **Signal definitions:** `/.homeycompose/signals/ir/<id>.json`. Fields as for RF, but `carrier`
  defaults to **38000** (30000–45000) and `interval` is in **milliseconds**. Prontohex signals use
  `"type": "prontohex"` with `cmds` mapping identifiers → Prontohex strings.
- driver.compose.json IR block: `"infrared": { "satelliteMode": true }`.
- Built-in pairing steps from the library: `"rf_ir_remote_learn"` and `"rf_ir_remote_add"`.
- **Runtime:** `this.homey.rf.getSignalInfrared('id')`, then `.cmd('COMMAND_NAME')`.

---

## Matter

Supported since Homey Pro (Early 2023) firmware **v11.1.0**, on Homey Pro (Early 2023/2026/mini) and
Self-Hosted Server — **not on Homey Cloud** (local only). Homey Pro already controls Matter devices
**without any app**; an app only *enhances* pairing (instructions, icons, naming).

- driver.compose.json: `"platforms": ["local"]`, `"connectivity": ["matter"]`, plus a `matter`
  object with `vendorId` and `productId` (number or array, **base-10, not hex**) and optional
  `learnmode` (`{ instruction, image }`). For a **bridge**, use `"class": "bridge"` with empty
  capabilities and add `deviceVendorId` / `deviceProductName` (from the Bridged Device Basic
  Information cluster) while keeping the bridge's own `vendorId`/`productId`.
- **Constraints:** you may **not** define custom `Driver`/`Device` classes for Matter; the manifest
  `class`/`capabilities` are ignored (Homey determines them at pairing). Optionally add `"matter"` to
  the app manifest's `platformLocalRequiredFeatures`.
- **Thread:** there is no separate Thread SDK. Matter runs over Wi-Fi/Ethernet/**Thread**, and Homey
  Pro / Pro mini act as a **Thread Border Router automatically** (no manual config) — you interact
  with Thread devices only through the Matter driver manifest above.

---

## Firmware updates (Z-Wave & Zigbee OTA)

Both support serving OTA firmware from the app via `/drivers/<driver_id>/driver.firmware.compose.json`
(requires Homey firmware **v13.2.0+**, Mobile App v9.10.0+; CLI `homey app driver firmware`, homey
CLI v4.3.0+, auto-fills `size`/`name`/`integrity`). Firmware binaries live in
`/drivers/<driver_id>/assets/firmware/`. Homey selects a file matching the device identifier whose
version is **higher** than the device's current version; integrity is a `<hash>:<hex>` string (SHA-2/
SHA-3/BLAKE2 families). Z-Wave entries add `version`/`applicableTo` (semver) and a `region`
(`EU`, `US`, …); Zigbee entries use numeric `fileVersion`/`imageType`/`manufacturerCode`. Add a
`wakeInstruction` for sleepy (battery) devices.
