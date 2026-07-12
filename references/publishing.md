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
- [ ] App ID is reverse-DNS and **final** (immutable after first publish); doesn't impersonate Homey/Athom
- [ ] SDK version is 3: `"sdk": 3`
- [ ] `platforms` is `["local"]` unless you have an Athom-approved account for Cloud
- [ ] All images present: app icon (SVG), app images (small, large), driver icons (SVG), driver images
- [ ] Icons are a **single solid path** monochrome silhouette (gradients/defs/clipPath/strokes have been observed to render as a blank disc)
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

## Before you submit for certification (what `validate` does NOT catch)

`homey app validate --level publish` passing is **necessary but not sufficient** — manual
certification rejects things the validator never checks. An agent left to its own defaults will trip
most of these, so verify them explicitly before submitting:

- [ ] **App name ≤ 4 words**, brand-based, no company/protocol/Homey/Athom (guideline 1.1)
- [ ] **Description** is a one-line tagline, not a paragraph, and doesn't repeat the README/name
- [ ] **README.txt** is 1–2 promotional paragraphs — no feature/Flow lists, no setup steps, no author line
- [ ] **README matches actual behaviour** (no removed features still described)
- [ ] **App icon** is a single monochrome silhouette, readable in white, no gradients/defs/clip/stroke
- [ ] **Driver icon/image is NOT the app's** — each driver unique; images on white background, angled
- [ ] **Widget previews**: 1024×1024, transparent, no screenshots, no text, simple shapes
- [ ] **Custom capabilities have an `icon`** (else they show a dashed placeholder box)
- [ ] **Translations are complete per language** — if any Flow card is translated, all are (+ settings/capabilities)
- [ ] **Third-party integration**: own icon (not the vendor logo), consider an "unofficial" note

---

## App Store Guidelines Summary {#guidelines}

### Naming (guideline 1.1):
- **Max 4 words** — names longer than four words are rejected. ("Google Health Sync" ✅ passes;
  "Health Sync for Google Health" ✗ is five words.)
- Use the **brand name**; **company names are not allowed**.
- Don't include **protocol names** (Zigbee, Z-Wave, 433 MHz, Infrared…).
- Don't use the **Homey or Athom** trademark in the name.
- The name is the brand, not a feature description. (The app `id` follows the same
  don't-impersonate-Homey/Athom rule but is *not* a substring ban — see
  `references/app-and-manifest.md`.)

### App description (one-liner):
- A single **catchy tagline**, not a paragraph.
- Don't repeat the app name or reuse README text; avoid "Adds support for X" / "Integrates X with Homey".

### Category:
Must be one of: `lights`, `video`, `music`, `appliances`, `security`, `climate`, `tools`, `internet`, `localization`, `energy`

### Brand color:
- Must be set via `brandColor` in the manifest
- Used as backdrop for icons in Flows, device picker, and App Store
- Must not be too bright
- Icons must be visible against this color

---

## Icons & Images

### App icon (`/assets/icon.svg`) — design it as a single monochrome silhouette

**Documented rules (guideline 1.5):** a clean, vector-based drawing on the **full 960×960 canvas**,
**transparent background**, and **no images, filled illustrations, gradients, or background colours**.
It must be **clearly visible against the `brandColor`** (the colored backdrop shown behind icons in
Flows, the device picker, and the App Store).

**Observed rendering behaviour (not spelled out in the docs, but it cost real debugging time — design
around it):** Homey effectively treats the icon as a **monochrome silhouette** placed on the
`brandColor` backdrop, and in several views renders the glyph in a **light/white tint**. Consequences:

- **A dark or black fill can "disappear"** against the backdrop in some views. Design the icon so it
  reads as a **solid silhouette that works in white** — the *shape* carries the icon, the fill colour
  is secondary to the mask.
