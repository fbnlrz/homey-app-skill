# Advanced Features Reference

Managers and features beyond drivers/flow/widgets. Access every manager via `this.homey.<manager>`.
Exact signatures live in the apidoc at <https://apps-sdk-v3.developer.homey.app/>.

## Table of Contents
1. [App Web API (`api.js`)](#web-api)
2. [Realtime events & app-to-app](#realtime)
3. [Images & image Flow tokens](#images)
4. [Videos (cameras)](#videos)
5. [LED Ring](#ledring)
6. [Speech, Geolocation, Clock, NFC](#misc-managers)
7. [Manager quick-map](#manager-map)

---

## App Web API (`api.js`) {#web-api}

An app can expose a REST + realtime Web API. **Homey Pro only — not available on Homey Cloud.**

- Routes are declared in the **App Manifest** under `"api"` (SDK v3 no longer infers them from
  `api.js`). Each route key is the exported handler name:
  ```json
  {
    "api": {
      "getSomething": { "method": "GET",  "path": "/" },
      "getById":      { "method": "GET",  "path": "/:id" },
      "doThing":      { "method": "POST", "path": "/thing", "public": true }
    }
  }
  ```
  `method` is `GET`/`POST`/`PUT`/`DELETE` (or an array). `public` (default `false`) — protected
  routes require the user to have granted the app permission (granted on install).
- Implementation lives in the app-root `api.js` (or `api.mts`/`api.py`). Handlers are async functions
  matching the route names and receive `{ homey, body, params, query }` (GET/DELETE get an empty
  body). Reach the app via `homey.app`:
  ```javascript
  module.exports = {
    async getById({ homey, params, query }) {
      return homey.app.getThing(params.id);
    },
  };
  ```
- Endpoints are reachable at `/api/app/<appId>/…` (also from the settings page via `Homey.api(...)`
  and from other apps).
- **This is NOT the widget `api.js`** — widgets have their own `api.js` scoped to the widget webview
  (see `references/widgets.md`). The app-level Web API is external REST + realtime.

Requires the `homey:manager:api` permission **only** for using the Homey Web API to control *other*
devices/flows — not for exposing your own app's routes. `homey:manager:api` is for "Tools"-type apps
(HomeyScript, Device Groups, DIY alarm), reviewed strictly, and **forbidden on Homey Cloud**.

## Realtime events & app-to-app {#realtime}

- **Realtime (one-way push to clients such as a settings page or widget):**
  ```javascript
  await this.homey.api.realtime('my_event', 'any JSON-stringifiable value');
  ```
  Clients subscribe with `Homey.on('my_event', cb)`.
- **App-to-app communication** (Homey Pro only; needs `homey:app:<appId>` permission):
  ```javascript
  const other = this.homey.api.getApiApp('com.athom.otherApp');   // ApiApp
  if (await other.getInstalled() && await other.getVersion()) {
    await other.post('/play', { sound: 'bell' });
  }
  other.on('realtime', ({ event, data }) => { /* … */ });
  ```
  Always check `getInstalled()` + version before calling. Not supported on Homey Cloud.

## Images & image Flow tokens {#images}

`this.homey.images` (**ManagerImages**). Images are **max 5 MB**. Debug at
`tools.developer.homey.app/tools/images`.

```javascript
const img = await this.homey.images.createImage();
img.setUrl('https://example.com/pic.png');        // URL must be https://
// or img.setPath('/userdata/pic.png');            // local/shipped file
// or img.setStream(async (stream) => res.body.pipe(stream));  // Homey >= 2.2.0
await img.update();                                 // re-fetch on the frontend
```

Consume: `const stream = await img.getStream();` → `stream.contentType`, `stream.filename`; an image
also exposes `img.cloudUrl` / `img.localUrl`. (The SDK v3 removed `Image.format`, `getFormat()`,
`getBuffer()`, `setBuffer()`.)

**As a Flow token** (types: `string`, `number`, `boolean`, `image`):
```javascript
const token = await this.homey.flow.createToken('my_image', { type: 'image', title: 'My Image' });
await token.setValue(img);
// or pass directly to a trigger: await myTriggerCard.trigger({ my_image: img });
```
Receiving an image argument (`droptoken`) in an action run listener:
```javascript
const stream = await args.droptoken.getStream();   // stream.meta.contentType, stream.meta.filename
```

## Videos (cameras) {#videos}

`this.homey.videos` (**ManagerVideos**) — Homey Pro 2023–2026 / mini since v12.7.0 **and Homey Cloud**.
Supports WebRTC, RTSP, RTMP, HLS, DASH. Since v12.12.0 Homey auto-serves videos as WebRTC to the
frontend (opt out with `disableWebRTCProxy: true`).

```javascript
const video = await this.homey.videos.createVideoRTSP({ demuxer: 'h265' });
video.registerVideoUrlListener(async () => ({ url: 'rtsp://user:pass@ip:554/stream' }));
await this.setCameraVideo('main', 'Main Camera', video);   // Device#setCameraVideo(id, name, video)
```
Other creators: `createVideoWebRTC({ dataChannel })` (with `registerOfferListener`),
`createVideoRTMP()`, `createVideoHLS()`, `createVideoDASH()`. If a device has an image and a video
with the same `id`, the image is the loading background.

## LED Ring {#ledring}

`this.homey.ledring` (**ManagerLedring**) — controllable only on **Homey Pro (Early 2019) and older**;
add `"ledring"` to `platformLocalRequiredFeatures` and request permission `homey:manager:ledring`.

```javascript
const anim = await this.homey.ledring.createSystemAnimation('pulse');
await anim.start();
```
Custom animation: `createAnimation({ options: { fps, tfps, rpm }, frames, priority, duration })` where
`priority` is `INFORMATIVE`/`FEEDBACK`/`CRITICAL` and each frame is an array of exactly **24** pixels
`{ r, g, b }` (0–255). Screensavers: define in `/.homeycompose/screensavers/<id>.json` (with `title`)
and register via `anim.registerScreensaver('<id>')`.

## Speech, Geolocation, Clock, NFC {#misc-managers}

- **Speech output** — `this.homey.speechOutput` (**ManagerSpeechOutput**), permission
  `homey:manager:speech-output` (text-to-speech; there is no dedicated speech-input manager page).
- **Geolocation** — `this.homey.geolocation` (**ManagerGeolocation**), permission
  `homey:manager:geolocation`.
- **Clock / timezone** — `this.homey.clock`. **SDK v3 forces `process.env.TZ = 'UTC'`**, so
  `new Date(...)`, `getHours()`, etc. operate in UTC. Get the user's zone with
  `await this.homey.clock.getTimezone()` (e.g. `Europe/Amsterdam`) and format with
  `Intl.DateTimeFormat(locale, { timeZone })`.
- **NFC** — `this.homey.nfc` (**ManagerNFC**), permission `homey:wireless:nfc` (scanned NFC tags).
- **Scheduling** — there is **no ManagerCron** (removed). Use `this.homey.setTimeout` /
  `setInterval` (+ `clear*`), which auto-clear on app destroy, or the `this.homey.on('unload', …)`
  event for teardown.

## Manager quick-map {#manager-map}

| Access | Manager | Highlights |
|---|---|---|
| `this.homey.flow` | ManagerFlow | `getTriggerCard`, `getDeviceTriggerCard`, `getConditionCard`, `getActionCard`, `createToken` |
| `this.homey.cloud` | ManagerCloud | `createOAuth2Callback`, `createWebhook`, `getHomeyId`, `getLocalAddress` (not on Cloud) |
| `this.homey.api` | ManagerApi | `realtime`, `getApiApp` (both not on Cloud) |
| `this.homey.images` | ManagerImages | `createImage` |
| `this.homey.videos` | ManagerVideos | `createVideoWebRTC/RTSP/RTMP/HLS/DASH` |
| `this.homey.ledring` | ManagerLedring | `createSystemAnimation`, `createAnimation` |
| `this.homey.insights` | ManagerInsights | `createLog/deleteLog/getLog/getLogs` (write-only — no read of entries) |
| `this.homey.settings` | ManagerSettings | `get/set/unset`, `on('set'|'unset')` |
| `this.homey.clock` | ManagerClock | `getTimezone` |
| `this.homey.geolocation` | ManagerGeolocation | location (permission) |
| `this.homey.speechOutput` | ManagerSpeechOutput | TTS (permission) |
| `this.homey.nfc` | ManagerNFC | NFC tags (permission) |
| `this.homey.dashboards` | ManagerDashboards | `getWidget().registerSettingAutocompleteListener` |
| `this.homey.discovery` | ManagerDiscovery | `getStrategy` |
| `this.homey.drivers` | ManagerDrivers | `getDriver`, `getDrivers` |
| `this.homey.app` | — | the App instance |
