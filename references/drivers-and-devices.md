# Drivers & Devices Reference

## Table of Contents
1. [Driver Class](#driver-class)
2. [Device Class](#device-class)
3. [Driver Manifest (driver.compose.json)](#driver-manifest)
4. [Capabilities](#capabilities)
5. [Custom Capabilities](#custom-capabilities)
6. [Device Settings](#device-settings)
7. [Pairing](#pairing)
8. [Device Availability](#device-availability)
9. [Device Store](#device-store)
10. [Discovery Integration](#discovery-integration)

---

## Driver Class

The `/drivers/<driver_id>/driver.js` file exports a class extending `Homey.Driver`. It manages all
Device instances for that driver and handles pairing.

```javascript
'use strict';

const Homey = require('homey');

class MyDriver extends Homey.Driver {

  async onInit() {
    // Register driver-specific Flow cards if needed
    this.log('MyDriver initialized');
  }

  // Simple pairing: return list of discovered devices
  async onPairListDevices() {
    const discoveredDevices = await this.discoverDevices();
    return discoveredDevices.map(device => ({
      name: device.name,
      data: {
        id: device.serialNumber, // Must be unique and immutable!
      },
      store: {
        address: device.ipAddress, // Mutable data goes in store
      },
      settings: {
        pollInterval: 30,
      },
    }));
  }

  // Advanced pairing: full control over the pair session
  async onPair(session) {
    session.setHandler('list_devices', async () => {
      return this.onPairListDevices();
    });

    session.setHandler('showView', async (viewId) => {
      // React to view navigation
    });
  }

  // Map device to different Device subclasses based on capabilities
  onMapDeviceClass(device) {
    if (device.hasCapability('dim')) {
      return MyDimmableDevice;
    }
    return MyDevice;
  }
}

module.exports = MyDriver;
```

### Key Driver methods:
- `onInit()` — Called when the driver is initialized
- `onPairListDevices()` — Simple pairing: return array of device objects
- `onPair(session)` — Advanced pairing: full session control
- `onRepair(session, device)` — Handle device repair
- `onMapDeviceClass(device)` — Return different Device classes per device
- `getDevices()` — Get all paired Device instances
- `getDevice({ id })` — Get a specific device by its data

---

## Device Class

The `/drivers/<driver_id>/device.js` represents a single paired device.

```javascript
'use strict';

const Homey = require('homey');

class MyDevice extends Homey.Device {

  async onInit() {
    this.log('Device initialized:', this.getName());

    // Register listeners for user-initiated capability changes
    this.registerCapabilityListener('onoff', async (value) => {
      await this.apiClient.setPower(value);
    });

    this.registerCapabilityListener('dim', async (value, opts) => {
      await this.apiClient.setBrightness(value * 100);
    });

    // Start polling for device state
    this.pollInterval = this.homey.setInterval(() => {
      this.pollDevice().catch(this.error);
    }, 30000);
  }

  async pollDevice() {
    const state = await this.apiClient.getState();
    await this.setCapabilityValue('onoff', state.power).catch(this.error);
    await this.setCapabilityValue('dim', state.brightness / 100).catch(this.error);
    await this.setCapabilityValue('measure_power', state.wattage).catch(this.error);
  }

  async onAdded() {
    // Device has been added (just after pairing)
    this.log('Device added');
  }

  async onSettings({ oldSettings, newSettings, changedKeys }) {
    // Called when the user updates device settings
    if (changedKeys.includes('pollInterval')) {
      this.restartPolling(newSettings.pollInterval);
    }
  }

  async onDeleted() {
    // Device has been deleted, clean up
    this.homey.clearInterval(this.pollInterval);
  }

  async onUninit() {
    // App is being destroyed (Homey Cloud)
    this.homey.clearInterval(this.pollInterval);
  }
}

module.exports = MyDevice;
```

### Key Device methods & properties:
- `onInit()` — Device initialization
- `onAdded()` — Called right after pairing
- `onSettings({ oldSettings, newSettings, changedKeys })` — Settings changed by user
- `onDeleted()` — Device removed by user
- `onUninit()` — App being destroyed
- `getName()` — Device name
- `getData()` — Immutable device data (set during pairing)
- `getSetting(key)` / `getSettings()` — Read device settings
- `setSettings({ key: value })` — Update settings programmatically (does NOT call onSettings)
- `getStoreValue(key)` / `setStoreValue(key, value)` — Persistent key-value store
- `setCapabilityValue(capId, value)` — Update a capability value (device → Homey)
- `getCapabilityValue(capId)` — Read current capability value
- `registerCapabilityListener(capId, listener)` — Listen for capability changes (Homey → device)
- `registerMultipleCapabilityListener(capIds, listener, timeout)` — Debounced multi-cap listener
- `hasCapability(capId)` — Check if device has a capability
- `addCapability(capId)` / `removeCapability(capId)` — Add/remove capabilities (expensive, use sparingly)
- `setAvailable()` / `setUnavailable(message)` — Control device availability
- `setWarning(message)` / `unsetWarning()` — Show/clear warning to user
- `this.driver` — Reference to the Driver instance
- `this.homey.app` — Reference to the App instance

### Multiple capability listener (debounced):
```javascript
this.registerMultipleCapabilityListener(
  ['dim', 'light_hue', 'light_saturation'],
  async (capabilityValues, capabilityOptions) => {
    // capabilityValues = { dim: 0.5, light_hue: 0.8, light_saturation: 1.0 }
    await this.apiClient.setColor(capabilityValues);
  },
  500 // debounce timeout in ms
);
```

---

## Driver Manifest

`/drivers/<driver_id>/driver.compose.json`:

```json
{
  "name": { "en": "My Smart Plug" },
  "class": "socket",
  "capabilities": ["onoff", "measure_power", "meter_power"],
  "capabilitiesOptions": {
    "measure_power": {
      "approximated": true
    }
  },
  "platforms": ["local"],
  "connectivity": ["lan"],
  "energy": {
    "approximation": {
      "usageOn": 5,
      "usageOff": 0.5
    }
  },
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

### Device classes:
`light`, `socket`, `vacuumcleaner`, `fan`, `heater`, `thermostat`, `sensor`, `doorbell`,
`lock`, `windowcoverings`, `tv`, `speaker`, `camera`, `remote`, `button`, `kettle`,
`coffeemachine`, `homealarm`, `solarpanel`, `other`

### Connectivity options:
`"cloud"`, `"lan"`, `"infrared"`, `"433"`, `"868"`, `"zigbee"`, `"zwave"`, `"ble"`
Can be an array for devices using multiple: `["infrared", "lan"]`

### Platforms:
- `"local"` — Homey Pro (runs locally)
- `"cloud"` — Homey Cloud (runs in Docker)

---

## Capabilities

Capabilities define what a device can do. Homey provides many system capabilities:

### Common system capabilities:
| Capability | Type | Description |
|---|---|---|
| `onoff` | boolean | On/off state |
| `dim` | number (0-1) | Brightness |
| `light_hue` | number (0-1) | Color hue |
| `light_saturation` | number (0-1) | Color saturation |
| `light_temperature` | number (0-1) | Color temperature |
| `target_temperature` | number | Target temperature |
| `measure_temperature` | number | Current temperature (°C) |
| `measure_humidity` | number | Humidity (%) |
| `measure_power` | number | Power usage (W) |
| `meter_power` | number | Energy usage (kWh) |
| `alarm_motion` | boolean | Motion detected |
| `alarm_contact` | boolean | Contact sensor |
| `alarm_battery` | boolean | Low battery |
| `measure_battery` | number | Battery level (%) |
| `volume_set` | number (0-1) | Volume level |
| `volume_mute` | boolean | Muted state |
| `windowcoverings_state` | enum | up/idle/down |
| `button` | boolean | Button (stateless trigger) |
| `speaker_playing` | boolean | Playing state |
| `locked` | boolean | Lock state |

Full list: https://apps-sdk-v3.developer.homey.app/tutorial-device-capabilities.html

### Capability options (in driver manifest):
```json
{
  "capabilitiesOptions": {
    "target_temperature": {
      "min": 5,
      "max": 35,
      "step": 0.5
    },
    "onoff": {
      "duration": true
    },
    "dim": {
      "duration": true
    }
  }
}
```

---

## Custom Capabilities

Define in `/.homeycompose/capabilities/<id>.json`:

```json
{
  "type": "number",
  "title": { "en": "Air Quality Index" },
  "getable": true,
  "setable": false,
  "uiComponent": "sensor",
  "icon": "/assets/aqi.svg",
  "units": { "en": "AQI" },
  "min": 0,
  "max": 500,
  "step": 1,
  "insights": true
}
```

### Capability types: `boolean`, `number`, `string`, `enum`

### Key properties:
- `getable` (default true) — Can the value be read by the frontend?
- `setable` (default true) — Can the value be set by the frontend?
- `uiComponent` — How it renders: `"sensor"`, `"slider"`, `"toggle"`, `"picker"`, `"button"`, `"thermostat"`, `"color"`, `"media"`, `null`
- `insights` (boolean) — Log values to Homey Insights charts (write-only at runtime — see below)
- `units` — Translation object for units display

### ⚠️ Insights is WRITE-ONLY at runtime

An app **cannot read a capability's Insights history back at runtime.** `insights: true` lets Homey
*store* and chart the values, but the App SDK gives you no way to retrieve them:

- `ManagerInsights` (`this.homey.insights`) exposes only `createLog`, `deleteLog`, `getLog`,
  `getLogs` — it lists and manages logs, but hands back no historical entries.
- An `InsightsLog` object has only `createEntry(value)` — there is **no `getEntries()`** or any
  history-read method.

So if you need to render history yourself (a sparkline in a widget, a rolling average, a report),
**keep your own capped rolling buffer** — sample the value each poll and store a bounded array in
the device store:

```javascript
async recordSample(value) {
  const history = this.getStoreValue('history') || [];
  history.push({ t: Date.now(), v: value });
  while (history.length > 96) history.shift();     // cap the buffer (e.g. last 96 samples)
  await this.setStoreValue('history', history);
}
```

(Homey's own Insights history is reachable only through the Homey Web API from outside the app, not
from the App SDK inside it.)

### Maintenance actions:
Button capabilities can be maintenance actions (shown in device settings):
```json
{
  "capabilitiesOptions": {
    "button.reset": {
      "maintenanceAction": true,
      "title": { "en": "Reset device" },
      "desc": { "en": "This will factory reset the device." }
    }
  }
}
```

### Sub-capabilities:
Use a capability more than once with a sub-ID: `"measure_temperature.indoor"`, `"measure_temperature.outdoor"`

---

## Device Settings

Define in `/drivers/<driver_id>/driver.settings.compose.json`:

```json
[
  {
    "type": "group",
    "label": { "en": "Connection" },
    "children": [
      {
        "id": "pollInterval",
        "type": "number",
        "label": { "en": "Poll Interval" },
        "hint": { "en": "How often to poll the device (seconds)" },
        "value": 30,
        "min": 5,
        "max": 300,
        "units": { "en": "seconds" }
      },
      {
        "id": "username",
        "type": "text",
        "label": { "en": "Username" },
        "value": ""
      },
      {
        "id": "password",
        "type": "password",
        "label": { "en": "Password" },
        "value": ""
      }
    ]
  }
]
```

### Setting types:
- `text` — Single line text
- `password` — Masked text
- `textarea` — Multi-line text
- `number` — Numeric with min/max/units
- `checkbox` — Boolean
- `dropdown` — Select from predefined values
- `radio` — Radio buttons
- `label` — Read-only text (informational)
- `group` — Group container with `children`

### Highlighted settings:
Add `"highlight": true` to show a setting prominently during pairing.

### Handling settings changes:
```javascript
async onSettings({ oldSettings, newSettings, changedKeys }) {
  if (changedKeys.includes('pollInterval')) {
    // Validate and apply — read the NEW value from newSettings, NOT getSetting()
    if (newSettings.pollInterval < 5) {
      throw new Error('Poll interval must be at least 5 seconds');
    }
    this.restartPolling(newSettings.pollInterval);
  }
}
```

Throwing an error in `onSettings()` will revert the settings change and show the error to the user.

> **⚠️ Inside `onSettings`, `this.getSetting()` still returns the OLD value.** Settings are only
> persisted *after* the handler resolves, so during the handler `getSetting('pollInterval')` /
> `getSettings()` reflect the pre-change state. Always read new values from the `newSettings`
> argument — e.g. restart a poll timer from `newSettings.pollInterval`, never from
> `this.getSetting('pollInterval')`. (Note the inverse case too: programmatic `setSettings()` does
> **not** fire `onSettings()`.)

---

## Pairing

### System pairing templates:
- `list_devices` — Show discovered devices to select
- `add_devices` — Confirm and add selected devices
- `login_oauth2` — OAuth2 login flow
- `login_credentials` — Username/password login
- `pincode` — PIN code entry
- `loading` — Loading screen
- `done` — Completion screen

### Simple pairing (list + add):
```json
{
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

Implement `onPairListDevices()` in `driver.js` to return device objects:

```javascript
async onPairListDevices() {
  return [
    {
      name: 'Living Room Light',
      data: { id: 'ABC123' },       // Unique, immutable
      store: { address: '192.168.1.50' },
      settings: { pollInterval: 30 },
      capabilities: ['onoff', 'dim'],
      icon: '/my_icon.svg',         // Relative to /drivers/<id>/assets/
    }
  ];
}
```

### Advanced pairing with `onPair()`:
```javascript
async onPair(session) {
  let username = '';
  let password = '';

  session.setHandler('login', async (data) => {
    username = data.username;
    password = data.password;
    const valid = await this.api.authenticate(username, password);
    if (!valid) throw new Error('Invalid credentials');
    return true;
  });

  session.setHandler('list_devices', async () => {
    const devices = await this.api.getDevices(username, password);
    return devices.map(d => ({
      name: d.name,
      data: { id: d.id },
    }));
  });
}
```

### Repair:
Add a `"repair"` array to the driver manifest to allow users to re-authenticate:
```json
{
  "repair": [
    { "id": "login_oauth2", "template": "login_oauth2" }
  ]
}
```

---

## Device Availability

```javascript
// Mark device as unavailable
await this.setUnavailable('Device is offline');

// Mark device as available again
await this.setAvailable();

// Show a warning (device still works, but user sees a message)
await this.setWarning('Battery low');
await this.unsetWarning();
```

When using Discovery, availability is managed automatically based on the discovery result.

---

## Device Store

Persistent key-value storage for mutable device properties:

```javascript
// Read
const address = this.getStoreValue('address');
const allKeys = this.getStoreKeys();

// Write
await this.setStoreValue('address', '192.168.1.50');

// Can also be set during pairing in the store property
```

Use the store sparingly — prefer device settings for user-configurable values and in-memory
storage for transient data.

---

## Discovery Integration

When using LAN discovery (mDNS, SSDP, MAC), the Device class integrates with the discovery system:

```javascript
class MyDevice extends Homey.Device {

  onDiscoveryResult(discoveryResult) {
    // Return true if this discovery result matches this device
    return discoveryResult.id === this.getData().id;
  }

  async onDiscoveryAvailable(discoveryResult) {
    // Device found on the network — connect!
    this.api = new DeviceAPI(discoveryResult.address);
    await this.api.connect();
  }

  async onDiscoveryAddressChanged(discoveryResult) {
    // IP address changed — reconnect
    await this.api.reconnect(discoveryResult.address);
  }

  onDiscoveryLastSeenChanged(discoveryResult) {
    // Device was seen on the network
    // Useful for updating lastSeenAt
  }
}
```

Link a discovery strategy to a driver by adding `"discovery": "my_discovery_strategy_id"`
to the driver manifest.
