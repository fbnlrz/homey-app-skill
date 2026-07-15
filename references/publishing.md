# Publishing Reference

## Table of Contents
1. [Pre-submission Checklist](#pre-submission-checklist)
2. [Before you submit for certification](#before-you-submit-for-certification-what-validate-does-not-catch)
3. [App Store Guidelines (complete)](#guidelines)
4. [Icons & Images](#icons-and-images)
5. [README](#readme)
6. [Localization completeness](#localization-completeness)
7. [Third-party service integrations](#third-party)
8. [Flow Card Guidelines](#flow-guidelines)
9. [Publishing Process](#publishing-process)
10. [Updating Your App](#updating)
11. [Verified Developer](#verified-developer)

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
- [ ] **No typos / spelling errors** in any language (spelling errors = rejection, guideline 1.11)
- [ ] **App images** are rich product imagery, not a flat icon/logo/clipart or a bare app screenshot (1.4.2)
- [ ] **App works standalone** and adds value by itself; not fully dependent on another app (1.12)
- [ ] **App is free** — no paywall for any functionality (2.3)
- [ ] **Not a duplicate** — checked the store for an existing app for this brand/concept (2.1)
- [ ] **Third-party integration**: own icon (not the vendor logo), consider an "unofficial" note

---

## App Store Guidelines (complete) {#guidelines}

The full guideline set from <https://apps.developer.homey.app/app-store/guidelines>, organized as
Athom numbers them. `homey app validate` checks almost none of these — they are enforced during
manual certification. Deeper how-to for icons, README, localization, and Flow cards follows in the
sections below.

### 1. Design

**1.1 App name** — Max **4 words**; longer names are rejected. Use the **brand name** (match it
exactly when supporting a specific brand); **company names are not allowed**. No **protocol names**
(Zigbee, Z-Wave, 433 MHz, Infrared…). Never use the **Homey/Athom** trademark. It is the brand, not a
feature description. (The app `id` follows the same don't-impersonate rule but is not a substring ban
— see `references/app-and-manifest.md`.)

**1.2 Description** — Required. An **engaging one-liner** that highlights the purpose — *not* an
extensive text. Don't use the app name in it or repeat README text. Avoid "Adds support for…" /
"Integrates … with Homey".

**1.3 Readme** — One to two paragraphs, tops. Don't list features/capabilities/Flow cards. Plain
text (no Markdown), **no URLs**, no changelog in the readme. (Detail in the [README](#readme) section.)

**1.4 Images**
- **1.4.1 Format & resolutions** — `.jpg` or `.png` only. **Small and Large are mandatory**, XLarge
  optional. App images: Small **250×175**, Large **500×350**, XLarge **1000×700**. Driver images:
  Small **75×75**, Large **500×500**, XLarge **1000×1000**.
- **1.4.2 App images** — Must be real, rich imagery. **A single flat shape/icon on a plain,
  monochrome, or transparent background is NOT approved.** Avoid logos, clipart, icon-type images,
  and images that only show an Android/iOS app UI.
- **1.4.3 Driver images** — A **white background** and a recognizable picture of the supported
  device. **Don't reuse the app image or app icon as a driver image.**

**1.5 App icon** (`/assets/icon.svg`) — Recognizable at small sizes, **transparent background**, full
**960×960** canvas. **No images, filled illustrations, gradients, or background colours.** If the app
supports a specific brand, use that company's brand icon. Must be clearly visible against `brandColor`.
(Design detail + observed rendering behaviour in [Icons & Images](#icons-and-images).)

**1.6 Driver icons** — Full **960×960** canvas, **transparent background**, lines/shapes only (no
images/fills/gradients/background colours). Where possible use an **angle from the right** rather than
a front view. **Do not reuse the app icon.** Each driver's icon must be unique and clearly represent
its device.

**1.7 Brand color** — `brandColor` is **mandatory** in the manifest. Both app and driver icons must
be clearly visible against it (so it must not be too bright/light).

**1.8 URLs** — `source`, `homepage`, `support`, `bugs.url` etc. in the manifest render as clickable
links on the app's store page (URLs belong here, never in the README).

**1.9 Flow** — **1.9.1 Titles:** short and clear; no device names; no "When/And/Then"; **no
parentheses**. **1.9.2 Formatted titles:** use `titleFormatted` to place arguments and keep it
readable. **1.9.3 Hint:** add a `hint` when the card's function isn't obvious. (Detail in
[Flow Card Guidelines](#flow-guidelines).)

**1.10 Widget previews** — Light **and** dark version, **1024×1024**, **transparent background**. No
text; simple shapes; not too many colours; **don't** use the same colour as the widget-picker
background; not a screenshot/over-detailed. (Detail in `references/widgets.md`.)

**1.11 Language & translations** — English is required. **No typos / spelling / grammar errors — the
app is rejected if spelling errors are found.** Consistency is vital; avoid sporadic/partial
translations. (Completeness detail in [Localization completeness](#localization-completeness).)

**1.12 Dependencies** — An app's core functionality must **work standalone**. You may **not** make one
app fully dependent on another app, and you may not publish an app that **adds no value by itself**.

**1.13 Account** — A developer account name may not contain emojis, special characters, or
inappropriate language. Verified Developer accounts should display the company name.

### 2. Legal

**2.1 Duplicate** — **2.1.1 App:** ideally one app per brand/concept; check the App Store first and
prefer collaborating with an existing app's developer; if you still submit, explain why collaboration
wasn't possible. **2.1.2 Code:** don't copy other developers' code without consent; if you base work
on someone else's source, ask permission and **credit the original in the app manifest**.

**2.2 Explicit content** — Apps with adult/explicit content (e.g. pornography) are not allowed.

**2.3 Compensation** — Apps must be **free of charge**; you may not charge for partial or full
functionality. Connecting to a service that has its own premium tier is fine as long as payment
happens outside the Homey app.

### 3. After app submission

**3.1 Review duration** — Certification can take **up to ~2 weeks**; faster when all requirements are
met on submission.

**3.2 Testing** — Test thoroughly before submitting: device controls, advanced-settings updates, Flow
creation/execution, and manual state changes made outside the Homey app. Check pairing instructions,
error messages, Flow-card clarity, setting labels/hints, and translations. Verified Developers need
sample devices. Test builds are reachable at `https://homey.app/en-us/app/<APP.ID>/test/`.

**3.3 Feedback** — Review findings are shared with you and are expected to be implemented.

**3.4 Removal** — Apps may be hidden/removed if they stop being compatible, stop functioning, or are
unmaintained. Apps with **no update for 2+ years** may be treated as abandoned.

### Category (manifest)
`category` must be one of: `lights`, `video`, `music`, `appliances`, `security`, `climate`, `tools`,
`internet`, `localization`, `energy`.

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

### App images (PNG/JPG) — guideline 1.4.2:
- `small.png` — 250×175 px (**mandatory**)
- `large.png` — 500×350 px (**mandatory**)
- `xlarge.png` — 1000×700 px (optional but recommended)
- Rich marketing imagery of the product. **A single flat shape/icon on a plain, monochrome, or
  transparent background is rejected** — no logos, no clipart, no icon-style images, and not just a
  screenshot of an Android/iOS app UI.

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
- **No typos or spelling/grammar errors** in any language — guideline 1.11 states the app is
  **rejected if spelling errors are found**. Proofread every string.

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

### Hints (guideline 1.9.3):
- Add a `hint` translation object when a card's function isn't self-evident, e.g.
  `"hint": { "en": "Triggers only when the value crosses the threshold upward." }`

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
