# AGENTS.md

## Scope

These instructions apply to the whole repository.

This project is `pi-annotate`, a Pi package that registers an `/annotate`
command/tool and talks to a Chrome/Chromium Manifest V3 extension through a
native messaging bridge. There is intentionally no bundled build step.

## Project Map

- `package.json` declares the Pi package metadata. It has no `scripts` section
  and only depends on `typebox`.
- `index.ts` is the Pi extension entry point. It registers the `/annotate`
  command and `annotate` tool, connects to the local native-host IPC endpoint,
  authenticates with the native-host token, formats annotation output, and
  writes decoded screenshots to `os.tmpdir()`.
- `types.ts` contains the TypeScript interfaces for annotation payloads shared
  conceptually with the browser extension.
- `chrome-extension/manifest.json` is the MV3 extension manifest.
- `chrome-extension/background.js` is the service worker. It manages the native
  messaging port, tab routing, content script injection, screenshot capture, and
  popup/keyboard messages.
- `chrome-extension/content.js` is a large self-contained vanilla JS content
  script. It owns the picker UI, note cards, selectors, accessibility/style
  capture, screenshots, and edit capture.
- `chrome-extension/popup.html` and `chrome-extension/popup.js` implement the
  browser action popup for connection status and setup.
- `chrome-extension/native/host.cjs` bridges Chrome native messaging stdio to the
  local IPC endpoint used by `index.ts` (`/tmp/pi-annotate.sock` on Unix,
  `\\.\pipe\pi-annotate` on Windows).
- `chrome-extension/native/install.sh` installs native messaging manifests on
  macOS/Linux and regenerates `host-wrapper.sh` with an absolute Node path.
- `chrome-extension/native/install-windows.ps1` installs Windows native
  messaging registry entries for Chrome and/or Edge and regenerates
  `host-wrapper.cmd` with an absolute Node path.
- `banner.png`, `demo.mp4`, and icons are distribution assets. Avoid modifying
  them unless the task is explicitly about assets.

## Commands

There are no configured npm scripts, automated tests, linter, or TypeScript
compiler settings in this repository.

Useful checks when touching JavaScript files:

```bash
node --check chrome-extension/background.js
node --check chrome-extension/content.js
node --check chrome-extension/popup.js
node --check chrome-extension/native/host.cjs
```

Manual runtime verification for behavior changes:

```bash
npm install
```

Then load `chrome-extension/` as an unpacked extension in Chrome, Chrome for
Testing, or Chromium. From `chrome-extension/native/`, run the installer for
your platform:

```bash
./install.sh <extension-id>
```

```powershell
.\install-windows.ps1 -ChromeExtensionId <chrome-id>
.\install-windows.ps1 -EdgeExtensionId <edge-id>
```

Fully quit and reopen the browser, click the Pi Annotate icon, confirm
connection status, then exercise `/annotate` or `/annotate <url>` from Pi.
For browser-side changes, reload the unpacked extension after edits. For
`index.ts` changes, restart Pi. Native host logs are written to the system temp
directory as:

```bash
pi-annotate-host.log
```

If full manual verification is not possible, state exactly which pieces were
not verified.

## Development Guidelines

- Keep browser extension code dependency-free. `content.js`, `background.js`,
  and `popup.js` run directly in Chrome without a bundler.
- Preserve the content script IIFE and double-injection guard based on
  `__piAnnotate_` plus `chrome.runtime.id`.
- Prefix injected DOM ids/classes with `pi-`, and keep `isPiElement` exclusions
  accurate so the picker does not select or capture its own UI.
- Escape user-controlled strings before inserting them into HTML. Reuse
  `escapeHtml` in `content.js` when building markup.
- Preserve the message protocol unless the task explicitly changes it:
  `START_ANNOTATION`, `AUTH`, `PING`, `PONG`, `ANNOTATIONS_COMPLETE`, `CANCEL`,
  `SESSION_REPLACED`, `CAPTURE_SCREENSHOT`, `CHECK_CONNECTION`, and
  `TOGGLE_PICKER`.
- Keep `requestId` propagation intact across `index.ts`, `background.js`,
  `content.js`, and `host.cjs`. Clean up `pendingRequests` and `requestTabs`
  when sessions complete, cancel, timeout, or disconnect.
- When changing annotation payload shape, update all relevant layers together:
  capture in `content.js`, interfaces in `types.ts`, formatting in `index.ts`,
  and README/CHANGELOG examples when user-facing.
- Screenshot and edit-capture payloads can be large. Preserve buffer/size limits
  and keep screenshot data redacted in logs.
- Native host security matters. Keep Unix socket files private, store the token
  at `/tmp/pi-annotate.token` on Unix and under `%LOCALAPPDATA%\pi-annotate` on
  Windows, preserve `0600` permissions where supported, and do not log auth
  tokens or base64 image data.
- `host.cjs` is CommonJS because it is launched directly by native messaging.
  `index.ts` uses ESM-style imports because the package is `"type": "module"`.
- Native host registration is platform-specific. macOS/Linux use native
  messaging manifest directories. Windows uses registry keys under
  `HKCU\Software\Google\Chrome\NativeMessagingHosts` and
  `HKCU\Software\Microsoft\Edge\NativeMessagingHosts`, plus a named pipe at
  `\\.\pipe\pi-annotate`.
- Do not edit generated `host-wrapper.sh` or `host-wrapper.cmd` for durable
  behavior; update the matching installer script instead.
- Keep changes narrowly scoped. `content.js` is large, so prefer local edits near
  existing helpers over broad rewrites.
- This repo contains existing UTF-8 UI glyphs. Preserve file encoding when
  editing, but avoid introducing decorative non-ASCII text unless needed.
- Do not bump versions for ordinary fixes. For release work, check
  `package.json`, `package-lock.json`, `chrome-extension/manifest.json`,
  README, and CHANGELOG together.

## Manual Smoke Cases

For picker/UI changes, cover these flows when possible:

- Start annotation from `/annotate` on the current tab.
- Start annotation with `/annotate <url>` and confirm tab routing works.
- Select one element, add a note, submit, and inspect formatted output.
- Toggle multi-select and select multiple elements.
- Toggle screenshot modes and verify screenshots are returned or omitted as
  expected.
- Toggle debug mode and confirm computed styles, parent context, and CSS
  variables appear only when intended.
- Toggle edit capture, make a visible style/text/class change, submit, and
  confirm before/after screenshots and diffs.
- Cancel with `ESC` and confirm no stale overlay remains.
- Open the popup and verify connection, retry, copy buttons, and Start
  Annotation behavior.