- Icons built from **gradients, `<defs>`, `clipPath`, or stroke-only shapes** have been observed to
  render as an **empty coloured disc** — and `homey app validate --level publish` does **not** warn.
  Use a **single solid `<path>`** and express cutouts with **`fill-rule="evenodd"`** subpaths.
- **Capability and driver icons are treated the same way** — keep them single-path monochrome too.

> Honest caveat: the white-glyph/blank-disc behaviour above is community/first-hand observation, not a
> quoted guideline. The safe design that satisfies both the docs and the observations is: one solid
> vector silhouette, transparent background, no gradients/defs/clip/stroke, readable in white.

Good (renders): one `<path>` with an evenodd cutout —
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 960 960">
  <path fill-rule="evenodd" d="M480 80a400 400 0 100 800 400 400 0 100-800Zm0 120a280 280 0 110 560 280 280 0 110-560Z"/>
</svg>
```

### App images (PNG):
- `small.png` — 250×175 px
- `large.png` — 500×350 px
- `xlarge.png` — 1000×700 px (optional but recommended)
- Clean marketing images showing the product.

### Driver icons & images (guideline 1.5/1.6) — must NOT reuse the app's:
- **Do not reuse the app icon for a driver**, and **do not use the app image as a driver image** —
  reviewers reject verbatim copies.
- **Each driver needs its own unique icon** that clearly represents that device/service (multiple
  drivers must differ from each other).
- Driver **icon**: vector, transparent background, full 960×960 canvas.
- Driver **image**: a recognizable picture of the device on a **white background**; prefer an angle
  from the **right side** over a front-facing view.
- Driver image PNG sizes (note they differ from app images): `small.png` **75×75**,
  `large.png` 500×500, `xlarge.png` 1000×1000.

---

## README

`/README.txt` in the app root is the App Store long description. Reviewers reject bloated READMEs —
keep it to **one or two short, promotional paragraphs**:
- **One to two paragraphs, tops** — no feature/capability/Flow-card lists, no setup or installation
  instructions.
- **Plain text only** — markdown/HTML is not rendered; **no URLs**; single line spacing, no fancy
  indentation.
- **No changelog** — use `.homeychangelog.json` (via `homey app publish`).
- **No contributor credits / author line** — credit contributors in the manifest instead.
- **Keep it accurate.** The text must match what the app actually does — if you drop a feature
  (e.g. an app becomes read-only), update `README.txt` and every `README.<lang>.txt` or it is
  flagged as misleading.
- Translated versions: `README.<lang>.txt` (e.g., `README.nl.txt`) — see the completeness rule below.

---

## Localization completeness (partial translations get rejected) {#localization-completeness}

Translate **per scope, completely** — a half-translated app is a certification failure:
- If you translate the **description** into a language, translate the **README** into it too.
- If you translate **Flow cards** into a language, translate **all** Flow cards — every title, hint,
  token, and argument — plus device settings and custom capabilities, into that language. Don't leave
  half the cards English.
- Always ship at least `en` (the fallback). NL + DE are worth adding for store-quality apps.

Practically: decide your language set up front and apply it across `locales/*.json`, all
`*.compose.json` translation objects, `README.<lang>.txt`, and `.homeychangelog.json`.

---

## Integrating third-party services (Jellyfin, Plex, Spotify…) {#third-party}

For an app that integrates someone else's service, the **documented** rules are: use the **brand
name** (not a company name), don't put Homey/Athom in the name, and **don't use the third party's
logo as your app icon**. Beyond the docs, the widely-followed **community conventions** for an
unofficial integration are:
- Name it after the service; **"<App> for <Brand>"** is a common nominative-fair-use pattern
  (mind the 4-word limit).
- Draw your **own** icon evoking the function — never lift the vendor's logo/artwork.
- Add an **"unofficial / not affiliated with <Brand>"** note in the README to avoid implying
  endorsement.

(The naming and no-logo points are documented; the "for Brand" pattern and the disclaimer are
conventions, not official requirements.)

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
