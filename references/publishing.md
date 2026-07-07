# Publishing Reference

## Table of Contents
1. [Pre-submission Checklist](#pre-submission-checklist)
2. [App Store Guidelines Summary](#guidelines)
3. [Icons & Images](#icons-and-images)
4. [README](#readme)
5. [Flow Card Guidelines](#flow-guidelines)
6. [Publishing Process](#publishing-process)
7. [Updating Your App](#updating)
8. [Verified Developer](#verified-developer)

---

## Pre-submission Checklist

Before publishing, verify:
- [ ] `homey app validate --level=publish` passes
- [ ] App ID is in reverse domain notation (no "homey" or "athom")
- [ ] SDK version is 3: `"sdk": 3`
- [ ] `platforms` is `["local"]` unless you have an Athom-approved account for Cloud
- [ ] All images present: app icon (SVG), app images (small, large), driver icons (SVG), driver images
- [ ] Icons are a **single solid path** (no gradients/defs/clipPath/strokes — they render as a blank disc)
- [ ] Every widget has **both** `preview-light.png` and `preview-dark.png` (missing ones fail with ENOENT)
- [ ] `brandColor` is set and not too bright
- [ ] README.txt is plain text (no markdown, no URLs, no changelogs)
- [ ] English translations are complete
- [ ] Flow cards have clear, short titles (no device names, no "When"/"And"/"Then")
- [ ] Device classes are appropriate
- [ ] Capabilities match the device type
- [ ] `.homeyignore` excludes non-essential files
- [ ] `env.json` is in `.gitignore`
- [ ] No console.log left (use `this.log()`, `this.error()`)
- [ ] Handles promise rejections (`.catch(this.error)`)
- [ ] Uses `this.homey.setInterval()` instead of global `setInterval()`

---

## App Store Guidelines Summary {#guidelines}

### Naming:
- Use the brand name as the app name
- Don't include protocol names (Zigbee, Z-Wave, etc.)
- Don't include company names
- Don't use "Homey" or "Athom"

### Category:
Must be one of: `lights`, `video`, `music`, `appliances`, `security`, `climate`, `tools`, `internet`, `localization`, `energy`

### Brand color:
- Must be set via `brandColor` in the manifest
- Used as backdrop for icons in Flows, device picker, and App Store
- Must not be too bright
- Icons must be visible against this color

---

## Icons & Images

### App icon (`/assets/icon.svg`) — the single-color glyph rule

The App Store renders `/assets/icon.svg` as a **single-color glyph masked onto a circle filled with
`brandColor`** — the SVG is recolored to one flat color, not drawn as you designed it. In practice
this means:

- **Use a single solid path.** Icons that rely on **gradients, `<defs>`, `clipPath`, or strokes**
  silently render as an **empty colored disc** — and `homey app validate --level publish` does
  **not** warn you, so it looks fine locally and blank in the store.
- **Express cutouts with `fill-rule="evenodd"`** subpaths rather than overlaying shapes or masks.
- Draw on the full canvas (960×960), transparent background, recognizable at small sizes.
- **Capability icons and driver icons are tinted monochrome too** — the same single-path rule
  applies to `/assets/<capability>.svg` and `/drivers/<id>/assets/icon.svg`.

Good (renders): one `<path>` with an evenodd cutout —
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 960 960">
  <path fill-rule="evenodd" d="M480 80a400 400 0 100 800 400 400 0 100-800Zm0 120a280 280 0 110 560 280 280 0 110-560Z"/>
</svg>
```
Bad (blank disc): gradients / `<defs>` / `clipPath` / stroke-only shapes.

### App images (PNG):
- `small.png` — 250×175 px
- `large.png` — 500×350 px
- `xlarge.png` — 1000×700 px (optional but recommended)
- Clean marketing images showing the product

### Driver images (PNG) — note the sizes differ from app images:
- `small.png` — **75×75 px**
- `large.png` — 500×500 px
- `xlarge.png` — 1000×1000 px
- Show the actual product device.

---

## README

`/README.txt` in the app root:
- **Plain text only** — no markdown, no HTML
- **No URLs** — they won't render
- **No changelogs** — use the built-in changelog feature
- **No feature lists** — keep it concise
- **No contributor credits** — use the manifest `contributors` field
- Keep it short and descriptive
- Translated versions: `README.<lang>.txt` (e.g., `README.nl.txt`)

---

## Flow Card Guidelines {#flow-guidelines}

### Titles:
- Short and clear
- Don't mention device names (the device argument handles that)
- Don't add "When", "And", "Then" prefixes
- Don't use parentheses
- Use `titleFormatted` with `[[argName]]` for argument placeholders

### Conditions:
- Use the invertible pattern: `!{{is|isn't}}` for boolean conditions
- Example: `"It !{{is|isn't}} raining"`

### Good examples:
- Trigger: "A button was pressed"
- Condition: "The device !{{is|isn't}} playing"
- Action: "Set the brightness"

### Bad examples:
- "When the Philips Hue light turns on" (don't include device/brand names)
- "Then set the temperature" (don't include "Then")
- "Set temperature (Celsius)" (don't use parentheses)

---

## Publishing Process

Publishing is a two-part lifecycle: the **CLI uploads a build**, then you **promote that build in
the Developer Dashboard**.

1. **Validate**: `homey app validate --level=publish`
2. **Publish**: `homey app publish` — the CLI, in one run:
   - bumps the version (asks patch/minor/major, or confirms your manual bump),
   - re-validates the app,
   - compresses and uploads a **build** to the Homey App Store, and
   - prompts **"What's new?"** and writes the entry into `.homeychangelog.json`.
   (Homey never downgrades — the new version must be higher than what is currently Live.)
3. **Promote the build** in the Developer Dashboard at
   [tools.developer.homey.app](https://tools.developer.homey.app/) → *My Apps* → your app → *Builds*.
   Each build moves through **Draft → Test → Certified/Live**:
   - **Release to Test** — makes the build available via a **shareable test link** from the
     dashboard (the app's `…/test/` page). Great for beta testers; no certification needed.
   - **Submit for certification** — sends the build to Athom for review. Apps that have never been
     released publicly must pass certification before they appear in the public App Store.

First-time submissions must be complete (icons, images, texts all present).

### Changelog:
`homey app publish` creates/updates `.homeychangelog.json`. It is keyed by version, then language
(`{ "1.0.0": { "en": "…", "nl": "…" } }`); `en` is required and is the fallback. Describe changes
clearly and concisely.

### Community forum link:
Set `homeyCommunityTopicId` (a **number**, from the topic's URL) in `.homeycompose/app.json` to show
a "Community" link on the App Store page pointing at your forum thread.

---

## Updating Your App {#updating}

### Version bumping:
Use semver: `homey app version patch|minor|major`

### Breaking changes:
If you need to make breaking changes to capabilities or drivers:
- Read the Breaking Changes guide
- Use `"deprecated": true` for old drivers/Flow cards rather than removing them
- Adding capabilities dynamically: `await this.addCapability('new_cap')`
- Removing capabilities: `await this.removeCapability('old_cap')` (breaks user Flows!)

### Updating driver capabilities across versions:
In `device.js` `onInit()`, check and migrate:
```javascript
async onInit() {
  // Add new capability if not present
  if (!this.hasCapability('measure_power')) {
    await this.addCapability('measure_power');
  }
  // Remove deprecated capability
  if (this.hasCapability('old_capability')) {
    await this.removeCapability('old_capability');
  }
}
```

---

## Verified Developer

- Publishing apps for Homey Pro is free for anyone
- Publishing apps for Homey Cloud requires a Verified Developer subscription
- Only companies can purchase the subscription
- Verified developers don't see the "Donate" button on their app pages
