# Flow Cards Reference

## Table of Contents
1. [Overview](#overview)
2. [Defining Flow Cards](#defining-flow-cards)
3. [Triggers](#triggers)
4. [Conditions](#conditions)
5. [Actions](#actions)
6. [Arguments](#arguments)
7. [Tokens](#tokens)
8. [Device Flow Cards](#device-flow-cards)
9. [Auto-generated Flow Cards](#auto-generated-flow-cards)

---

## Overview

Flow is Homey's automation engine. Users create automations with three columns:
- **When...** (triggers) — Something happened
- **And...** (conditions) — A state must be true
- **Then...** (actions) — Do something

Your app defines Flow cards in compose files and registers listeners in code.

---

## Defining Flow Cards

### App-level Flow cards (Compose)
Place in `/.homeycompose/flow/`:
- `triggers/<id>.json`
- `conditions/<id>.json`
- `actions/<id>.json`

### Driver-level Flow cards
Place in `/drivers/<driver_id>/driver.flow.compose.json`:

```json
{
  "triggers": [
    {
      "id": "button_pressed",
      "title": { "en": "A button was pressed" },
      "tokens": [
        {
          "name": "button_id",
          "type": "string",
          "title": { "en": "Button" }
        }
      ],
      "args": [
        {
          "type": "device",
          "name": "device",
          "filter": "driver_id=my_driver"
        }
      ]
    }
  ],
  "conditions": [],
  "actions": []
}
```

---

## Triggers

A trigger fires when something happens. Your app tells Homey when to fire it.

### Defining a trigger (Compose):
`/.homeycompose/flow/triggers/rain_start.json`:
```json
{
  "title": { "en": "It starts raining" },
  "hint": { "en": "Triggers when rain is detected." },
  "tokens": [
    {
      "name": "mm_per_hour",
      "type": "number",
      "title": { "en": "Amount" },
      "example": 3
    }
  ]
}
```

### Firing a trigger (code):
```javascript
// In app.js onInit():
const rainTrigger = this.homey.flow.getTriggerCard('rain_start');

// Later, when rain is detected:
const tokens = { mm_per_hour: 5.2 };
const state = {}; // Used for filtering with run listeners
await rainTrigger.trigger(tokens, state).catch(this.error);
```

### Device trigger (fires for a specific device):
```javascript
// In app.js or driver.js:
const myTrigger = this.homey.flow.getDeviceTriggerCard('button_pressed');

// In device.js, trigger for this specific device:
const tokens = { button_id: 'left' };
const state = { button_id: 'left' };
await myTrigger.trigger(this, tokens, state).catch(this.error);
```

### Trigger with run listener (filtering):
When a trigger has arguments, register a run listener to filter which Flows should run:
```javascript
const rainTrigger = this.homey.flow.getTriggerCard('rain_start');
rainTrigger.registerRunListener(async (args, state) => {
  // args = user's chosen argument values
  // state = values passed in trigger()
  return args.location === state.location;
});
```

---

## Conditions

Conditions check whether a state is true. The Flow continues only if the condition resolves `true`.

### Defining a condition:
`/.homeycompose/flow/conditions/is_raining.json`:
```json
{
  "title": { "en": "It is raining" },
  "titleFormatted": { "en": "It !{{is|isn't}} raining" },
  "hint": { "en": "Checks whether it is currently raining." }
}
```

The `titleFormatted` with `!{{is|isn't}}` creates an invertible condition — the user can toggle
between "is" and "isn't" in the Flow editor.

### Registering a condition listener:
```javascript
const isRaining = this.homey.flow.getConditionCard('is_raining');
isRaining.registerRunListener(async (args, state) => {
  return this.weatherApi.isRaining(); // Must return boolean
});
```

---

## Actions

Actions execute when the trigger fires and all conditions are met.

### Defining an action:
`/.homeycompose/flow/actions/send_notification.json`:
```json
{
  "title": { "en": "Send a notification" },
  "titleFormatted": { "en": "Send notification [[message]]" },
  "args": [
    {
      "type": "text",
      "name": "message",
      "title": { "en": "Message" },
      "placeholder": { "en": "Hello!" }
    }
  ]
}
```

### Registering an action listener:
```javascript
const sendNotification = this.homey.flow.getActionCard('send_notification');
sendNotification.registerRunListener(async (args, state) => {
  await this.notificationService.send(args.message);
});
```

### Action with duration:
Add `"duration": true` to the action definition. The duration value (in ms) is passed as `args.duration`.

---

## Arguments

Arguments let users provide input when creating a Flow.

### Argument types:

**text** — Free text input:
```json
{
  "type": "text",
  "name": "message",
  "title": { "en": "Message" },
  "placeholder": { "en": "Type here..." }
}
```

**number** — Numeric input:
```json
{
  "type": "number",
  "name": "temperature",
  "title": { "en": "Temperature" },
  "min": 5,
  "max": 35,
  "step": 0.5
}
```

**dropdown** — Predefined options:
```json
{
  "type": "dropdown",
  "name": "mode",
  "title": { "en": "Mode" },
  "values": [
    { "id": "eco", "label": { "en": "Eco" } },
    { "id": "comfort", "label": { "en": "Comfort" } }
  ]
}
```

**autocomplete** — Dynamic search:
```json
{
  "type": "autocomplete",
  "name": "artist",
  "title": { "en": "Artist" },
  "placeholder": { "en": "Search..." }
}
```

Register the autocomplete handler:
```javascript
const playArtist = this.homey.flow.getActionCard('play_artist');
playArtist.registerArgumentAutocompleteListener('artist', async (query, args) => {
  const results = await this.musicApi.searchArtists(query);
  return results.map(artist => ({
    name: artist.name,
    description: artist.genre,
    image: artist.imageUrl,
    id: artist.id,
  }));
});
```

**device** — Device picker (makes the card appear under the device in the Flow editor):
```json
{
  "type": "device",
  "name": "device",
  "filter": "driver_id=my_driver"
}
```

**checkbox** — Boolean toggle:
```json
{
  "type": "checkbox",
  "name": "enabled",
  "title": { "en": "Enabled" }
}
```

**color** — Color picker:
```json
{
  "type": "color",
  "name": "color",
  "title": { "en": "Color" }
}
```

**date** / **time** — Date or time picker.

### Title formatting:
Use `titleFormatted` with `[[argName]]` placeholders to create readable Flow cards:
```json
{
  "title": { "en": "Set temperature" },
  "titleFormatted": { "en": "Set temperature to [[temperature]] degrees" }
}
```

---

## Tokens

Tokens are values that a trigger provides to the rest of the Flow. Users can drag tokens
into text fields of condition and action cards.

### Defining tokens on a trigger:
```json
{
  "tokens": [
    {
      "name": "temperature",
      "type": "number",
      "title": { "en": "Temperature" },
      "example": 22
    },
    {
      "name": "location",
      "type": "string",
      "title": { "en": "Location" },
      "example": "Living Room"
    }
  ]
}
```

### Token types: `string`, `number`, `boolean`, `image`

### Providing token values when triggering:
```javascript
const tokens = {
  temperature: 22.5,
  location: 'Living Room',
};
await myTrigger.trigger(tokens).catch(this.error);
```

---

## Device Flow Cards

Flow cards with a `"type": "device"` argument appear under the device in the Flow editor sidebar.
This is the preferred pattern for device-specific cards.

### Example device action card:
```json
{
  "actions": [
    {
      "id": "set_mode",
      "title": { "en": "Set mode" },
      "titleFormatted": { "en": "Set mode to [[mode]]" },
      "args": [
        {
          "type": "device",
          "name": "device",
          "filter": "driver_id=my_thermostat"
        },
        {
          "type": "dropdown",
          "name": "mode",
          "title": { "en": "Mode" },
          "values": [
            { "id": "auto", "label": { "en": "Auto" } },
            { "id": "heat", "label": { "en": "Heat" } },
            { "id": "cool", "label": { "en": "Cool" } }
          ]
        }
      ]
    }
  ]
}
```

### Registering the listener:
```javascript
// In app.js or driver.js onInit():
const setMode = this.homey.flow.getActionCard('set_mode');
setMode.registerRunListener(async (args, state) => {
  // args.device is the Device instance
  await args.device.setMode(args.mode);
});
```

---

## Auto-generated Flow Cards

Homey automatically generates Flow cards for custom capabilities:

- **boolean** capabilities get: `<id>_true` and `<id>_false` triggers
- **number/string/enum** capabilities get: `<id>_changed` trigger
- System capabilities (like `onoff`, `dim`) get their own system Flow cards automatically

If you need custom behavior beyond the auto-generated cards, define your own Flow cards
and register the appropriate listeners.

### Deprecating Flow cards:
Add `"deprecated": true` to keep old Flow cards working but hidden from new Flows:
```json
{
  "id": "old_action",
  "deprecated": true,
  "title": { "en": "Old action (deprecated)" }
}
```
