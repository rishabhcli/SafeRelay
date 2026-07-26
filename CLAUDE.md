# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository shape

Monorepo holding **two independent Jac 0.34.7 applications** that share no build,
package manager, or persistence layer. Run every command from inside the relevant
app directory — there is no root-level build. The top-level `design/` directory
holds icon-composer source art (SVG/PNG layers plus a `build_layers.mjs` helper)
and is **not** a Jac app — see the Jac-rule note below.

| App | Path | Kind | Purpose |
| --- | --- | --- | --- |
| Web | `web/` | `web-app` | Evidence-scoped console monitoring source-backed public hazard feeds (USGS/NWS) plus mobile relay ingest — never fabricates operational records |
| Mobile | `mobile/` | `mobile` | Offline-first BLE packet relay, packaged for iOS/Android via Capacitor |

## The one hard rule: everything stays in Jac

Both apps are written *entirely* in Jac — backend logic, graph schema, agent
abilities, tests, routes, and JSX-like client components. **Do not add JavaScript,
TypeScript, Python, handwritten API routes, or a second persistence layer.** Model
work with Jac primitives instead:

- **Graph nodes + edges + walkers** for topology and traversal.
- **`def:pub` typed functions** for anonymous, client-callable web and mobile RPC.
  The shared public root graph is the database.
- **LLM output** only when structured, and always with a deterministic Jac fallback
  so the app runs with no model provider configured — this applies both to `by llm()`
  (cloud) and to the mobile on-device Apple Foundation Models bridge
  (`services/foundation_models.cl.jac`, which degrades to a deterministic reply off
  iOS/Apple Intelligence).

The only sanctioned non-Jac code is the generated Capacitor native shell
(`mobile/android/`, `mobile/ios/` — Swift only, see below) and the `design/` icon
tooling. Do not add JS/TS/Python anywhere else.

Before editing any `.jac` file, read the relevant compiler guide: `jac guide <name>`.

## Commands

`jac 0.34.7` must be on PATH. Both apps also define these as `[scripts]` in their
`jac.toml` (runnable via `jac run <script>`).

### web/
```sh
export PROMETHEUS_ADMIN_PASSWORD="$(openssl rand -base64 32)"  # required to start
jac install
jac start --dev main.jac        # serves http://localhost:8000  (ops UI at /ops)
jac check .                     # lint — run this BEFORE tests
jac test                        # runs saferelay/store_test.jac (see [test] in jac.toml)
jac test saferelay/store_test.jac   # single test file
jac build main.jac
# Preflight (CI gate): jac check . && jac test && jac build main.jac
```
`MAPBOX_ACCESS_TOKEN` is optional — the incident map falls back to the public token
baked into `jac.toml`'s `[client.vite.define]`; set your own to avoid drawing on that
account's quota. The `SAFERELAY_LIVE_AGENT` / `BYLLM_*` / provider-key variables and
the `[byllm.model]` block remain scaffolded in `web/.env.example` and `jac.toml`, but
no `by llm()` call is currently wired into the web backend — the deterministic
hazard-feed path is the only path. See `web/.env.example`.

### mobile/
```sh
jac install && bun install      # Jac deps + Capacitor npm deps (bun, not npm)
jac start main.jac --client web --dev --port 4173 -a 4174   # browser preview :4173
jac check .
jac clean --data --force && jac test -d tests -v    # canonical: clears graph data first
jac test tests/protocol_tests.jac -v                # single test file
jac build --client web
jac build --client mobile --platform android   # needs JAVA_HOME=JDK 21, ANDROID_HOME=Android SDK 36
jac build --client mobile --platform ios       # needs full Xcode on macOS
```

## Architecture

