# Wireless & Cloud Reference

## Table of Contents
1. [Wi-Fi / LAN Devices](#wifi-lan)
2. [Discovery Strategies](#discovery-strategies)
3. [OAuth2](#oauth2)
4. [Webhooks](#webhooks)
5. [Z-Wave](#z-wave)
6. [Zigbee](#zigbee)
7. [Bluetooth LE](#bluetooth-le)
8. [433 MHz / 868 MHz](#433-868-mhz)
9. [Infrared](#infrared)
10. [Matter](#matter)

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

### MAC Address (ARP):
```json
{
  "type": "mac",
  "mac": {
    "manufacturer": [[0, 36, 109], [0, 36, 110]]
  }
}
```
MAC bytes are specified in decimal (JSON doesn't support hex).

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
  this.log('Webhook received:', message.body);
});
```

Register webhook IDs at https://tools.developer.homey.app/. The webhook URL format is:
`https://webhooks.athom.com/webhook/<WEBHOOK_ID>?homey=<HOMEY_ID>&...`

---

## Z-Wave

Use the `homey-zwavedriver` library:

```bash
npm install homey-zwavedriver
```

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

Z-Wave devices pair automatically through Homey's built-in Z-Wave inclusion process.
The driver manifest should specify `"connectivity": ["zwave"]`.

---

## Zigbee

Use the `homey-zigbeedriver` library:

```bash
npm install homey-zigbeedriver
```

```javascript
const { ZigBeeDevice } = require('homey-zigbeedriver');
const { CLUSTER } = require('zigbee-clusters');

class MyZigbeeDevice extends ZigBeeDevice {
  async onNodeInit({ zclNode }) {
    this.registerCapability('onoff', CLUSTER.ON_OFF);
    this.registerCapability('dim', CLUSTER.LEVEL_CONTROL);

    zclNode.endpoints[1].clusters[CLUSTER.ON_OFF.NAME]
      .on('attr.onOff', (value) => {
        this.setCapabilityValue('onoff', value).catch(this.error);
      });
  }
}
```

Driver manifest: `"connectivity": ["zigbee"]`.

---

## Bluetooth LE

For BLE devices, use the Homey BLE manager:

```javascript
class MyDevice extends Homey.Device {
  async onInit() {
    const advertisement = await this.homey.ble.find(this.getData().uuid);
    const peripheral = await advertisement.connect();
    const services = await peripheral.discoverServices();
    // Read/write characteristics
  }
}
```

BLE is available on Homey Pro only. Driver manifest: `"connectivity": ["ble"]`.

---

## 433 MHz / 868 MHz {#433-868-mhz}

Use the `homey-rfdriver` library for radio frequency devices:

```bash
npm install homey-rfdriver
```

Signal definitions go in `/.homeycompose/signals/433/<id>.json` or `868/<id>.json`.
Requires `homey:wireless:433` or `homey:wireless:868` permission.

---

## Infrared

Use the `homey-rfdriver` library for IR devices as well.
Signal definitions go in `/.homeycompose/signals/ir/<id>.json`.
Requires `homey:wireless:ir` permission.

---

## Matter

Matter is supported since Homey Pro v10+. Homey acts as a Matter controller.
Matter support is still evolving — check the latest docs for current status.

Driver manifest: `"connectivity": ["matter"]`.