### web/ — one graph, one runtime
`saferelay/store.jac` is the whole backend: it declares the graph nodes
(`DisasterCache` → `DisasterEvent` via the `DisasterCacheEvent` edge, plus
`MobileRelaySignal`), the typed view objects, and the domain logic that pulls live
USGS earthquake and NWS severe-weather records over `urllib.request` with bounded
timeouts. It never fabricates operational records — a failed refresh keeps the
verified cache or reports unavailable. Public RPCs are `get_disaster_feed`,
`refresh_disaster_feed`, `cloud_relay_health`, and `ingest_mobile_signal`; the
last endpoint accepts relay reports from the mobile app. `main.jac`
re-exports these as thin `def:pub` wrappers and mounts the client via a
`cl { ... }` block. Client UI lives in `saferelay/*.jac` (`AppShell` router,
`LandingPage`, and `VerifiedCommandCenter` — the evidence monitor at
`/ops`). Evidence-boundary tests are `saferelay/store_test.jac`. The former drill
engine (Incident/Alert/RelayHop topology, the `TraceRelay` walker, the `by llm()`
briefing agent, and the 24-RPC console) has been removed.

> The web app's real code is all under `saferelay/` (+ `styles/`). The `app/`,
> `components/`, `lib/`, `hooks/`, `supabase/` directories hold only empty
> placeholder subfolders (no Jac code).

### mobile/ — dual client/server compilation
Jac compiles server and client variants into separate codespaces, so each domain
module exists twice in one importable project:

- `*.jac` — server/test variant (e.g. `domain/protocol.jac`, `domain/operations.jac`).
- `*.cl.jac` — client-build variant (e.g. `domain/protocol.cl.jac`, all of
  `services/`, `components/AppShell.cl.jac`).

To avoid duplicate declarations during whole-project `jac check`, **client symbols
are prefixed `Client`/`CLIENT_`** (e.g. `SosPacket` ↔ `ClientSosPacket`,
`PACKET_SIZE` ↔ `CLIENT_PACKET_SIZE`). The two variants must be kept algorithmically
equivalent. Layout: `domain/` = protocol + operations logic, `services/` = Capacitor
device/data bindings (BLE mesh, storage, field feeds, handoff transfer, and the
Apple Foundation Models bridge `foundation_models.cl.jac`), `components/` = UI
(`AppShell.cl.jac` plus the Mapbox `IncidentMap.cl.jac`), `tests/` = protocol +
operations tests. The client also depends on `mapbox-gl`; `MAPBOX_ACCESS_TOKEN` is
optional (`jac.toml` bakes a public fallback token). See `docs/ARCHITECTURE.md`.

`android/` and `ios/` are generated Capacitor shells (`jac setup mobile`) — no
Flutter/Dart. Touch them only for a native service, entitlement, permission, or
plugin bridge. The iOS shell now carries hand-written Swift bridges under
`ios/App/App/`: `SafeRelayMeshPlugin` (CoreBluetooth central/peripheral relay),
`SafeRelayFoundationModelsPlugin` (on-device Apple Intelligence), and
`SafeRelayBridgeViewController` + `SafeRelayNativeSettingsView` (native tab-bar
chrome), wired at launch from `AppDelegate`. `LocalNotifications` (configured in
`capacitor.config.json`) surfaces foreign-distress alerts. App id:
`com.development.saferelay`.

## Conventions

- 4-space indent. `snake_case` for Jac functions/variables/modules; `PascalCase`
  for components, nodes, walkers, and Java classes.
- Tests live beside the app they cover and are named `*_test.jac` / `*_tests.jac`
  with behavior-focused names. Always `jac check .` before running tests.
- Commit subjects are concise and imperative (`Add relay packet validation`); keep
  each commit scoped to one app or native-bridge concern.

## Evidence boundary (mobile BLE)

A generated shell, passing codec tests, a browser preview, an installed APK, or the
mere presence of `SafeRelayMeshPlugin.swift` **do not prove phone-to-phone BLE
behavior.** Do not claim native radio support until central scanning, peripheral
advertising, background continuity, packet receipt, and relay have been validated on
two physical devices. Responder receipt and rescue outcome are never inferred from a
local broadcast. Per `AGENTS.md`, run and interactively test the mobile app only on
physically connected Apple-Intelligence-capable iPhones (iOS 27) via Device Hub —
never a simulator, emulator, iPad, or browser preview; if fewer than two qualifying
iPhones are connected, report BLE relay validation as blocked.

## License

Proprietary — Copyright (c) 2025 SafeRelay Team, All Rights Reserved. No copying,
modification, distribution, or hackathon resubmission without written permission.
Never commit secrets; use `web/.env.example` and documented environment variables.
